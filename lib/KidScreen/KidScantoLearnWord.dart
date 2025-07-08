import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:confetti/confetti.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import '../Screen/AnimatedLoadingIndicator.dart';
import '../Service/ModelManager.dart';
import 'dart:math';

class KidScantoLearnWord extends StatefulWidget {
  const KidScantoLearnWord({super.key});

  @override
  _KidScantoLearnWordState createState() => _KidScantoLearnWordState();
}

class _KidScantoLearnWordState extends State<KidScantoLearnWord> with SingleTickerProviderStateMixin {
  File? _image;
  String? _detectedLetter;
  double? _confidence;
  bool _isProcessing = false;
  double _progressValue = 0.0;
  final ModelManager _modelManager = ModelManager();
  final ImagePicker _picker = ImagePicker();
  final FlutterTts _tts = FlutterTts();

  List<String> _capturedLetters = [];
  List<double> _capturedConfidences = [];
  String _targetWord = "";
  bool _wordCompleted = false;

  String? _selectedLevel = 'Level 1';
  final List<String> _levels = ['Level 1', 'Level 2', 'Level 3', 'Level 4', 'Level 5'];
  List<String> _wordsForLevel = [];
  int _currentWordIndex = 0;
  bool _isLoadingWords = true;

  final ConfettiController _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  final ConfettiController _failureConfettiController = ConfettiController(duration: const Duration(seconds: 3));

  bool _showSuccessOverlay = false;
  bool _showFailureOverlay = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _iconAnimation;

