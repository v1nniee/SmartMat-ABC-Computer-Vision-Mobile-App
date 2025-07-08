import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

class AdminViewVideos extends StatefulWidget {
  const AdminViewVideos({Key? key}) : super(key: key);

  @override
  _AdminViewVideosState createState() => _AdminViewVideosState();
}

class _AdminViewVideosState extends State<AdminViewVideos> {
  List<Map<String, String>> _videoFiles = []; // Store name and URL
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFFFFCA28),
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    _fetchVideos();
  }

  // Fetch all videos and their download URLs from Firebase Storage
  Future<void> _fetchVideos() async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child('AlphabetsVideos');
      final listResult = await storageRef.listAll();

      List<Map<String, String>> videoData = [];
      for (var item in listResult.items) {
        final url = await item.getDownloadURL(); // Get the downloadable URL
        videoData.add({'name': item.name, 'url': url});
      }

      setState(() {
        _videoFiles = videoData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showDialog('Oops!', 'Error fetching videos: $e');
    }
  }

  // Show dialog for errors
  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFFCE8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          title,
          style: GoogleFonts.balsamiqSans(
            color: Colors.redAccent,
            fontSize: 24,
            fontWeight: FontWeight.bold,
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
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: GoogleFonts.balsamiqSans(
                color: const Color(0xFFFFCA28),
                fontSize: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Show video player dialog
  void _showVideoPlayer(String url, String name) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFFFFFCE8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: VideoPlayerWidget(videoUrl: url, videoName: name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFCE8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFEE82),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'View Videos',
          style: GoogleFonts.balsamiqSans(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: _isLoading
              ? const Center(
            child: CircularProgressIndicator(color: Color(0xFFFFCA28)),
          )
              : _videoFiles.isEmpty
              ? Center(
            child: Text(
              'No videos found',
              style: GoogleFonts.balsamiqSans(
                fontSize: 18,
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
              : ListView.builder(
            itemCount: _videoFiles.length,
            itemBuilder: (context, index) {
              final videoName = _videoFiles[index]['name']!;
              final videoUrl = _videoFiles[index]['url']!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: GestureDetector(
                  onTap: () => _showVideoPlayer(videoUrl, videoName),
                  child: Container(
                    padding: const EdgeInsets.all(15.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: const Color(0xFFFFCA28), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.video_library,
                          color: Color(0xFFFFCA28),
                          size: 30,
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Text(
                            videoName,
                            style: GoogleFonts.balsamiqSans(
                              fontSize: 18,
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.play_arrow,
                          color: Color(0xFFFFCA28),
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// Widget to display the video player
class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final String videoName;

  const VideoPlayerWidget({required this.videoUrl, required this.videoName, Key? key}) : super(key: key);

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        setState(() {
          _isInitialized = true;
        });
      }).catchError((e) {
        print('Error initializing video: $e');
      });

    // Add listener to pause the video when it ends
    _controller.addListener(() {
      if (_isInitialized &&
          !_controller.value.isPlaying &&
          _controller.value.position >= _controller.value.duration) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Handle play/pause with proper async behavior
  Future<void> _togglePlayPause() async {
    if (_controller.value.isPlaying) {
      await _controller.pause();
    } else {
      if (_controller.value.position >= _controller.value.duration) {
        await _controller.seekTo(Duration.zero); // Reset to start
      }
      await _controller.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCE8),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.videoName,
            style: GoogleFonts.balsamiqSans(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          _isInitialized
              ? AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFFFCA28), width: 2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: VideoPlayer(_controller),
              ),
            ),
          )
              : const CircularProgressIndicator(color: Color(0xFFFFCA28)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _togglePlayPause,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFEE82),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Icon(
                  _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFEE82),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}