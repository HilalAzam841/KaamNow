import 'package:geolocator/geolocator.dart';

import 'format.dart';

class LocationFix {
  LocationFix(this.latitude, this.longitude, {this.accuracy, this.speedKmh, this.heading});
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? speedKmh;
  final double? heading;
}

/// Browser / device GPS. Returns null with a reason when location is unavailable.
class LocationService {
  Future<(LocationFix?, String?)> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return (null, strings.locationOff);
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return (null, strings.locationDenied);
      }
      final p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)));
      return (
        LocationFix(p.latitude, p.longitude,
            accuracy: p.accuracy, speedKmh: p.speed >= 0 ? p.speed * 3.6 : null, heading: p.heading >= 0 ? p.heading : null),
        null
      );
    } catch (e) {
      return (null, strings.couldNotGetLocation);
    }
  }
}
