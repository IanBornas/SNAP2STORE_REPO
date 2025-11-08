import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';

// Allow overriding the API base URL at build time:
// flutter build apk --release --dart-define=API_BASE_URL=https://api.example.com
const String kApiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');

class BackendService {
  // Base URL selection rules:
  // 1) If API_BASE_URL is passed via --dart-define, use it (prod/staging).
  // 2) Otherwise, use platform-aware localhost defaults for development.
  static String get baseUrl {
    if (kApiBaseUrl.isNotEmpty) return kApiBaseUrl;
    if (kIsWeb) return 'http://127.0.0.1:5000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android emulator maps host 127.0.0.1 to 10.0.2.2
      return 'http://10.0.2.2:5000';
    }
    return 'http://127.0.0.1:5000'; // iOS simulator / desktop
  }

  // Lightweight healthcheck/warmup that can be called on app start.
  // This also triggers model loading on the backend to reduce first-request latency.
  static Future<bool> ping() async {
    try {
      if (kDebugMode) {
        print('[BackendService] Warming up AI backend at $baseUrl...');
      }
      // Use /warmup endpoint to explicitly trigger model initialization
      final resp = await http
          .get(Uri.parse('$baseUrl/warmup'))
          .timeout(const Duration(seconds: 10));
      
      if (resp.statusCode == 200) {
        if (kDebugMode) {
          final data = json.decode(resp.body);
          print('[BackendService] ✓ Backend is ready and responding');
          print('[BackendService] Models loaded: ${data['models']}');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('[BackendService] ⚠ Backend responded with status ${resp.statusCode}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('[BackendService] ⚠ Backend warmup failed: $e');
        print('[BackendService] → This is OK if testing offline or backend not started');
      }
      return false;
    }
  }

  // Helper methods for web file handling
  static Future<Uint8List> _readFileAsBytesWeb(String filePath) async {
    // For web, we need to use a different approach since file paths are blob URLs
    final response = await http.get(Uri.parse(filePath));
    return response.bodyBytes;
  }

  static String _getFileNameFromPath(String path) {
    return path.split('/').last.split('?').first;
  }

  static String _getFileExtension(String path) {
    final fileName = _getFileNameFromPath(path);
    final dotIndex = fileName.lastIndexOf('.');
    return dotIndex != -1 ? fileName.substring(dotIndex + 1) : 'jpg';
  }

  static Future<Map<String, dynamic>> analyzeImage(String imagePath) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/analyze'));

      if (kIsWeb) {
        // For web: read file as bytes and create multipart file
        var bytes = await _readFileAsBytesWeb(imagePath);
        var multipartFile = http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: 'image.${_getFileExtension(imagePath).toLowerCase()}',
          contentType: MediaType('image', _getFileExtension(imagePath).toLowerCase()),
        );
        request.files.add(multipartFile);
      } else {
        // For mobile: use the existing method
        request.files.add(await http.MultipartFile.fromPath('file', imagePath));
      }

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonResponse = json.decode(responseData);

      if (response.statusCode == 200 && jsonResponse['success'] == true) {
        return jsonResponse;
      } else {
        throw Exception(jsonResponse['error'] ?? 'Analysis failed');
      }
    } catch (e) {
      throw Exception('Failed to analyze image: $e');
    }
  }

  static Future<Map<String, dynamic>> findNearbyStores(double lat, double lng, {String query = 'media store'}) async {
    try {
      var response = await http.post(
        Uri.parse('$baseUrl/map-ai'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'lat': lat,
          'lng': lng,
          'query': query,
        }),
      );

      var jsonResponse = json.decode(response.body);

      if (response.statusCode == 200 && jsonResponse['success'] == true) {
        return jsonResponse;
      } else {
        throw Exception(jsonResponse['error'] ?? 'Store search failed');
      }
    } catch (e) {
      throw Exception('Failed to find nearby stores: $e');
    }
  }

  static Future<Map<String, dynamic>> analyzeAndFindStores(String imagePath, double lat, double lng) async {
    try {
      // First, analyze the image
      var analysisResult = await analyzeImage(imagePath);

      // Check if media was detected
      if (analysisResult['media_type'] == null) {
        return {
          'success': true,
          'analysis': analysisResult,
          'stores': null,
          'message': 'No media detected in the image',
        };
      }

      // Extract the search query from analysis
      String searchQuery = analysisResult['search_query'] ?? 'media store';

      // Then find stores using the identified media type
      var storesResult = await findNearbyStores(lat, lng, query: searchQuery);

      // Combine results
      return {
        'success': true,
        'analysis': analysisResult,
        'stores': storesResult,
        'media_type': analysisResult['media_type'],
        'search_query': searchQuery,
      };
    } catch (e) {
      throw Exception('Failed to analyze and find stores: $e');
    }
  }
}