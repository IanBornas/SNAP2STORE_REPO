import 'package:geolocator/geolocator.dart';

class LocationService {
  static Future<bool> requestPermission() async {
    // First check whether location services are enabled on the device.
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Prompt user to enable location services. This opens the location settings UI.
      await Geolocator.openLocationSettings();
      // Re-check service status after user returns from settings.
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are permanently denied, open app settings so user can enable.
      await Geolocator.openAppSettings();
      return false;
    }

    return true;
  }

  static Future<Position?> getCurrentPosition() async {
    try {
      bool hasPermission = await requestPermission();
      if (!hasPermission) {
        return null;
      }

      // Optionally, check again if services are enabled before requesting position.
      if (!await Geolocator.isLocationServiceEnabled()) {
        // Try to open settings once to let user enable it.
        await Geolocator.openLocationSettings();
        if (!await Geolocator.isLocationServiceEnabled()) {
          return null;
        }
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }
}