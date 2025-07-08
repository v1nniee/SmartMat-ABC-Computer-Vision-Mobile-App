import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:scribble/scribble.dart';
import 'package:image/image.dart' as img;
import 'package:confetti/confetti.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../Screen/AnimatedLoadingIndicator.dart';
import '../Service/ModelManager.dart';
import 'dart:math';

class KidWritetoLearnWord extends StatefulWidget {
  @override
  _KidWritetoLearnWordState createState() => _KidWritetoLearnWordState();
}

class _KidWritetoLearnWordState extends State<KidWritetoLearnWord> with SingleTickerProviderStateMixin {
  final ScribbleNotifier _notifier = ScribbleNotifier();
  final GlobalKey _canvasKey = GlobalKey();
  final ModelManager _modelManager = ModelManager();
  final ConfettiController _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  final ConfettiController _failureConfettiController = ConfettiController(duration: const Duration(seconds: 3));
  final FlutterTts _tts = FlutterTts();

  String? _detectedLetter;
  double? _confidence;
  bool _isProcessing = false;
  double _progressValue = 0.0;

  List<String> _capturedLetters = [];
  List<double> _capturedConfidences = [];
  String _targetWord = "";
  bool _wordCompleted = false;
  bool _showSuccessOverlay = false;
  bool _showFailureOverlay = false;

  String? _selectedLevel = 'Level 1';
  final List<String> _levels = ['Level 1', 'Level 2', 'Level 3', 'Level 4', 'Level 5'];
  List<String> _wordsForLevel = [];
  int _currentWordIndex = 0;
  bool _isLoadingWords = true;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _fetchWordsForLevel(_selectedLevel!);
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

