import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangout/core/widgets/image_pick.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

class _PhotosPicker extends ImagePickerPlatform {
  XFile? photo;
  ImageSource? source;
  ImagePickerOptions? options;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    this.source = source;
    this.options = options;
    return photo;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
  late List<MethodCall> calls;
  Object? result;
  late ImagePickerPlatform originalPicker;
  late _PhotosPicker photos;

  setUp(() {
    originalPicker = ImagePickerPlatform.instance;
    photos = _PhotosPicker()
      ..photo = XFile.fromData(
        Uint8List.fromList([1, 2, 3]),
        path: '/tmp/photo.jpg',
      );
    ImagePickerPlatform.instance = photos;
    calls = [];
    result = [
      {
        'name': 'photo.jpg',
        'path': '/tmp/photo.jpg',
        'size': 3,
        'bytes': Uint8List.fromList([1, 2, 3]),
      },
    ];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return result;
        });
  });

  tearDown(() {
    ImagePickerPlatform.instance = originalPicker;
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('iOS opens Photos and returns validated image bytes', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final picked = await PickedImage.browse();
    expect(calls, isEmpty);
    expect(photos.source, ImageSource.gallery);
    expect(photos.options!.imageQuality, 90);
    expect(photos.options!.requestFullMetadata, isFalse);
    expect(picked!.ok, isTrue);
    expect(picked.contentType, 'image/jpeg');
  });

  test('Android keeps the existing extension-filtered picker', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await PickedImage.browse();
    expect(calls.single.method, 'custom');
    expect(calls.single.arguments['allowedExtensions'], kImageExtensions);
  });

  test('cancelling Photos returns no image', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    photos.photo = null;
    expect(await PickedImage.browse(), isNull);
  });

  test('Photos selection still rejects unsupported file formats', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    photos.photo = XFile.fromData(
      Uint8List.fromList([1]),
      path: '/tmp/animation.gif',
    );
    expect((await PickedImage.browse())!.error, isNotNull);
  });
}
