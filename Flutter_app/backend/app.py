import logging
from flask import Flask, request, jsonify
from werkzeug.utils import secure_filename
import tempfile
import os
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from flask_cors import CORS
from PIL import Image
import torch
from torchvision import models, transforms
import os
from google.cloud import vision
from googlemaps import Client as GoogleMaps
import requests
from dotenv import load_dotenv

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

load_dotenv()

app = Flask(__name__)

# Enable CORS for all routes
CORS(app)

# Security configurations
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max file size
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp'}

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

# Rate limiting
limiter = Limiter(
    get_remote_address,
    app=app,
    default_limits=["200 per day", "50 per hour"],
    storage_uri="memory://"
)

# Initialize Google APIs (you'll need to set environment variables for API keys)
try:
    vision_client = vision.ImageAnnotatorClient()
    logger.info("Google Vision API client initialized successfully")
except Exception as e:
    logger.warning(f"Google Vision API not configured: {e}")
    vision_client = None

# Alternative: Use Vision API with REST calls (more reliable with API key)
vision_api_key = os.getenv('GOOGLE_VISION_API_KEY')
vision_rest_url = "https://vision.googleapis.com/v1/images:annotate"

gmaps_key = os.getenv('GOOGLE_MAPS_API_KEY')
if not gmaps_key:
    logger.warning("Google Maps API key not found in environment variables")
    gmaps = None
else:
    gmaps = GoogleMaps(key=gmaps_key)
    logger.info("Google Maps API client initialized successfully")

# Fallback to local model if Google Vision fails
model = models.resnet50(pretrained=True)
model.eval()

# Load ImageNet class names for better fallback results
try:
    import urllib.request
    url = "https://raw.githubusercontent.com/pytorch/hub/master/imagenet_classes.txt"
    with urllib.request.urlopen(url) as f:
        classes = [line.decode('utf-8').strip() for line in f.readlines()]
    logger.info("ImageNet classes loaded successfully")
except Exception as e:
    logger.warning(f"Could not load ImageNet classes: {e}")
    classes = None

def classify_media_type(labels):
    """Classify the type of media from image labels - strictly media only"""
    media_keywords = {
        'book': ['book', 'novel', 'magazine', 'comic', 'textbook', 'paperback', 'hardcover', 'literature', 'library', 'reading'],
        'movie': ['movie', 'film', 'cinema', 'dvd', 'bluray', 'video', 'poster', 'screen', 'hollywood', 'cinematic'],
        'game': ['video game', 'gaming', 'console', 'controller', 'joystick', 'arcade', 'playstation', 'xbox', 'nintendo', 'gaming console'],
        'music': ['cd', 'vinyl', 'album', 'record', 'cassette', 'audio', 'music', 'instrument', 'spotify', 'itunes'],
        'software': ['software', 'program', 'application', 'computer program', 'digital media', 'app store']
    }

    labels_lower = [label.lower() for label in labels]
    labels_text = ' '.join(labels_lower)

    # Check for media-specific keywords first
    for media_type, keywords in media_keywords.items():
        if any(keyword in labels_text for keyword in keywords):
            return media_type

    # Additional checks for media-related terms
    media_indicators = ['media', 'entertainment', 'digital', 'content', 'multimedia']
    if any(indicator in labels_text for indicator in media_indicators):
        return 'media'

    # If no media detected, return None to indicate non-media
    return None

def generate_store_search_query(media_type, labels):
    """Generate appropriate store search query based on media type"""
    store_types = {
        'book': ['bookstore', 'library', 'book shop', 'barnes & noble', 'books'],
        'movie': ['video store', 'movie rental', 'blockbuster', 'redbox', 'dvd store'],
        'game': ['game store', 'gaming store', 'gamestop', 'electronic store', 'toy store'],
        'music': ['music store', 'record store', 'cd store', 'instrument store'],
        'software': ['electronics store', 'computer store', 'best buy', 'software store'],
        'media': ['media store', 'electronics', 'department store']
    }

    # Get relevant store types for this media
    relevant_stores = store_types.get(media_type, store_types['media'])

    # Try to use specific labels if they match store types
    for label in labels[:2]:  # Check top 2 labels
        label_lower = label.lower()
        if any(store in label_lower for store in ['bookstore', 'library', 'video store', 'game store', 'music store']):
            return label_lower

    # Return primary store type for this media
    return relevant_stores[0]