  Future<void> _fetchWordsForLevel(String level) async {
    setState(() {
      _isLoadingWords = true;
      _wordsForLevel = [];
      _targetWord = "";
      _currentWordIndex = 0;
      _capturedLetters.clear();
      _capturedConfidences.clear();
      _wordCompleted = false;
      _showSuccessOverlay = false;
      _showFailureOverlay = false;
      _detectedLetter = null;
      _confidence = null;
    });

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('Word Formation')
          .doc(level)
          .collection(level)
          .orderBy('createdAt', descending: true)
          .get();

      List<String> words = snapshot.docs.map((doc) => doc['word'] as String).toList();

      setState(() {
        _wordsForLevel = words;
        _targetWord = words.isNotEmpty ? words[_currentWordIndex] : "No words available";
        _isLoadingWords = false;
      });
    } catch (e) {
      print('Error fetching words: $e');
      setState(() {
        _isLoadingWords = false;
        _targetWord = "Error loading words";
      });
    }
  }

  void _previousWord() {
    if (_currentWordIndex > 0) {
      setState(() {
        _currentWordIndex--;
        _targetWord = _wordsForLevel[_currentWordIndex];
        _reset();
      });
    }
  }

  void _nextWord() {
    if (_currentWordIndex < _wordsForLevel.length - 1) {
      setState(() {
        _currentWordIndex++;
        _targetWord = _wordsForLevel[_currentWordIndex];
        _reset();
      });
    }
  }

  Future<Uint8List?> _captureScreenshot() async {
    try {
      RenderRepaintBoundary boundary = _canvasKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('Error capturing screenshot: $e');
      return null;
    }
  }

  Future<void> _captureAndProcessCanvas() async {
    if (_capturedLetters.length >= _targetWord.length || _wordCompleted) return;

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

    if (!_modelManager.isHandwritingModelLoaded || _modelManager.handwritingModel == null) {
      setState(() {
        _isProcessing = false;
      });
      _showErrorDialog('Model not loaded');
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
      _detectedLetter = _modelManager.labels[bestClassId];
      _confidence = maxConfidence;
      _capturedLetters.add(_detectedLetter!);
      _capturedConfidences.add(maxConfidence);

      await _speakDetectedLetter(_detectedLetter!, onComplete: () {
        setState(() {
          _isProcessing = false;
        });
        _notifier.clear();

        if (_capturedLetters.length == _targetWord.length) {
          _finishWordFormation();
        }
      });
    } else {
      setState(() {
        _isProcessing = false;
      });
      _showErrorDialog('Letter not detected');
      _notifier.clear();
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Oops!',
            style: TextStyle(
              color: Colors.redAccent,
              fontFamily: 'BalsamiqSans',
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            message,
            style: TextStyle(
              fontFamily: 'BalsamiqSans',
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
                style: TextStyle(
                  color: Colors.black,
                  fontFamily: 'BalsamiqSans',
                  fontSize: 20,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _speakDetectedLetter(String letter, {VoidCallback? onComplete}) async {
    try {
      print('Speaking letter: $letter');
      await _tts.speak(letter);
      _tts.setCompletionHandler(() {
        print('TTS completed for letter: $letter');
        if (onComplete != null) {
          onComplete();
        }
      });
    } catch (e) {
      print('Error speaking letter: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to speak letter: $e')),
      );
      if (onComplete != null) onComplete();
    }
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

  void _playSuccessFeedback() async {
    _confettiController.play();
    try {
      print('Speaking word: $_targetWord');
      await _tts.speak('Woohoo! You made the word $_targetWord! You\'re awesome!');
      print('TTS word playback initiated successfully');
    } catch (e) {
      print('Error speaking word: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to speak word: $e')),
      );
    }
  }

  void _playFailureFeedback() async {
    _failureConfettiController.play();
    try {
      print('Speaking: Try again');
      await _tts.speak("Oopsies! Let's try spelling $_targetWord again!");
      print('TTS failure message playback initiated successfully');
    } catch (e) {
      print('Error speaking failure message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to speak message: $e')),
      );
    }
  }

  void _finishWordFormation() {
    setState(() {
      _wordCompleted: true;
    });

    String formedWord = _capturedLetters.join();
    bool isSuccessful = formedWord == _targetWord;

    _updateHandwritingProgress(_targetWord, isSuccessful);

    if (isSuccessful) {
      setState(() {
        _showSuccessOverlay = true;
      });
      _animationController.forward();
      _playSuccessFeedback();
      Future.delayed(const Duration(seconds: 3), () {
        setState(() {
          _showSuccessOverlay = false;
        });
        _animationController.reset();
        _reset();
      });
    } else {
      setState(() {
        _showFailureOverlay = true;
      });
      _animationController.forward();
      _playFailureFeedback();
      Future.delayed(const Duration(seconds: 3), () {
        setState(() {
          _showFailureOverlay = false;
        });
        _animationController.reset();
        _reset();
      });
    }
  }

  void _reset() {
    setState(() {
      _capturedLetters.clear();
      _capturedConfidences.clear();
      _detectedLetter = null;
      _confidence = null;
      _wordCompleted = false;
      _showSuccessOverlay = false;
      _showFailureOverlay = false;
    });
    _notifier.clear();
  }

  Future<void> _updateHandwritingProgress(String word, bool isSuccessful) async {
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
          .collection('WriteToFormWordProgress')
          .doc('progress');

      DocumentSnapshot snapshot = await progressRef.get();

      if (snapshot.exists) {
        Map<String, dynamic> progressData = snapshot.data() as Map<String, dynamic>;
        int totalAttempts = (progressData[word]?['attempts'] ?? 0) as int;
        int successfulAttempts = (progressData[word]?['successfulAttempts'] ?? 0) as int;

        int newSuccessfulAttempts = isSuccessful ? successfulAttempts + 1 : successfulAttempts;

        await progressRef.set({
          word: {
            'attempts': totalAttempts + 1,
            'successfulAttempts': newSuccessfulAttempts,
            'lastDetected': FieldValue.serverTimestamp(),
          }
        }, SetOptions(merge: true));
      } else {
        await progressRef.set({
          word: {
            'attempts': 1,
            'successfulAttempts': isSuccessful ? 1 : 0,
            'lastDetected': FieldValue.serverTimestamp(),
          }
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Error updating HandwritingWordFormationProgress for $word: $e');
    }
  }

  void _backspace() {
    if (_capturedLetters.isNotEmpty) {
      setState(() {
        _capturedLetters.removeLast();
        _capturedConfidences.removeLast();
        _detectedLetter = _capturedLetters.isNotEmpty ? _capturedLetters.last : null;
        _confidence = _capturedConfidences.isNotEmpty ? _capturedConfidences.last : null;
        _wordCompleted = false;
      });
      _notifier.clear();
    }
  }

  void _clearCanvasAndResults() {
    setState(() {
      _detectedLetter = null;
      _confidence = null;
    });
    _notifier.clear();
  }

  @override
  void dispose() {
    _notifier.dispose();
    _confettiController.dispose();
    _failureConfettiController.dispose();
    _tts.stop();
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
          'Write to Learn Word',
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
            GestureDetector(
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity! > 0) {
                  _previousWord();
                } else if (details.primaryVelocity! < 0) {
                  _nextWord();
                }
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 15),
                    Text(
                      'Please write a letter to form the word.',
                      style: TextStyle(
                        fontFamily: 'BalsamiqSans',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 10),
                    // Level Selector
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFFEE82), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      child: DropdownButton<String>(
                        value: _selectedLevel,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: _levels.map((level) {
                          return DropdownMenuItem(
                            value: level,
                            child: Text(
                              level,
                              style: TextStyle(
                                fontFamily: 'BalsamiqSans',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedLevel = value;
                            _fetchWordsForLevel(value!);
                          });
                        },
                        icon: const Icon(Icons.filter_list, color: Colors.black),
                      ),
                    ),
                    SizedBox(height: 30),
                    // Target Word with Navigation Buttons
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFFEE82), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(14.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_back_ios, color: _currentWordIndex > 0 ? Colors.black : Colors.grey),
                            onPressed: _currentWordIndex > 0 ? _previousWord : null,
                          ),
                          Expanded(
                            child: Center(
                              child: _isLoadingWords
                                  ? const CircularProgressIndicator(color: Colors.black)
                                  : Text(
                                _targetWord,
                                style: TextStyle(
                                  fontFamily: 'BalsamiqSans',
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.arrow_forward_ios, color: _currentWordIndex < _wordsForLevel.length - 1 ? Colors.black : Colors.grey),
                            onPressed: _currentWordIndex < _wordsForLevel.length - 1 ? _nextWord : null,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 30),
                    // Captured Letters
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFFEE82), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(14.0),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: List.generate(_targetWord.length, (index) {
                          bool isCurrent = index == _capturedLetters.length;
                          bool isFilled = index < _capturedLetters.length;
                          return Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFFFEE82), width: 2),
                              borderRadius: BorderRadius.circular(10),
                              color: isCurrent ? const Color(0xFFFFEE82).withOpacity(0.3) : Colors.white,
                            ),
                            child: Center(
                              child: Text(
                                isFilled ? _capturedLetters[index] : '-',
                                style: TextStyle(
                                  fontFamily: 'BalsamiqSans',
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: isFilled ? Colors.black : Colors.grey[600],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    SizedBox(height: 30),
                    // Canvas with buttons
                    Stack(
                      children: [
                        Container(
                          height: canvasSize,
                          width: canvasSize,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFFFEE82), width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: RepaintBoundary(
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
                                  if (_isProcessing)
                                    AnimatedLoadingIndicator(progressValue: _progressValue),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          left: 10,
                          child: ElevatedButton(
                            onPressed: _clearCanvasAndResults,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[400],
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.cleaning_services, color: Colors.white, size: 30),
                                SizedBox(width: 6),
                                Text(
                                  'Erase',
                                  style: TextStyle(
                                    fontFamily: 'BalsamiqSans',
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: ElevatedButton(
                            onPressed: _captureAndSaveToGallery,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[400],
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.save_alt, color: Colors.white, size: 30),
                                SizedBox(width: 4),
                                Text(
                                  'Save',
                                  style: TextStyle(
                                    fontFamily: 'BalsamiqSans',
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
                    SizedBox(height: 30),
                    // Action Buttons
                    GestureDetector(
                      onTap: _captureAndProcessCanvas,
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
                            const Icon(Icons.check_circle_outline, size: 28, color: Colors.black),
                            const SizedBox(width: 10),
                            Text(
                              'Check Drawing',
                              style: TextStyle(
                                fontFamily: 'BalsamiqSans',
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
                      onTap: _capturedLetters.isEmpty ? null : _backspace,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: _capturedLetters.isEmpty ? Colors.grey : const Color(0xFFFFEE82),
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
                            const Icon(Icons.backspace, size: 28, color: Colors.black),
                            const SizedBox(width: 10),
                            Text(
                              'Back',
                              style: TextStyle(
                                fontFamily: 'BalsamiqSans',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            // Confetti for Success
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
            // Confetti for Failure
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
            // Success Overlay
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
                        border: Border.all(color: const Color(0xFFFFEE82), width: 2),
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
                            '🎉 Woohoo! You made the word "$_targetWord"! You\'re awesome!',
                            style: TextStyle(
                              fontFamily: 'BalsamiqSans',
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
            // Failure Overlay
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
                        border: Border.all(color: const Color(0xFFFFEE82), width: 2),
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
                            '😕 Oopsies! Let\'s try spelling "$_targetWord" again!',
                            style: TextStyle(
                              fontFamily: 'BalsamiqSans',
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