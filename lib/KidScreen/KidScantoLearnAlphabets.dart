import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';
import '../Screen/AnimatedLoadingIndicator.dart';
import '../Service/ModelManager.dart';

class KidScantoLearnAlphabets extends StatefulWidget {
  const KidScantoLearnAlphabets({super.key});

  @override
  _KidScantoLearnAlphabetsState createState() => _KidScantoLearnAlphabetsState();
}

class _KidScantoLearnAlphabetsState extends State<KidScantoLearnAlphabets>
    with SingleTickerProviderStateMixin {
  File? _image;
  String? _detectedClass;
  double? _confidence;
  bool _isProcessing = false;
  double _progressValue = 0.0;
  final ModelManager _modelManager = ModelManager();
  final ImagePicker _picker = ImagePicker();
  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;
  bool _hasPlayed = false;
  late AnimationController _animationController;
  late Animation<double> _iconAnimation;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.network('');
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _iconAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.repeat(reverse: true);
  }

  Future<void> _initializeVideoController(String videoFileName) async {
    try {
      if (_isVideoInitialized) {
        await _videoController.pause();
        await _videoController.dispose();
      }
      setState(() {
        _isVideoInitialized = false;
      });
      final storageRef = FirebaseStorage.instance.ref().child('AlphabetsVideos/$videoFileName');
      final videoUrl = await storageRef.getDownloadURL();
      _videoController = VideoPlayerController.network(videoUrl);
      await _videoController.initialize();
      _videoController.setLooping(false);
      _videoController.setVolume(1.0);
      _videoController.addListener(() {
        if (_videoController.value.position == _videoController.value.duration && _hasPlayed) {
          setState(() {});
        }
      });
      setState(() {
        _isVideoInitialized = true;
      });
    } catch (e) {
      print('Error initializing video controller: $e');
      setState(() {
        _isVideoInitialized = false;
      });
    }
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
        _hasPlayed = false;
        _isVideoInitialized = false;
      });

      if (_isVideoInitialized) {
        await _videoController.pause();
        await _videoController.dispose();
      }

      await _processImage();
      setState(() {
        _isProcessing = false;
      });
      _playVideoIfDetected();
    }
  }

  Future<void> _updateAlphabetProgress(String letter, double confidence) async {
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
          .collection('ScanToLearnAlphabetProgress')
          .doc('progress');

      DocumentSnapshot snapshot = await progressRef.get();

      if (snapshot.exists) {
        Map<String, dynamic> progressData = snapshot.data() as Map<String, dynamic>;
        int totalDetections = (progressData[letter]?['totalDetections'] ?? 0) as int;

        await progressRef.set({
          letter: {
            'totalDetections': totalDetections + 1,
            'lastDetected': FieldValue.serverTimestamp(),
          }
        }, SetOptions(merge: true));
      } else {
        await progressRef.set({
          letter: {
            'totalDetections': 1,
            'lastDetected': FieldValue.serverTimestamp(),
          }
        }, SetOptions(merge: true));
      }

      print('Updated progress for letter: $letter');
    } catch (e) {
      print('Error updating alphabet progress: $e');
    }
  }


  Future<void> _processImage() async {
    if (_image == null) return;
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
      _showErrorDialog('Failed to decode image');
      return;
    }
    final padded = img.copyResize(image, width: 640, height: 640);
    print('Image size: ${padded.width}x${padded.height}');
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
    String? bestClass;
    double minDistanceToCenter = double.infinity;
    final imageCenterX = 640 / 2;
    final imageCenterY = 640 / 2;
    for (var det in detections) {
      final confidence = det[4];
      if (confidence > 0.4) {
        final classId = det[5].toInt();
        if (classId < _modelManager.labels.length) {
          final xMin = det[0] * 640;
          final yMin = det[1] * 640;
          final xMax = det[2] * 640;
          final yMax = det[3] * 640;
          print('Raw coords: [${det[0]}, ${det[1]}, ${det[2]}, ${det[3]}], '
              'Scaled: [$xMin, $yMin, $xMax, $yMax]');
          final boxCenterX = (xMin + xMax) / 2;
          final boxCenterY = (yMin + yMax) / 2;
          final distanceToCenter = sqrt(
            pow(boxCenterX - imageCenterX, 2) + pow(boxCenterY - imageCenterY, 2),
          );
          print('Letter: ${_modelManager.labels[classId]}, '
              'Center: ($boxCenterX, $boxCenterY), '
              'Distance: $distanceToCenter, Confidence: $confidence');
          if (distanceToCenter < minDistanceToCenter) {
            minDistanceToCenter = distanceToCenter;
            maxConfidence = confidence;
            bestClass = _modelManager.labels[classId];
          }
        }
      }
    }
    if (bestClass != null) {
      setState(() {
        _detectedClass = bestClass;
        _confidence = maxConfidence;
      });
      print('Selected letter: $bestClass, Distance: $minDistanceToCenter, Confidence: $maxConfidence');
      await _updateAlphabetProgress(bestClass, maxConfidence * 100);
      await _initializeVideoController('$bestClass.mp4');
    } else {
      setState(() {
        _isProcessing = false;
      });
      _showErrorDialog('Not Detected');
      return;
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

  void _playVideoIfDetected() {
    if (_detectedClass != null && _isVideoInitialized && !_hasPlayed) {
      _videoController.setVolume(1.0);
      _videoController.seekTo(Duration.zero);
      _videoController.play();
      _hasPlayed = true;
      print('Playing video for letter $_detectedClass');
    } else {
      _stopVideo();
      print('Video stopped or not triggered');
    }
  }

  void _replayVideo() {
    if (_isVideoInitialized && _detectedClass != null) {
      _videoController.seekTo(Duration.zero);
      _videoController.play();
      setState(() {});
      print('Replaying video for letter $_detectedClass');
    }
  }

  void _stopVideo() {
    if (_isVideoInitialized) {
      _videoController.pause();
      _videoController.seekTo(Duration.zero);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    if (_isVideoInitialized) _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // White background for the top area
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFEE82),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Scan to Learn Alphabets',
          style: GoogleFonts.balsamiqSans(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFFFFADD), // Background color below buttons
              ),
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFFADD), // Ensure content area matches
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                        child: _image == null
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
                            : Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipRRect(
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
                      const SizedBox(height: 25),
                      if (_detectedClass != null)
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
                          child: _isVideoInitialized
                              ? Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: AspectRatio(
                                  aspectRatio: _videoController.value.aspectRatio,
                                  child: VideoPlayer(_videoController),
                                ),
                              ),
                              if (_hasPlayed && !_videoController.value.isPlaying)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12.0),
                                  child: GestureDetector(
                                    onTap: _replayVideo,
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.1),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 10),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.replay, color: Colors.black),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Play Again',
                                            style: GoogleFonts.balsamiqSans(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          )
                              : Column(
                            children: [
                              const CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 4,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Finding your letter...',
                                style: GoogleFonts.balsamiqSans(
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
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