@app.route('/analyze', methods=['POST'])
@limiter.limit("10 per minute")
def analyze():
    try:
        logger.info("Received image analysis request")
        if 'file' not in request.files:
            logger.error("No file provided in request")
            return jsonify({'success': False, 'error': 'No file provided'}), 400

        file = request.files['file']
        if file.filename == '':
            logger.error("Empty filename provided")
            return jsonify({'success': False, 'error': 'No file selected'}), 400

        if not allowed_file(file.filename):
            logger.error(f"Invalid file type: {file.filename}")
            return jsonify({'success': False, 'error': 'Invalid file type. Allowed: png, jpg, jpeg, gif, bmp, webp'}), 400

        # Secure the filename and save temporarily
        filename = secure_filename(file.filename)
        with tempfile.NamedTemporaryFile(delete=False, suffix=os.path.splitext(filename)[1]) as temp_file:
            file.save(temp_file.name)
            temp_path = temp_file.name

        try:
            image = Image.open(temp_path)
            # Always convert to RGB to ensure compatibility with JPEG format
            if image.mode != 'RGB':
                image = image.convert('RGB')
            logger.info(f"Processing image: {filename}")
        finally:
            # Clean up temporary file
            try:
                os.unlink(temp_path)
            except OSError:
                pass

        # Convert PIL image to bytes for Google Vision
        from io import BytesIO
        img_byte_arr = BytesIO()
        image.save(img_byte_arr, format='JPEG')
        content = img_byte_arr.getvalue()

        top_labels = []
        confidence_scores = []
        # Initialize vision_client_available to avoid UnboundLocalError
        vision_client_available = False
        if 'vision_client' in globals() and vision_client is not None:
            vision_client_available = True

        # Try Google Vision API first (with service account or API key)
        if vision_client_available:
            try:
                # Create Google Vision image object
                vision_image = vision.Image(content=content)

                # Perform label detection
                response = vision_client.label_detection(image=vision_image)
                labels = response.label_annotations

                # Extract top labels
                if labels:
                    top_labels = [label.description for label in labels[:5]]
                    confidence_scores = [label.score for label in labels[:5]]
                    logger.info(f"Google Vision detected {len(labels)} labels")
                else:
                    logger.warning("Google Vision returned no labels")
            except Exception as e:
                logger.error(f"Google Vision API error: {e}")
                vision_client_available = False  # Disable for this request
        else:
            logger.info("Google Vision API not available, skipping to fallback")

        # Fallback: Use Vision API via REST if service account failed
        if not top_labels and vision_api_key:
            try:
                import base64
                image_base64 = base64.b64encode(content).decode('utf-8')

                payload = {
                    "requests": [{
                        "image": {"content": image_base64},
                        "features": [{"type": "LABEL_DETECTION", "maxResults": 5}]
                    }]
                }

                response = requests.post(
                    f"{vision_rest_url}?key={vision_api_key}",
                    json=payload,
                    headers={'Content-Type': 'application/json'}
                )

                if response.status_code == 200:
                    result = response.json()
                    if 'responses' in result and result['responses']:
                        labels = result['responses'][0].get('labelAnnotations', [])
                        if labels:
                            top_labels = [label['description'] for label in labels[:5]]
                            confidence_scores = [label['score'] for label in labels[:5]]
                            logger.info(f"Vision API (REST) detected {len(labels)} labels")
            except Exception as e:
                logger.error(f"Vision API REST error: {e}")

        # Enhanced fallback to local model if Vision API fails or not configured
        if not top_labels:
            logger.info("No labels from Vision API, attempting local model fallback")
            try:
                transform = transforms.Compose([
                    transforms.Resize(256),
                    transforms.CenterCrop(224),
                    transforms.ToTensor(),
                    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
                ])
                logger.info("Applying image transformations")
                img_t = transform(image).unsqueeze(0)
                logger.info(f"Image tensor shape: {img_t.shape}")

                with torch.no_grad():
                    logger.info("Running model inference")
                    outputs = model(img_t)
                    probabilities = torch.nn.functional.softmax(outputs[0], dim=0)
                    top_probs, top_classes = torch.topk(probabilities, 5)
                    logger.info(f"Top probabilities: {top_probs}")
                    logger.info(f"Top classes: {top_classes}")

                # Map to ImageNet classes
                if classes:
                    class_names = [classes[i.item()] for i in top_classes]
                    logger.info(f"Mapped to class names: {class_names}")
                else:
                    class_names = [f'Predicted Class {i.item()}' for i in top_classes]
                    logger.warning("ImageNet classes not loaded, using generic names")

                top_labels = class_names
                confidence_scores = [prob.item() for prob in top_probs]
                logger.info("Fallback to local ResNet model completed successfully")

            except Exception as e:
                logger.error(f"Local model fallback failed: {str(e)}", exc_info=True)
                # Return a generic error response
                return jsonify({'success': False, 'error': f'Image analysis failed: {str(e)}'}), 500

        # Classify media type from labels - strictly media only
        media_type = classify_media_type(top_labels)

        if media_type is None:
            logger.info(f"Analysis completed - no media detected in image. Labels: {top_labels}")
            return jsonify({
                'success': True,
                'labels': top_labels,
                'confidence': confidence_scores,
                'media_type': None,
                'message': 'No media detected in this image. Please try an image of books, movies, games, music, or other media.',
                'fallback': not vision_client_available or not top_labels
            })

        search_query = generate_store_search_query(media_type, top_labels)

        logger.info(f"Analysis completed successfully. Labels: {len(top_labels)}, Media type: {media_type}, Search query: {search_query}, Fallback used: {not vision_client_available or not top_labels}")
        return jsonify({
            'success': True,
            'labels': top_labels,
            'confidence': confidence_scores,
            'media_type': media_type,
            'search_query': search_query,
            'fallback': not vision_client_available or not top_labels
        })

    except Exception as e:
        logger.error(f"Error in analyze endpoint: {str(e)}", exc_info=True)
        return jsonify({'success': False, 'error': 'Internal server error'}), 500

