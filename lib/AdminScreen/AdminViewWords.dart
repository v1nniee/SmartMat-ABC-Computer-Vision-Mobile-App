import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminViewWords extends StatefulWidget {
  const AdminViewWords({Key? key}) : super(key: key);

  @override
  _AdminViewWordsState createState() => _AdminViewWordsState();
}

class _AdminViewWordsState extends State<AdminViewWords> {
  bool _isLoading = true;
  String? _selectedFilter = 'All'; // Default filter is "All"

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFFFFCA28),
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    // Simulate loading for initial fetch
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _isLoading = false;
      });
    });
  }

  // Show dialog for errors, success, or confirmation
  void _showDialog(String title, String message, {VoidCallback? onConfirm}) {
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
          if (onConfirm != null) // Add "No" button for confirmation dialogs
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'No',
                style: GoogleFonts.balsamiqSans(
                  color: const Color(0xFFFFCA28),
                  fontSize: 20,
                ),
              ),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (onConfirm != null) onConfirm(); // Execute deletion if confirmed
            },
            child: Text(
              onConfirm != null ? 'Yes' : 'OK',
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

  // Delete word from Firestore with confirmation
  Future<void> _deleteWord(String level, String docId) async {
    _showDialog(
      'Confirm Deletion',
      'Are you sure you want to delete this word?',
      onConfirm: () async {
        try {
          await FirebaseFirestore.instance
              .collection('Word Formation')
              .doc(level)
              .collection(level)
              .doc(docId)
              .delete();

          _showDialog('Success', 'Word deleted successfully!');
        } catch (e) {
          _showDialog('Oops!', 'Error deleting word: $e');
        }
      },
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
          'View Words',
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
          child: Column(
            children: [
              // Filter Bar
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
                child: DropdownButton<String>(
                  value: _selectedFilter,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: [
                    DropdownMenuItem(
                      value: 'All',
                      child: Text(
                        'All Levels',
                        style: GoogleFonts.balsamiqSans(
                          fontSize: 18,
                          color: const Color(0xFFFFCA28),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ...List.generate(5, (index) {
                      return DropdownMenuItem(
                        value: 'Level ${index + 1}',
                        child: Text(
                          'Level ${index + 1}',
                          style: GoogleFonts.balsamiqSans(
                            fontSize: 18,
                            color: const Color(0xFFFFCA28),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedFilter = value;
                    });
                  },
                  style: GoogleFonts.balsamiqSans(
                    fontSize: 18,
                    color: const Color(0xFFFFCA28),
                    fontWeight: FontWeight.bold,
                  ),
                  icon: const Icon(Icons.filter_list, color: Color(0xFFFFCA28)),
                ),
              ),
              const SizedBox(height: 30),
              // Words List
              Expanded(
                child: _isLoading
                    ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFFCA28)),
                )
                    : ListView(
                  children: _selectedFilter == 'All'
                      ? List.generate(5, (index) {
                    final level = 'Level ${index + 1}';
                    return _buildLevelSection(level);
                  })
                      : [_buildLevelSection(_selectedFilter!)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build a section for each level
  Widget _buildLevelSection(String level) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Word Formation')
          .doc(level)
          .collection(level)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        if (snapshot.hasError) {
          return Text(
            'Error loading $level',
            style: GoogleFonts.balsamiqSans(
              fontSize: 18,
              color: Colors.redAccent,
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: Text(
              'No words found in $level',
              style: GoogleFonts.balsamiqSans(
                fontSize: 18,
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }

        final words = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              level,
              style: GoogleFonts.balsamiqSans(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            ...words.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final word = data['word'] as String;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
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
                        Icons.text_fields,
                        color: Color(0xFFFFCA28),
                        size: 30,
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Text(
                          word,
                          style: GoogleFonts.balsamiqSans(
                            fontSize: 18,
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.redAccent,
                        ),
                        onPressed: () => _deleteWord(level, doc.id),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}