import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminAddWords extends StatefulWidget {
  const AdminAddWords({Key? key}) : super(key: key);

  @override
  _AdminAddWordsState createState() => _AdminAddWordsState();
}

class _AdminAddWordsState extends State<AdminAddWords> {
  final _formKey = GlobalKey<FormState>();
  final User? user = FirebaseAuth.instance.currentUser;
  final TextEditingController _wordController = TextEditingController();
  String? _selectedLevel;
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

  // Save word to Firestore
  Future<void> _saveWord() async {
    if (!_formKey.currentState!.validate() || _selectedLevel == null) {
      _showDialog('Oops!', 'Please enter a word and select a level');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final firestoreRef = FirebaseFirestore.instance
          .collection('Word Formation')
          .doc(_selectedLevel)
          .collection(_selectedLevel!);

      String wordToSave = _wordController.text.trim().toUpperCase();
      await firestoreRef.add({
        'word': wordToSave,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user?.uid,
      });

      _showDialog('Success', 'Word "$wordToSave" added to $_selectedLevel successfully!');
      setState(() {
        _wordController.clear();
        _selectedLevel = null;
      });
    } catch (e) {
      _showDialog('Oops!', 'Error saving word: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _wordController.dispose();
    super.dispose();
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
          'Add Word',
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
                // Word Input Section
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
                  child: TextFormField(
                    controller: _wordController,
                    decoration: InputDecoration(
                      labelText: "Enter Word for Kid's Learning",
                      border: InputBorder.none,
                      prefixIcon: const Icon(Icons.text_fields, color: Color(0xFFFFCA28)),
                      labelStyle: GoogleFonts.balsamiqSans(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                    style: GoogleFonts.balsamiqSans(
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z]')),
                    ],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a word';
                      }
                      if (!RegExp(r'^[A-Za-z]+$').hasMatch(value)) {
                        return 'Word must contain only letters';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 30),
                // Level Dropdown
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
                    value: _selectedLevel,
                    decoration: InputDecoration(
                      labelText: 'Select Level',
                      border: InputBorder.none,
                      prefixIcon: const Icon(Icons.star, color: Color(0xFFFFCA28)),
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
                    icon: const Icon(Icons.filter_list, color: Color(0xFFFFCA28)),
                    isExpanded: true,
                    items: List.generate(5, (index) {
                      return DropdownMenuItem(
                        value: 'Level ${index + 1}',
                        child: Text(
                          'Level ${index + 1}',
                          style: GoogleFonts.balsamiqSans(
                            fontSize: 18,
                            color: Colors.black87,
                          ),
                        ),
                      );
                    }),
                    onChanged: (value) {
                      setState(() {
                        _selectedLevel = value;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Please select a level';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 30),
                // Save Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveWord,
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
                      const Icon(Icons.save, color: Colors.black),
                      const SizedBox(width: 10),
                      Text(
                        'Add Word',
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