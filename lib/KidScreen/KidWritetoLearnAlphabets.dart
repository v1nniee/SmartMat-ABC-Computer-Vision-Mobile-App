import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:scribble/scribble.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:math';
import '../Screen/AnimatedLoadingIndicator.dart';
import '../Service/ModelManager.dart';

class KidWritetoLearnAlphabets extends StatefulWidget {
  @override
  _KidWritetoLearnAlphabetsState createState() =>
      _KidWritetoLearnAlphabetsState();
}

class _KidWritetoLearnAlphabetsState extends State<KidWritetoLearnAlphabets>
    with SingleTickerProviderStateMixin {
  final ScribbleNotifier _notifier = ScribbleNotifier();
  final GlobalKey _canvasKey = GlobalKey();
  final ModelManager _modelManager = ModelManager();
  final FlutterTts _tts = FlutterTts();
  final ConfettiController _confettiController =
      ConfettiController(duration: const Duration(seconds: 2));
  final ConfettiController _failureConfettiController =
      ConfettiController(duration: const Duration(seconds: 2));
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ImagePicker _picker = ImagePicker();

  File? _image;
  String? _targetLetter;
  String? _detectedClass;
  double? _confidence;
  bool _isProcessing = false;
  double _progressValue = 0.0;
  bool _showSuccessOverlay = false;
  bool _showFailureOverlay = false;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _notifier.setColor(Colors.black);
    _notifier.setStrokeWidth(10.0);
    _initializeTts();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
  }

  Future<void> _initializeTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.2);
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _detectedClass = null;
        _confidence = null;
        _isProcessing = true;
        _progressValue = 0.0;
        _showSuccessOverlay = false;
        _showFailureOverlay = false;
        _targetLetter = null;
      });
      await _processPickedImage();
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _processPickedImage() async {
    if (_image == null) return;
    if (!_modelManager.isAlphabetMapModelLoaded ||
        _modelManager.alphabetMapModel == null) {
      setState(() {
        _isProcessing = false;
      });
      _showErrorDialog('Alphabet map model not loaded');
      return;
    }
    img.Image? image = img.decodeImage(await _image!.readAsBytes());
    if (image == null) {
      setState(() {
        _isProcessing = false;
      });
      _showErrorDialog('Failed to decode image');
      return;
    }
    final padded = img.copyResize(image, width: 640, height: 640);
    final input = List.generate(
      1,
      (_) => List.generate(
        640,
        (y) => List.generate(
          640,
          (x) => List.generate(
            3,
            (c) => padded.getPixel(x, y)[c].toDouble() / 255.0,
          ),
        ),
      ),
    );
    for (int i = 0; i <= 100; i += 10) {
      await Future.delayed(const Duration(milliseconds: 50));
      setState(() {
        _progressValue = i / 100.0;
      });
    }
    var outputTensor = List.filled(1, List.filled(300, List.filled(6, 0.0)));
    _modelManager.alphabetMapModel!.run(input, outputTensor);
    final detections = outputTensor[0];
    double maxConfidence = 0.0;
    double minDistanceToCenter = double.infinity;
    String? bestClass;
    final imageCenterX = 640 / 2;
    final imageCenterY = 640 / 2;
    for (var det in detections) {
      final confidence = det[4];
      if (confidence > 0.5) {
        final classId = det[5].toInt();
        if (classId < _modelManager.labels.length) {
          final xMin = det[0] * 640;
          final yMin = det[1] * 640;
          final xMax = det[2] * 640;
          final yMax = det[3] * 640;

          final boxCenterX = (xMin + xMax) / 2;
          final boxCenterY = (yMin + yMax) / 2;
          final distanceToCenter = sqrt(
            pow(boxCenterX - imageCenterX, 2) +
                pow(boxCenterY - imageCenterY, 2),
          );
          if (confidence > maxConfidence ||
              (confidence == maxConfidence &&
                  distanceToCenter < minDistanceToCenter)) {
            maxConfidence = confidence;
            minDistanceToCenter = distanceToCenter;
            bestClass = _modelManager.labels[classId];
          }
        }
      }
    }

    if (bestClass != null) {
      setState(() {
        _targetLetter = bestClass;
        _confidence = maxConfidence;
      });
      try {
        await _tts.speak(bestClass);
      } catch (e) {
        print('Error speaking letter: $e');
        _showErrorDialog('Failed to pronounce letter');
      }
    } else {
      setState(() {
        _isProcessing = false;
        _targetLetter = null;
      });
      _showErrorDialog('No letter detected. Try again.');
    }
  }

  Future<Uint8List?> _captureScreenshot() async {
    try {
      RenderRepaintBoundary boundary = _canvasKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('Error capturing screenshot: $e');
      return null;
    }
  }
  Future<void> _captureAndProcessCanvas() async {
    if (_targetLetter == null) {
      _showErrorDialog('Please capture a letter first!');
      return;
    }
    Uint8List? screenshot = await _captureScreenshot();
    if (screenshot == null) {
      setState(() {
        _isProcessing = false;
      });
      _showErrorDialog('Failed to capture drawing');
      return;
    }
    setState(() {
      _isProcessing = true;
      _progressValue = 0.0;
      _showSuccessOverlay = false;
      _showFailureOverlay = false;
    });
    if (!_modelManager.isHandwritingModelLoaded ||
        _modelManager.handwritingModel == null) {
      setState(() {
        _isProcessing = false;
      });
      _showErrorDialog('Handwriting model not loaded');
      return;
    }
    img.Image? image = img.decodeImage(screenshot);
    if (image == null) {
      setState(() {
        _isProcessing = false;
      });
      _showErrorDialog('Failed to process drawing');
      return;
    }
    final padded = img.copyResize(image, width: 640, height: 640);
    final input = List.generate(
      1,
      (_) => List.generate(
        640,
        (y) => List.generate(
          640,
          (x) => List.generate(
            3,
            (c) => padded.getPixel(x, y)[c].toDouble() / 255.0,
          ),
        ),
      ),
    );
    for (int i = 0; i <= 100; i += 10) {
      await Future.delayed(Duration(milliseconds: 50));
      setState(() {
        _progressValue = i / 100.0;
      });
    }
    var outputTensor = List.filled(1, List.filled(300, List.filled(6, 0.0)));
    _modelManager.handwritingModel!.run(input, outputTensor);
    final detections = outputTensor[0];
    double maxConfidence = 0.0;
    int bestClassId = -1;
    for (var det in detections) {
      final confidence = det[4];
      if (confidence > 0.4) {
        final classId = det[5].toInt();
        if (classId >= 0 && classId < _modelManager.labels.length) {
          if (confidence > maxConfidence) {
            maxConfidence = confidence;
            bestClassId = classId;
          }
        }
      }
    }
    if (bestClassId != -1) {
      String bestLabel = _modelManager.labels[bestClassId];
      setState(() {
        _detectedClass = bestLabel;
        _confidence = maxConfidence;
      });
      bool isSuccess = bestLabel == _targetLetter;
      if (isSuccess) {
        setState(() {
          _showSuccessOverlay = true;
        });
        _playSuccessFeedback();
      } else {
        setState(() {
          _showFailureOverlay = true;
        });
        _playFailureFeedback();
      }
      await _updateHandwritingProgress(bestLabel, isSuccess);
    } else {
      setState(() {
        _showFailureOverlay = true;
      });
      _playFailureFeedback();
      await _updateHandwritingProgress(_targetLetter, false);
    }
    setState(() {
      _isProcessing = false;
    });
    _notifier.clear();
    _animationController.forward();
    Future.delayed(const Duration(seconds: 3), () {
      setState(() {
        _showSuccessOverlay = false;
        _showFailureOverlay = false;
      });
      _animationController.reset();
    });
  }

  Future<void> _speakDetectedLetter(String letter) async {
    try {
      await _tts.speak(letter);
    } catch (e) {
      print('Error speaking letter: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to speak letter: $e')),
      );
    }
  }

  void _playSuccessFeedback() async {
    _confettiController.play();
    try {
      print('Speaking: Woohoo! You wrote $_detectedClass! You\'re awesome!');
      await _tts.speak('Woohoo! You wrote $_detectedClass! You\'re awesome!');
      print('TTS success playback initiated successfully');
    } catch (e) {
      print('Error speaking success message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to speak message: $e')),
      );
    }
  }

  void _playFailureFeedback() async {
    _failureConfettiController.play();
    try {
      await _tts.speak('Oops! Let\'s try writing $_targetLetter again!');
      await _audioPlayer.play(AssetSource('sound/fail.mp3'));
    } catch (e) {
      print('Error playing failure feedback: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to play feedback: $e')),
      );
    }
  }

  Future<void> _updateHandwritingProgress(
      String? letter, bool isSuccess) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No user logged in');
        return;
      }
      String userId = user.uid;
      DocumentReference progressRef = FirebaseFirestore.instance
          .collection('Kid')
          .doc(userId)
          .collection('WriteToLearnAlphabetProgress')
          .doc('progress');
      DocumentSnapshot snapshot = await progressRef.get();
      if (letter != null) {
        if (snapshot.exists) {
          Map<String, dynamic> progressData =
              snapshot.data() as Map<String, dynamic>;
          int attempts = (progressData[letter]?['attempts'] ?? 0) as int;
          int successfulAttempts =
              (progressData[letter]?['successfulAttempts'] ?? 0) as int;
          await progressRef.set({
            letter: {
              'attempts': attempts + 1,
              'successfulAttempts':
                  isSuccess ? successfulAttempts + 1 : successfulAttempts,
              'lastDetected': FieldValue.serverTimestamp(),
            }
          }, SetOptions(merge: true));
        } else {
          await progressRef.set({
            letter: {
              'attempts': 1,
              'successfulAttempts': isSuccess ? 1 : 0,
              'lastDetected': FieldValue.serverTimestamp(),
            }
          }, SetOptions(merge: true));
        }
      }
    } catch (e) {
      print('Error updating handwriting progress: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Oops!',
            style: GoogleFonts.balsamiqSans(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.redAccent,
            ),
          ),
          content: Text(
            message,
            style: GoogleFonts.balsamiqSans(
              fontSize: 18,
              color: Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'OK',
                style: GoogleFonts.balsamiqSans(
                  fontSize: 20,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _captureAndSaveToGallery() async {
    try {
      Uint8List? screenshot = await _captureScreenshot();
      if (screenshot == null) {
        _showErrorDialog('Failed to capture drawing');
        return;
      }

      await Gal.putImageBytes(screenshot, album: 'HandwritingDrawings');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Drawing saved to gallery',
            style: TextStyle(
              fontFamily: 'BalsamiqSans',
              fontSize: 16,
            ),
          ),
          backgroundColor: Colors.green[400],
        ),
      );
    } catch (e) {
      print('Error saving to gallery: $e');
      _showErrorDialog('Failed to save drawing');
    }
  }

  void _clearCanvasAndResults() {
    setState(() {
      _notifier.clear();
      _detectedClass = null;
      _confidence = null;
    });
  }

  @override
  void dispose() {
    _notifier.dispose();
    _tts.stop();
    _confettiController.dispose();
    _failureConfettiController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final canvasSize = screenSize.width * 0.916;

    return Scaffold(
      backgroundColor: Color(0xFFFFFADD),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFEE82),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Write to Learn Alphabets',
          style: GoogleFonts.balsamiqSans(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 15),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Text(
                      'Step 1: Capture a Letter on the Map',
                      style: GoogleFonts.balsamiqSans(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 10),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: const Color(0xFFFFEE82), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _image == null
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.image_search,
                                      size: 60,
                                      color: Colors.black,
                                    ),
                                    SizedBox(height: 10),
                                    Text(
                                      'Take or pick a photo here!',
                                      style: GoogleFonts.balsamiqSans(
                                        fontSize: 18,
                                        color: Colors.black,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Image.file(
                                  _image!,
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                  height: 200,
                                ),
                              ),
                        if (_isProcessing && _targetLetter == null)
                          AnimatedLoadingIndicator(
                              progressValue: _progressValue),
                      ],
                    ),
                  ),
                  SizedBox(height: 15),
                  GestureDetector(
                    onTap: () => _pickImage(ImageSource.camera),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEE82),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.camera_alt,
                              size: 28, color: Colors.black),
                          const SizedBox(width: 10),
                          Text(
                            'Take a Photo',
                            style: GoogleFonts.balsamiqSans(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 15),
                  GestureDetector(
                    onTap: () => _pickImage(ImageSource.gallery),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEE82),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.photo_library,
                              size: 28, color: Colors.black),
                          const SizedBox(width: 10),
                          Text(
                            'Pick a Picture',
                            style: GoogleFonts.balsamiqSans(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 25),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Text(
                      'Step 2: Write the Letter',
                      style: GoogleFonts.balsamiqSans(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 20),
                  if (_targetLetter != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Text(
                        '$_targetLetter',
                        style: GoogleFonts.balsamiqSans(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  SizedBox(height: 10),
                  Stack(
                    children: [
                      Container(
                        height: canvasSize,
                        width: canvasSize,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFFFFEE82), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: _targetLetter == null
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons
                                          .create, // This is the "drawing pen" icon
                                      size: 60,
                                      color: Colors.black,
                                    ),
                                    const SizedBox(
                                        height:
                                            10), // Small space between icon and text
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20),
                                      child: Text(
                                        'Write the letter here after capturing a letter on the map!',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.balsamiqSans(
                                          fontSize: 18,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : RepaintBoundary(
                                key: _canvasKey,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Container(
                                        color: Colors.white,
                                        child: Scribble(
                                          notifier: _notifier,
                                          drawPen: true,
                                        ),
                                      ),
                                      if (_isProcessing &&
                                          _targetLetter != null)
                                        AnimatedLoadingIndicator(
                                            progressValue: _progressValue),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                      if (_targetLetter != null)
                        Positioned(
                          top: 10,
                          left: 10,
                          child: ElevatedButton(
                            onPressed: _clearCanvasAndResults,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[400],
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.cleaning_services,
                                    color: Colors.white, size: 30),
                                SizedBox(width: 6),
                                Text(
                                  'Erase',
                                  style: GoogleFonts.balsamiqSans(
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_targetLetter != null)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: ElevatedButton(
                            onPressed: _captureAndSaveToGallery,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[400],
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.save_alt,
                                    color: Colors.white, size: 30),
                                SizedBox(width: 4),
                                Text(
                                  'Save',
                                  style: GoogleFonts.balsamiqSans(
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: const Color(0xFFFFEE82), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'You just wrote..',
                          style: GoogleFonts.balsamiqSans(
                            fontSize: 16,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.create,
                              color: Colors.black,
                              size: 28,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _detectedClass ?? '',
                              style: GoogleFonts.balsamiqSans(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  GestureDetector(
                    onTap:
                        _targetLetter != null ? _captureAndProcessCanvas : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: _targetLetter != null
                            ? const Color(0xFFFFEE82)
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline,
                              size: 28, color: Colors.black),
                          const SizedBox(width: 10),
                          Text(
                            'Check Handwriting',
                            style: GoogleFonts.balsamiqSans(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                particleDrag: 0.05,
                emissionFrequency: 0.02,
                numberOfParticles: 30,
                gravity: 0.3,
                shouldLoop: false,
                colors: const [
                  Colors.red,
                  Colors.blue,
                  Colors.green,
                  Colors.yellow,
                  Colors.purple,
                ],
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _failureConfettiController,
                blastDirection: pi / 2,
                emissionFrequency: 0.02,
                numberOfParticles: 25,
                gravity: 0.3,
                shouldLoop: false,
                colors: const [Colors.redAccent],
              ),
            ),
            if (_showSuccessOverlay)
              AnimatedOpacity(
                opacity: _showSuccessOverlay ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Center(
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: screenSize.width * 0.8,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFFFFEE82), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 60,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '🎉 Woohoo! You wrote "$_detectedClass"! You\'re awesome!',
                            style: GoogleFonts.balsamiqSans(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (_showFailureOverlay)
              AnimatedOpacity(
                opacity: _showFailureOverlay ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Center(
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: screenSize.width * 0.8,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFFFFEE82), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.sentiment_dissatisfied,
                            color: Colors.redAccent,
                            size: 60,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '😕 Oops! Let\'s try writing "$_targetLetter" again!',
                            style: GoogleFonts.balsamiqSans(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.redAccent,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
