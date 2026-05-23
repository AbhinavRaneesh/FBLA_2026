import 'ml_kit_service.dart';

class _MlKitUnsupportedService implements MlKitImageLabelingService {
  @override
  Future<List<MlKitLabel>> analyzeImage(String imagePath) async {
    throw UnsupportedError(
      'ML Kit image labeling is only available on Android and iOS devices.',
    );
  }

  @override
  Future<void> dispose() async {}
}

MlKitImageLabelingService createMlKitImageLabelingServiceImpl() {
  return _MlKitUnsupportedService();
}
