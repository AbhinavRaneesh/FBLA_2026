import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

import 'ml_kit_service.dart';

class _MlKitImageLabelingService implements MlKitImageLabelingService {
  final ImageLabeler _labeler = ImageLabeler(
    options: ImageLabelerOptions(confidenceThreshold: 0.5),
  );

  @override
  Future<List<MlKitLabel>> analyzeImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final labels = await _labeler.processImage(inputImage);

    return labels
        .map(
          (label) => MlKitLabel(
            label: label.label,
            confidence: label.confidence,
          ),
        )
        .toList();
  }

  @override
  Future<void> dispose() => _labeler.close();
}

MlKitImageLabelingService createMlKitImageLabelingServiceImpl() {
  return _MlKitImageLabelingService();
}
