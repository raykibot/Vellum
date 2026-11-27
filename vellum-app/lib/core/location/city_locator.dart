import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

class CityCoord {
  const CityCoord({
    required this.name,
    required this.lat,
    required this.lng,
  });

  final String name;
  final double lat;
  final double lng;

  factory CityCoord.fromJson(Map<String, dynamic> json) {
    return CityCoord(
      name: json['name'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }
}

class CityLocateResult {
  const CityLocateResult({this.city, required this.failed});

  final String? city;
  final bool failed;
}

/// 离线城市级定位解析（仅申请粗略定位并本地匹配最近地级市，0 元零第三方地图依赖）。
class CityLocator {
  static const double _earthRadiusKm = 6371.0;
  static const double _maxMatchDistanceKm = 250.0;

  static List<CityCoord>? _cachedCities;

  static Future<List<CityCoord>> loadCities() async {
    if (_cachedCities != null) return _cachedCities!;
    final raw = await rootBundle.loadString('assets/data/china_cities.json');
    final decoded = jsonDecode(raw) as List<dynamic>;
    _cachedCities = decoded
        .map((item) => CityCoord.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
    return _cachedCities!;
  }

  /// 纯函数匹配最近城市，便于单元测试直接调用。
  static String? findNearestCityFromList(
    double lat,
    double lng,
    List<CityCoord> cities,
  ) {
    String? bestName;
    var bestDist = double.infinity;
    for (final city in cities) {
      final dist = haversineKm(lat, lng, city.lat, city.lng);
      if (dist < bestDist) {
        bestDist = dist;
        bestName = city.name;
      }
    }
    return bestDist <= _maxMatchDistanceKm ? bestName : null;
  }

  static double haversineKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * _earthRadiusKm * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _toRad(double deg) => deg * math.pi / 180.0;

  static Future<List<String>> searchCities(String query) async {
    final cities = await loadCities();
    final q = query.trim();
    if (q.isEmpty) {
      return cities.map((c) => c.name).toList();
    }
    final normalized = q.replaceFirst(RegExp(r'市$'), '');
    return cities
        .where((c) => c.name.contains(q) || c.name.contains(normalized))
        .map((c) => c.name)
        .toList();
  }

  static Future<CityLocateResult> detectCurrentCity() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const CityLocateResult(failed: true);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const CityLocateResult(failed: true);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        ),
      );
      final cities = await loadCities();
      final city = findNearestCityFromList(
        position.latitude,
        position.longitude,
        cities,
      );
      if (city == null) {
        return const CityLocateResult(failed: true);
      }
      return CityLocateResult(city: city, failed: false);
    } catch (_) {
      return const CityLocateResult(failed: true);
    }
  }
}
