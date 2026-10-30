import 'package:flutter_test/flutter_test.dart';
import 'package:hangout/core/links/activity_links.dart';

void main() {
  String? id(String s) => ActivityLinks.activityId(Uri.parse(s));

  test('url round-trips through activityId', () {
    final url = ActivityLinks.url('AbC123_-x');
    expect(url, 'https://hang-out-129b5.web.app/a/AbC123_-x');
    expect(id(url), 'AbC123_-x');
  });

  test('accepts hosting links, trailing slash and query', () {
    expect(id('https://hang-out-129b5.web.app/a/xyz/'), 'xyz');
    expect(id('https://hang-out-129b5.web.app/a/xyz?utm_source=wa'), 'xyz');
    expect(id('https://hang-out-129b5.firebaseapp.com/a/xyz'), 'xyz');
  });

  test('accepts the custom scheme', () {
    expect(id('hangout://activity/xyz'), 'xyz');
  });

  test('rejects other hosts, paths, schemes and bad ids', () {
    expect(id('https://evil.example/a/xyz'), isNull);
    expect(id('http://hang-out-129b5.web.app/a/xyz'), isNull);
    expect(id('https://hang-out-129b5.web.app/b/xyz'), isNull);
    expect(id('https://hang-out-129b5.web.app/a'), isNull);
    expect(id('https://hang-out-129b5.web.app/a/x/y'), isNull);
    expect(id('hangout://circle/xyz'), isNull);
    expect(id('hangout://activity/a%20b'), isNull);
    expect(id('hangout://activity/${'x' * 129}'), isNull);
  });
}