  @override
  void initState() {
    super.initState();
    _fetchWordsForLevel(_selectedLevel!);
    _initializeTts();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _iconAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.repeat(reverse: true);
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
      _image = null;
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

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _detectedLetter = null;
        _confidence = null;
        _isProcessing = true;
        _progressValue = 0.0;
      });
      await _processImage();
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _processImage() async {
    if (_image == null || _capturedLetters.length >= _targetWord.length || _wordCompleted) return;

    if (!_modelManager.isAlphabetMapModelLoaded || _modelManager.alphabetMapModel == null) {
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
      _showErrorDialog('Failed to process image');
      return;
    }

    final padded = img.copyResize(image, width: 640, height: 640);
    print('Image size: ${padded.width}x${padded.height}'); // Debug image size

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
    double minDistanceToCenter = double.infinity;
    double maxConfidence = 0.0;
    int bestClassId = -1;
    final imageCenterX = 640 / 2; // Image center x-coordinate (320)
    final imageCenterY = 640 / 2; // Image center y-coordinate (320)

    for (var det in detections) {
      final confidence = det[4];
      if (confidence > 0.4) {
        final classId = det[5].toInt();
        if (classId >= 0 && classId < _modelManager.labels.length) {
          // Assume coordinates are normalized (0 to 1); scale to 640x640
          final xMin = det[0] * 640;
          final yMin = det[1] * 640;
          final xMax = det[2] * 640;
          final yMax = det[3] * 640;

          // Log raw and scaled coordinates
          print('Raw coords: [${det[0]}, ${det[1]}, ${det[2]}, ${det[3]}], '
              'Scaled: [$xMin, $yMin, $xMax, $yMax]');

          // Calculate the center of the bounding box
          final boxCenterX = (xMin + xMax) / 2;
          final boxCenterY = (yMin + yMax) / 2;

          // Calculate distance from box center to image center
          final distanceToCenter = sqrt(
            pow(boxCenterX - imageCenterX, 2) + pow(boxCenterY - imageCenterY, 2),
          );

          // Log detection details
          print('Letter: ${_modelManager.labels[classId]}, '
              'Center: ($boxCenterX, $boxCenterY), '
              'Distance: $distanceToCenter, Confidence: $confidence');

          // Prioritize the detection closest to the center
          if (distanceToCenter < minDistanceToCenter) {
            minDistanceToCenter = distanceToCenter;
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

      print('Selected letter: $_detectedLetter, Distance: $minDistanceToCenter, Confidence: $maxConfidence');

      await _speakDetectedLetter(_detectedLetter!, onComplete: () {
        setState(() {
          _isProcessing = false;
        });

        if (_capturedLetters.length == _targetWord.length) {
          _finishWordFormation();
        }
      });
    } else {
      setState(() {
        _isProcessing = false;
      });
      _showErrorDialog('Letter not detected');
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

  void _backspace() {
    if (_capturedLetters.isNotEmpty) {
      setState(() {
        _capturedLetters.removeLast();
        _capturedConfidences.removeLast();
        _detectedLetter = _capturedLetters.isNotEmpty ? _capturedLetters.last : null;
        _confidence = _capturedConfidences.isNotEmpty ? _capturedConfidences.last : null;
        _image = null;
        _wordCompleted = false;
      });
    }
  }

  void _finishWordFormation() {
    setState(() {
      _wordCompleted = true;
    });

    String formedWord = _capturedLetters.join();
    bool isSuccessful = formedWord == _targetWord;

    _updateWordFormationProgress(isSuccessful);

    if (isSuccessful) {
      setState(() {
        _showSuccessOverlay = true;
      });
      _animationController.forward();
      _confettiController.play();
      try {
        print('Speaking word: $_targetWord');
        _tts.speak('Woohoo! You made the word $_targetWord! You\'re awesome!');
        print('TTS word playback initiated successfully');
      } catch (e) {
        print('Error speaking word: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to speak word: $e')),
        );
      }
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
      _failureConfettiController.play();
      try {
        print('Speaking: Try again');
        _tts.speak("Oopsies! Let's try spelling $_targetWord again!");
        print('TTS failure message playback initiated successfully');
      } catch (e) {
        print('Error speaking failure message: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to speak message: $e')),
        );
      }

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
      _image = null;
      _detectedLetter = null;
      _confidence = null;
      _wordCompleted = false;
      _showSuccessOverlay = false;
      _showFailureOverlay = false;
    });
  }

  Future<void> _updateWordFormationProgress(bool isSuccessful) async {
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
          .collection('ScanToFormWordProgress')
          .doc('progress');

      DocumentSnapshot snapshot = await progressRef.get();

      if (snapshot.exists) {
        Map<String, dynamic> progressData = snapshot.data() as Map<String, dynamic>;
        int totalAttempts = (progressData[_targetWord]?['attempts'] ?? 0) as int;
        int successfulAttempts = (progressData[_targetWord]?['successfulAttempts'] ?? 0) as int;

        int newSuccessfulAttempts = isSuccessful ? successfulAttempts + 1 : successfulAttempts;

        await progressRef.set({
          _targetWord: {
            'attempts': totalAttempts + 1,
            'successfulAttempts': newSuccessfulAttempts,
            'lastDetected': FieldValue.serverTimestamp(),
          }
        }, SetOptions(merge: true));
      } else {
        await progressRef.set({
          _targetWord: {
            'attempts': 1,
            'successfulAttempts': isSuccessful ? 1 : 0,
            'lastDetected': FieldValue.serverTimestamp(),
          }
        }, SetOptions(merge: true));
      }

      print('Updated Word Formation progress for: $_targetWord');
    } catch (e) {
      print('Error updating word formation progress: $e');
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _failureConfettiController.dispose();
    _tts.stop();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          'Scan to Form a Word',
          style: GoogleFonts.balsamiqSans(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                            style: GoogleFonts.balsamiqSans(
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
                  const SizedBox(height: 30),
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
                              style: GoogleFonts.balsamiqSans(
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
                  const SizedBox(height: 30),
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
                              style: GoogleFonts.balsamiqSans(
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
                  const SizedBox(height: 30),
                  // Image Preview
                  Container(
                    height: 300,
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
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _image == null
                            ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ScaleTransition(
                                scale: _iconAnimation,
                                child: const Icon(
                                  Icons.image_search,
                                  size: 60,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20), // 20 pixels padding on left and right
                                child: Text(
                                  'Take or pick a photo of a letter on the map here!',
                                  textAlign: TextAlign.center, // Center-align the text
                                  style: GoogleFonts.balsamiqSans(
                                    fontSize: 18,
                                    color: Colors.black,
                                  ),
                                ),
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
                            height: 300,
                          ),
                        ),
                        if (_isProcessing)
                          AnimatedLoadingIndicator(progressValue: _progressValue),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Action Buttons
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
                          const Icon(Icons.camera_alt, size: 28, color: Colors.black),
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
                  const SizedBox(height: 15),
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
                          const Icon(Icons.photo_library, size: 28, color: Colors.black),
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
                  const SizedBox(height: 15),
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
                  const SizedBox(height: 20),
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
              emissionFrequency: 0.01,
              numberOfParticles: 50,
              gravity: 0.2,
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
              emissionFrequency: 0.01,
              numberOfParticles: 30,
              gravity: 0.2,
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
                    width: MediaQuery.of(context).size.width * 0.8,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 12,
                          spreadRadius: 6,
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
          // Failure Overlay
          if (_showFailureOverlay)
            AnimatedOpacity(
              opacity: _showFailureOverlay ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Center(
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.8,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withOpacity(0.3),
                          blurRadius: 12,
                          spreadRadius: 6,
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
    );
  }
}