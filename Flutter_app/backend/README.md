# AI Backend Service

A Flask-based backend service providing AI-powered image analysis and map analysis features.

## Features

- **Image Analysis**: Uses Google Vision API with ResNet50 fallback for object detection
- **Map Analysis**: Google Maps integration for location-based services
- **Robust Fallbacks**: Local AI models ensure service availability
- **Production Ready**: Docker containerization and proper logging

## Setup

1. Clone the repository
2. Install dependencies: `pip install -r requirements.txt`
3. Set up environment variables in `.env`:
   ```
   GOOGLE_MAPS_API_KEY=your_maps_api_key
   GOOGLE_VISION_API_KEY=your_vision_api_key
   ```
4. Run locally: `python app.py`

## Docker Deployment

```bash
# Build and run with Docker Compose
docker-compose up --build

# Or build manually
docker build -t ai-backend .
docker run -p 5000:5000 --env-file .env ai-backend
```

## API Endpoints

### POST /analyze
Analyze an image for objects.

**Request**: Multipart form data with `file` field containing image
**Response**:
```json
{
  "success": true,
  "labels": ["cat", "animal"],
  "confidence": [0.95, 0.87],
  "fallback": false
}
```

### POST /map-ai
Find nearby stores and get directions.

**Request**:
```json
{
  "lat": 37.7749,
  "lng": -122.4194,
  "query": "grocery store"
}
```

**Response**:
```json
{
  "success": true,
  "nearest_store": {...},
  "all_stores": [...],
  "route_info": {...}
}
```

## Environment Variables

- `GOOGLE_MAPS_API_KEY`: Google Maps API key
- `GOOGLE_VISION_API_KEY`: Google Vision API key
- `FLASK_DEBUG`: Enable debug mode (default: false)
- `PORT`: Server port (default: 5000)

## Production Considerations

- API keys are loaded from environment variables
- Comprehensive error handling and logging
- Docker containerization for easy deployment
- Health checks included
- Resource limits configured