import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class KidsHome extends StatefulWidget {
  const KidsHome({Key? key}) : super(key: key);

  @override
  _KidsHomeState createState() => _KidsHomeState();
}

class _KidsHomeState extends State<KidsHome> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFFFFE173),
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:  Color(0xFFFFFCE8),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: MediaQuery.of(context).size.height * 0.25,
            pinned: false,
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Image.asset(
                'assets/images/header.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFFFFCE8),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                padding: const EdgeInsets.only(top: 20, bottom: 40),
                child: Column(
                  children: [
                    // Welcome Text
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('Kid')
                          .doc(FirebaseAuth.instance.currentUser?.uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return CircularProgressIndicator(color: Colors.black);
                        }
                        if (!snapshot.hasData || !snapshot.data!.exists) {
                          return Text(
                            'Oops, no data!',
                            style: GoogleFonts.balsamiqSans(fontSize: 16, color: Colors.black),
                          );
                        }
                        String kidName = snapshot.data?.get('fullName') ?? 'Evan Ling';
                        return Text(
                          'Hello $kidName!',
                          style: GoogleFonts.balsamiqSans(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.center,
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // Scan Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        children: [
                          _buildSectionTitle('Scan & Learn'),
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.9,
                            children: [
                              _buildFunCard(
                                context,
                                Icons.camera_alt,
                                'Scan to Learn Alphabets',
                                    () => Navigator.pushNamed(context, '/kidScantoLearnAlphabets'),
                              ),
                              _buildFunCard(
                                context,
                                Icons.camera,
                                'Scan to Form a Word',
                                    () => Navigator.pushNamed(context, '/kidScantoLearnWord'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),

                          // Write Section
                          _buildSectionTitle('Write & Learn'),
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.9,
                            children: [
                              _buildFunCard(
                                context,
                                Icons.brush,
                                'Write to Learn Alphabets',
                                    () => Navigator.pushNamed(context, '/kidWritetoLearnAlphabets'),
                              ),
                              _buildFunCard(
                                context,
                                Icons.edit,
                                'Write to Form a Word',
                                    () => Navigator.pushNamed(context, '/kidWritetoLearnWord'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFunCard(
      BuildContext context,
      IconData icon,
      String title,
      VoidCallback onTap,
      ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFEE82),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: Colors.black,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.balsamiqSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.balsamiqSans(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
      textAlign: TextAlign.center,
    );
  }
}
