import 'ml_kit_service_stub.dart' if (dart.library.io) 'ml_kit_service_io.dart';

class MlKitLabel {
  final String label;
  final double confidence;

  const MlKitLabel({
    required this.label,
    required this.confidence,
  });
}

abstract class MlKitImageLabelingService {
  Future<List<MlKitLabel>> analyzeImage(String imagePath);

  Future<void> dispose();
}

MlKitImageLabelingService createMlKitImageLabelingService() {
  return createMlKitImageLabelingServiceImpl();
}
