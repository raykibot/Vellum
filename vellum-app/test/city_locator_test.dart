import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vellum_app/core/location/city_locator.dart';

void main() {
  group('CityLocator offline nearest-city matching', () {
    late List<CityCoord> cities;

    setUpAll(() {
      final raw = File('assets/data/china_cities.json').readAsStringSync();
      final decoded = jsonDecode(raw) as List<dynamic>;
      cities = decoded
          .map((e) => CityCoord.fromJson(e as Map<String, dynamic>))
          .toList();
    });

    test('matches Shenzhen, Hangzhou, and Beijing coordinates accurately', () {
      expect(
        CityLocator.findNearestCityFromList(22.54, 114.06, cities),
        '深圳市',
      );
      expect(
        CityLocator.findNearestCityFromList(30.27, 120.15, cities),
        '杭州市',
      );
      expect(
        CityLocator.findNearestCityFromList(39.90, 116.40, cities),
        '北京市',
      );
    });

    test('returns null for coordinates outside 250km threshold', () {
      expect(
        CityLocator.findNearestCityFromList(35.6762, 139.6503, cities),
        isNull,
      );
    });
  });
}
