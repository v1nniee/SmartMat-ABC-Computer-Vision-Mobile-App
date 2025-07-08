import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';

class AdminAddVideos extends StatefulWidget {
  const AdminAddVideos({Key? key}) : super(key: key);

  @override
  _AdminAddVideosState createState() => _AdminAddVideosState();
}

class _AdminAddVideosState extends State<AdminAddVideos> {
  final _formKey = GlobalKey<FormState>();
  final User? user = FirebaseAuth.instance.currentUser;

  // Selected letter for the video
  String? _selectedLetter;

  // File to upload
  File? _videoFile;

  // Loading state
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFFFFCA28),
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  // Pick video file from device
  Future<void> _pickVideo() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _videoFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      _showDialog('Error', 'Error picking video: $e');
    }
  }

  // Show dialog for both errors and success
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
            color: title == 'Success' ? Colors.green : Colors.redAccent,
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

  // Upload video to Firebase Storage
  Future<void> _uploadVideo() async {
    if (!_formKey.currentState!.validate() || _videoFile == null || _selectedLetter == null) {
      _showDialog('Error', 'Please select a video and a letter');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Define the file path in Firebase Storage as AlphabetsVideos/A.mp4 to Z.mp4
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('AlphabetsVideos')
          .child('$_selectedLetter.mp4');

      // Upload the file
      await storageRef.putFile(_videoFile!);

      // Show success dialog
      _showDialog('Success', 'Video for $_selectedLetter uploaded successfully!');

      // Clear selections after successful upload
      setState(() {
        _videoFile = null;
        _selectedLetter = null;
      });
    } catch (e) {
      _showDialog('Error', 'Error uploading video: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
          'Add Video',
          style: GoogleFonts.balsamiqSans(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                // Video Upload Section
                GestureDetector(
                  onTap: _pickVideo,
                  child: Container(
                    height: 150,
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
                    child: _videoFile == null
                        ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.video_call,
                          size: 50,
                          color: Color(0xFFFFCA28),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Tap to select a video',
                          style: GoogleFonts.balsamiqSans(
                            fontSize: 16,
                            color: const Color(0xFFFFCA28),
                          ),
                        ),
                      ],
                    )
                        : Center(
                      child: Text(
                        'Selected: ${_videoFile!.path.split('/').last}',
                        style: GoogleFonts.balsamiqSans(
                          fontSize: 16,
                          color: const Color(0xFFFFCA28),
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                // Letter Dropdown
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFFFCA28), width: 2),
                    borderRadius: BorderRadius.circular(15),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  child: DropdownButtonFormField<String>(
                    value: _selectedLetter,
                    decoration: InputDecoration(
                      labelText: 'Select Letter',
                      border: InputBorder.none,
                      prefixIcon: const Icon(Icons.abc, color: Color(0xFFFFCA28)),
                      labelStyle: GoogleFonts.balsamiqSans(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                    style: GoogleFonts.balsamiqSans(
                      fontSize: 18,
                      color: const Color(0xFFFFCA28),
                      fontWeight: FontWeight.bold,
                    ),
                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFFFCA28)),
                    isExpanded: true,
                    items: List.generate(26, (index) {
                      return DropdownMenuItem(
                        value: String.fromCharCode(65 + index), // A to Z
                        child: Text(
                          String.fromCharCode(65 + index),
                          style: GoogleFonts.balsamiqSans(
                            fontSize: 18,
                            color: Colors.black87,
                          ),
                        ),
                      );
                    }),
                    onChanged: (value) {
                      setState(() {
                        _selectedLetter = value;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Please select a letter';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 30),
                // Upload Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _uploadVideo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFEE82),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                    shadowColor: Colors.black.withOpacity(0.2),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.upload, color: Colors.black),
                      const SizedBox(width: 10),
                      Text(
                        'Upload Video',
                        style: GoogleFonts.balsamiqSans(
                          fontSize: 18,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
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
    );
  }
}