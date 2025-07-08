import 'package:tflite_flutter/tflite_flutter.dart';
class ModelManager {
  static final ModelManager _instance = ModelManager._internal();
  Interpreter? _handwritingModel;
  Interpreter? _alphabetMapModel;
  bool _isHandwritingModelLoaded = false;
  bool _isAlphabetMapModelLoaded = false;
  final List<String> labels = List.generate(26, (index) => String.fromCharCode(65 + index));
  factory ModelManager() {
    return _instance;
  }
  ModelManager._internal();
  Future<void> loadModels() async {
    await _loadHandwritingModel();
    await _loadAlphabetMapModel();
  }
  Future<void> _loadHandwritingModel() async {
    if (_isHandwritingModelLoaded) return;
    try {
      _handwritingModel = await Interpreter.fromAsset(
        'assets/models/HandwritingDetection.tflite',
        options: InterpreterOptions()..useNnApiForAndroid = true,
      );
      _handwritingModel!.allocateTensors();
      _isHandwritingModelLoaded = true;
      print('Handwriting model loaded successfully');
    } catch (e) {
      print('Error loading handwriting model: $e');
    }
  }
  Future<void> _loadAlphabetMapModel() async {
    if (_isAlphabetMapModelLoaded) return;
    try {
      _alphabetMapModel = await Interpreter.fromAsset(
        'assets/models/AlphabetMapDetection_best_float32.tflite',
        options: InterpreterOptions()..useNnApiForAndroid = true,
      );
      _alphabetMapModel!.allocateTensors();
      _isAlphabetMapModelLoaded = true;
      print('Alphabet map model loaded successfully');
    } catch (e) {
      print('Error loading alphabet map model: $e');
    }
  }
  Interpreter? get handwritingModel => _handwritingModel;
  Interpreter? get alphabetMapModel => _alphabetMapModel;
  bool get isHandwritingModelLoaded => _isHandwritingModelLoaded;
  bool get isAlphabetMapModelLoaded => _isAlphabetMapModelLoaded;
  void dispose() {
    _handwritingModel?.close();
    _alphabetMapModel?.close();
    _isHandwritingModelLoaded = false;
    _isAlphabetMapModelLoaded = false;
  }
}

