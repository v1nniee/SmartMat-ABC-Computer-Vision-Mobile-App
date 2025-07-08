import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class KidAccount extends StatefulWidget {
  const KidAccount({Key? key}) : super(key: key);

  @override
  _KidAccountState createState() => _KidAccountState();
}

class _KidAccountState extends State<KidAccount> {
  final User? user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFCE8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFEE82),
        elevation: 0,
        title: Text(
          'My Account',
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
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile Information Section
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('Kid')
                      .doc(user?.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.black),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Something went wrong!',
                          style: GoogleFonts.balsamiqSans(
                            fontSize: 18,
                            color: Colors.black,
                          ),
                        ),
                      );
                    }
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return Center(
                        child: Text(
                          'No data found!',
                          style: GoogleFonts.balsamiqSans(
                            fontSize: 18,
                            color: Colors.black,
                          ),
                        ),
                      );
                    }

                    String kidName = snapshot.data!.get('fullName') ?? 'Super Kid';
                    String email = user?.email ?? 'No email';

                    return Container(
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
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          _buildInfoTile(Icons.person, 'Name', kidName),
                          const Divider(color: Color(0xFFFFEE82)),
                          _buildInfoTile(Icons.email, 'Email', email),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 30),
                // Action Buttons
                _buildActionTile(
                  context,
                  Icons.edit,
                  'Edit Profile',
                      () {
                    Navigator.pushNamed(context, '/kidEditProfile');
                  },
                ),
                const SizedBox(height: 15),
                _buildActionTile(
                  context,
                  Icons.lock,
                  'Change Password',
                      () {
                    Navigator.pushNamed(context, '/kidChangePassword');
                  },
                ),
                const SizedBox(height: 15),
                _buildActionTile(
                  context,
                  Icons.supervised_user_circle,
                  'My Caregiver',
                      () {
                    Navigator.pushNamed(context, '/kidApproveRejectCaregiver');
                  },
                ),
                const SizedBox(height: 30),
                // Logout Button
                GestureDetector(
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                          (route) => false,
                    );
                  },
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
                    child: Center(
                      child: Text(
                        'Logout',
                        style: GoogleFonts.balsamiqSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.black,
            size: 28,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.balsamiqSans(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: GoogleFonts.balsamiqSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
      BuildContext context,
      IconData icon,
      String title,
      VoidCallback onTap,
      ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
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
          children: [
            Icon(
              icon,
              color: Colors.black,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.balsamiqSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}