import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_app/services/backend_service.dart';
import 'package:flutter_app/services/location_service.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  GoogleMapController? mapController;
  final LatLng _center = const LatLng(14.5995, 120.9842);
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  bool _isSearchingStores = false;
  Map<String, dynamic>? _storeResults;
  String? _errorMessage;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    // Delay location request to avoid immediate errors on map initialization
    Future.delayed(const Duration(seconds: 1), () {
      _getCurrentLocation();
    });
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _errorMessage = null;
    });

    try {
      final position = await LocationService.getCurrentPosition();
      if (position != null) {
        setState(() {
          _currentPosition = position;
          _isLoadingLocation = false;
        });

        // Move camera to current location
        mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(position.latitude, position.longitude),
            15.0,
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'Unable to get location. Please check permissions.';
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      // Only show error if it's not a permission/initialization issue
      if (!e.toString().contains('permission') && !e.toString().contains('denied')) {
        setState(() {
          _errorMessage = 'Error getting location: $e';
        });
      }
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _findNearbyStores() async {
    if (_currentPosition == null) {
      setState(() {
        _errorMessage = 'Current location not available';
      });
      return;
    }

    setState(() {
      _isSearchingStores = true;
      _errorMessage = null;
      _storeResults = null;
      _markers.clear();
    });

    try {
      final results = await BackendService.findNearbyStores(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      setState(() {
        _storeResults = results;
        _isSearchingStores = false;
      });

      // Add markers for stores
      _addStoreMarkers(results);
    } catch (e) {
      setState(() {
        _errorMessage = 'Error finding stores: $e';
        _isSearchingStores = false;
      });
    }
  }

  void _addStoreMarkers(Map<String, dynamic> results) {
    final stores = results['all_stores'] as List;
    final markers = <Marker>{};

    // Add current location marker
    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          infoWindow: const InfoWindow(title: 'Your Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    // Add store markers
    for (int i = 0; i < stores.length; i++) {
      final store = stores[i];
      markers.add(
        Marker(
          markerId: MarkerId('store_$i'),
          position: LatLng(store['lat'], store['lng']),
          infoWindow: InfoWindow(
            title: store['name'],
            snippet: store['vicinity'],
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  @override
  void dispose() {
    // Dispose the map controller to free native resources (prevents
    // leaking ImageReader/Surface buffers on Android when the page is
    // opened/closed repeatedly).
    mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(target: _center, zoom: 11.0),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),

          // Top control panel
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Location status
                    if (_isLoadingLocation)
                      const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Getting your location...'),
                        ],
                      )
                    else if (_currentPosition != null)
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Location: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 12),

                    // Store search button
                    ElevatedButton.icon(
                      onPressed: (_isSearchingStores || _currentPosition == null)
                          ? null
                          : _findNearbyStores,
                      icon: _isSearchingStores
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.store),
                      label: Text(_isSearchingStores ? 'Searching...' : 'Find Nearby Stores'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                      ),
                    ),

                    // Error message
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Store results panel
          if (_storeResults != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Card(
                elevation: 4,
                child: Container(
                  height: 200,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nearby Stores',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: (_storeResults!['all_stores'] as List).length,
                          itemBuilder: (context, index) {
                            final store = _storeResults!['all_stores'][index];
                            return ListTile(
                              leading: const Icon(Icons.store, color: Colors.teal),
                              title: Text(store['name']),
                              subtitle: Text(store['vicinity']),
                              trailing: Text('${store['rating']} ⭐'),
                              onTap: () {
                                mapController?.animateCamera(
                                  CameraUpdate.newLatLngZoom(
                                    LatLng(store['lat'], store['lng']),
                                    18.0,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}