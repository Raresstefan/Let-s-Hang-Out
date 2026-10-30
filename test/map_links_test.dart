import 'package:flutter_test/flutter_test.dart';
import 'package:hangout/features/activity_details/map_links.dart';

void main() {
  const place = 'Central Park courts & café';
  const q = 'Central%20Park%20courts%20%26%20caf%C3%A9';

  test('Google Maps links search the encoded place', () {
    final l = MapLink.forPlace(MapApp.googleMaps, place);
    expect(l.web.toString(),
        'https://www.google.com/maps/search/?api=1&query=$q');
    expect(l.native.toString(), 'comgooglemaps://?q=$q');
  });

  test('Apple Maps uses the universal link only', () {
    final l = MapLink.forPlace(MapApp.appleMaps, place);
    expect(l.web.toString(), 'https://maps.apple.com/?q=$q');
    expect(l.native, isNull);
  });

  test('Waze links start navigation', () {
    final l = MapLink.forPlace(MapApp.waze, place);
    expect(l.web.toString(), 'https://waze.com/ul?q=$q&navigate=yes');
    expect(l.native.toString(), 'waze://?q=$q&navigate=yes');
  });

  test('Other apps uses the Android geo intent', () {
    final l = MapLink.forPlace(MapApp.otherApps, '  $place ');
    expect(l.web.toString(), 'geo:0,0?q=$q');
  });
}
