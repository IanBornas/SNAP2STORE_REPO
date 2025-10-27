import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';

class BackendService {
  static const String baseUrl = 'http://127.0.0.1:5000'; // Update this for production

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