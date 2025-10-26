import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_app/services/backend_service.dart';
import 'package:flutter_app/services/location_service.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _analysisResult;
  Map<String, dynamic>? _storesResult;
  String? _errorMessage;

  Future<void> _pickAndAnalyzeImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() {
        _selectedImage = image;
        _isAnalyzing = true;
        _errorMessage = null;
        _analysisResult = null;
        _storesResult = null;
      });

      // Get user location
      final position = await LocationService.getCurrentPosition();
      if (position == null) {
        throw Exception('Unable to get location. Please enable location services.');
      }

      // Analyze image and find stores in one call
      final result = await BackendService.analyzeAndFindStores(
        image.path,
        position.latitude,
        position.longitude,
      );

      setState(() {
        _analysisResult = result['analysis'];
        _storesResult = result['stores'];
        _isAnalyzing = false;
      });

      // Show message if no media detected
      if (result['analysis']['media_type'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['analysis']['message'] ?? 'No media detected in this image'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isAnalyzing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Discover Page'),
          backgroundColor: Colors.teal,
          bottom: const TabBar(
            indicatorColor: Color.fromARGB(255, 44, 41, 41),
            tabs: [
              Tab(icon: Icon(Icons.place_outlined), text: 'Near you'),
              Tab(icon: Icon(Icons.new_releases_outlined), text: 'Something new'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Near you tab - Image Analysis
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    'Find Media Near You',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Take a photo of a book, movie, game, or other media to find stores that carry it nearby',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isAnalyzing ? null : _pickAndAnalyzeImage,
                    icon: const Icon(Icons.image),
                    label: const Text('Select Media Image'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Selected Image Preview
                  if (_selectedImage != null)
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: kIsWeb
                          ? Image.network(
                              _selectedImage!.path,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                                  ),
                                );
                              },
                            )
                          : Image.file(
                              File(_selectedImage!.path),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                                  ),
                                );
                              },
                            ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Loading Indicator
                  if (_isAnalyzing)
                    const Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 8),
                        Text('Analyzing media and finding stores...'),
                      ],
                    ),

                  // Error Message
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Error: $_errorMessage',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),

                  // Analysis Results
                  if (_analysisResult != null)
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Analysis Results:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_analysisResult!['media_type'] != null)
                              Text(
                                'Media Type: ${_analysisResult!['media_type']?.toString().toUpperCase() ?? 'Unknown'}',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal),
                              )
                            else
                              Text(
                                'No Media Detected',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange),
                              ),
                            const SizedBox(height: 8),
                            if (_analysisResult!['media_type'] != null)
                              Text(
                                'Search Query: ${_analysisResult!['search_query'] ?? 'N/A'}',
                                style: const TextStyle(fontSize: 16),
                              ),
                            const SizedBox(height: 12),
                            Text(
                              'Labels: ${(_analysisResult!['labels'] as List).join(', ')}',
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Confidence: ${(_analysisResult!['confidence'] as List).map((c) => '${(c * 100).toStringAsFixed(1)}%').join(', ')}',
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Using Fallback: ${_analysisResult!['fallback'] ? 'Yes' : 'No'}',
                              style: TextStyle(
                                fontSize: 14,
                                color: _analysisResult!['fallback'] ? Colors.orange : Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Stores Results - only show if media was detected
                    if (_storesResult != null && _analysisResult!['media_type'] != null)
                      Container(
                        margin: const EdgeInsets.only(top: 16),
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Nearby Stores:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...(_storesResult!['all_stores'] as List).map((store) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                '${store['name']} - ${store['vicinity']}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            )),
                            const SizedBox(height: 12),
                            if (_storesResult!['nearest_store'] != null)
                              Text(
                                'Nearest: ${(_storesResult!['nearest_store'] as Map)['name']} (${(_storesResult!['route_info'] as Map?)?['distance'] ?? 'Distance unavailable'})',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                          ],
                        ),
                      ),
                ],
              ),
            ),

            // Something new tab - placeholder
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.new_releases, size: 64, color: theme.colorScheme.primary),
                    const SizedBox(height: 12),
                    Text('New finds will appear here', style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
