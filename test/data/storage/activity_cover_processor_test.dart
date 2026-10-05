import 'package:flutter_test/flutter_test.dart';
import 'package:hangout/data/storage/activity_cover_processor.dart';
import 'package:image/image.dart' as image;

void main() {
  test('resizes and JPEG-encodes activity covers', () async {
    final source = image.Image(width: 2400, height: 1800);
    image.fill(source, color: image.ColorRgb8(220, 80, 60));

    final processed = await prepareActivityCover(image.encodePng(source));
    final decoded = image.decodeJpg(processed);

    expect(decoded, isNotNull);
    expect(decoded!.width, lessThanOrEqualTo(1600));
    expect(decoded.height, lessThanOrEqualTo(1200));
    expect(processed.lengthInBytes, lessThan(maxStoredActivityCoverBytes));
  });
}