@app.route('/map-ai', methods=['POST'])
@limiter.limit("20 per minute")
def map_ai():
    try:
        logger.info("Received map AI request")
        data = request.get_json()
        if not data:
            logger.error("No JSON data provided")
            return jsonify({'success': False, 'error': 'No data provided'}), 400

        user_lat = data.get('lat')
        user_lng = data.get('lng')
        if user_lat is None or user_lng is None:
            logger.error("Missing latitude or longitude")
            return jsonify({'success': False, 'error': 'Latitude and longitude are required'}), 400

        # Validate coordinate ranges
        try:
            user_lat = float(user_lat)
            user_lng = float(user_lng)
            if not (-90 <= user_lat <= 90) or not (-180 <= user_lng <= 180):
                raise ValueError("Invalid coordinates")
        except (ValueError, TypeError):
            logger.error("Invalid coordinate format")
            return jsonify({'success': False, 'error': 'Invalid latitude or longitude format'}), 400

        query = data.get('query', 'media store')  # Default search query for media
        logger.info(f"Searching for '{query}' near ({user_lat}, {user_lng})")

        if gmaps is None:
            # Enhanced fallback to mock data if API not configured - media-focused stores
            media_stores = {
                'bookstore': [
                    {"name": "Mock Bookstore", "lat": user_lat + 0.01, "lng": user_lng + 0.01, "vicinity": "Mock Address 1", "rating": 4.5, "place_id": "mock1"},
                    {"name": "Local Library", "lat": user_lat - 0.01, "lng": user_lng - 0.01, "vicinity": "Mock Address 2", "rating": 4.0, "place_id": "mock2"},
                    {"name": "Book Haven", "lat": user_lat + 0.02, "lng": user_lng + 0.02, "vicinity": "Mock Address 3", "rating": 4.2, "place_id": "mock3"}
                ],
                'video store': [
                    {"name": "Mock Video Store", "lat": user_lat + 0.01, "lng": user_lng + 0.01, "vicinity": "Mock Address 1", "rating": 4.5, "place_id": "mock1"},
                    {"name": "DVD Rental Shop", "lat": user_lat - 0.01, "lng": user_lng - 0.01, "vicinity": "Mock Address 2", "rating": 4.0, "place_id": "mock2"},
                    {"name": "Movie Mart", "lat": user_lat + 0.02, "lng": user_lng + 0.02, "vicinity": "Mock Address 3", "rating": 4.2, "place_id": "mock3"}
                ],
                'game store': [
                    {"name": "Mock Game Store", "lat": user_lat + 0.01, "lng": user_lng + 0.01, "vicinity": "Mock Address 1", "rating": 4.5, "place_id": "mock1"},
                    {"name": "Gaming Hub", "lat": user_lat - 0.01, "lng": user_lng - 0.01, "vicinity": "Mock Address 2", "rating": 4.0, "place_id": "mock2"},
                    {"name": "Game World", "lat": user_lat + 0.02, "lng": user_lng + 0.02, "vicinity": "Mock Address 3", "rating": 4.2, "place_id": "mock3"}
                ]
            }

            # Use query-appropriate mock stores
            stores = media_stores.get(query, media_stores['bookstore'])  # Default to bookstore
            nearest = stores[0]  # First one as nearest
            route_info = {
                "distance": "1.2 km",
                "duration": "5 mins",
                "steps": ["Head north on Main St", "Turn left onto Store Ave", "Arrive at destination"]
            }
            return jsonify({
                "success": True,
                "nearest_store": nearest,
                "all_stores": stores,
                "route_info": route_info,
                "fallback": True
            })

        # Use Google Places API to find nearby places - media-focused search
        try:
            # Adjust search parameters based on media type
            search_type = 'store'
            if 'book' in query.lower():
                search_type = 'book_store'
            elif 'movie' in query.lower() or 'video' in query.lower():
                search_type = 'movie_rental'
            elif 'game' in query.lower():
                search_type = 'electronics_store'

            places_result = gmaps.places_nearby(
                location=(user_lat, user_lng),
                radius=5000,  # 5km radius
                keyword=query,
                type=search_type
            )
            places = places_result.get('results', [])
            logger.info(f"Found {len(places)} places via Google Maps API")
        except Exception as e:
            logger.error(f"Google Maps API error: {e}")
            places = []  # Trigger fallback

        if not places:
            # Fallback to enhanced mock data if API returns no results - media-focused
            fallback_stores = {
                'bookstore': [
                    {"name": "Fallback Bookstore", "lat": user_lat + 0.01, "lng": user_lng + 0.01, "vicinity": "Fallback Address 1", "rating": 4.5, "place_id": "fallback1"},
                    {"name": "Community Library", "lat": user_lat - 0.01, "lng": user_lng - 0.01, "vicinity": "Fallback Address 2", "rating": 4.0, "place_id": "fallback2"}
                ],
                'video store': [
                    {"name": "Fallback Video Store", "lat": user_lat + 0.01, "lng": user_lng + 0.01, "vicinity": "Fallback Address 1", "rating": 4.5, "place_id": "fallback1"},
                    {"name": "Movie Rental", "lat": user_lat - 0.01, "lng": user_lng - 0.01, "vicinity": "Fallback Address 2", "rating": 4.0, "place_id": "fallback2"}
                ],
                'game store': [
                    {"name": "Fallback Game Store", "lat": user_lat + 0.01, "lng": user_lng + 0.01, "vicinity": "Fallback Address 1", "rating": 4.5, "place_id": "fallback1"},
                    {"name": "Gaming Store", "lat": user_lat - 0.01, "lng": user_lng - 0.01, "vicinity": "Fallback Address 2", "rating": 4.0, "place_id": "fallback2"}
                ]
            }

            stores = fallback_stores.get(query, fallback_stores['bookstore'])
            nearest = stores[0]
            route_info = {
                "distance": "0.8 km",
                "duration": "3 mins",
                "steps": ["Walk straight ahead", "Cross the street", "Enter the store"]
            }
            return jsonify({
                "success": True,
                "nearest_store": nearest,
                "all_stores": stores,
                "route_info": route_info,
                "fallback": True
            })

        # Format Google Places results
        stores = [{
            "name": place['name'],
            "lat": place['geometry']['location']['lat'],
            "lng": place['geometry']['location']['lng'],
            "vicinity": place.get('vicinity', 'Address not available'),
            "rating": place.get('rating', 0),
            "place_id": place.get('place_id', '')
        } for place in places[:5]]  # Limit to top 5 results

        # Calculate distances and find nearest
        def distance(lat1, lon1, lat2, lon2):
            return ((lat1 - lat2)**2 + (lon1 - lon2)**2)**0.5

        nearest = min(stores, key=lambda s: distance(user_lat, user_lng, s['lat'], s['lng']))

        # Get directions to nearest store
        route_info = {}
        try:
            directions_result = gmaps.directions(
                origin=(user_lat, user_lng),
                destination=(nearest['lat'], nearest['lng']),
                mode="driving"
            )

            if directions_result:
                route = directions_result[0]['legs'][0]
                route_info = {
                    "distance": route['distance']['text'],
                    "duration": route['duration']['text'],
                    "steps": [step['html_instructions'] for step in route['steps'][:3]]  # First 3 steps
                }
                logger.info("Directions calculated successfully")
            else:
                logger.warning("No directions found")
        except Exception as e:
            logger.error(f"Directions API error: {e}")

        logger.info(f"Map AI request completed successfully. Found {len(stores)} stores")
        return jsonify({
            "success": True,
            "nearest_store": nearest,
            "all_stores": stores,
            "route_info": route_info
        })

    except Exception as e:
        logger.error(f"Error in map-ai endpoint: {str(e)}", exc_info=True)
        return jsonify({"success": False, "error": "Internal server error"}), 500

@app.route('/')
def home():
    return jsonify({
        'status': 'running',
        'message': 'AI Backend Service is running',
        'endpoints': {
            'analyze': 'POST /analyze - Analyze images for media types',
            'map_ai': 'POST /map-ai - Find nearby stores'
        }
    })

if __name__ == '__main__':
    # Production-ready configuration
    app.run(
        host='0.0.0.0',
        port=int(os.getenv('PORT', 5000)),
        debug=os.getenv('FLASK_DEBUG', 'False').lower() == 'true'
    )