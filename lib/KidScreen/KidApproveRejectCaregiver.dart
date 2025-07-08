import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

class KidApproveRejectCaregiver extends StatefulWidget {
  const KidApproveRejectCaregiver({super.key});

  @override
  _KidApproveRejectCaregiverState createState() => _KidApproveRejectCaregiverState();
}

class _KidApproveRejectCaregiverState extends State<KidApproveRejectCaregiver> {
  User? kid = FirebaseAuth.instance.currentUser;

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

  Future<void> _approveCaregiver(String caregiverId, String caregiverEmail, String relationship) async {
    try {
      await FirebaseFirestore.instance
          .collection('Kid')
          .doc(kid!.uid)
          .collection('Caregiver')
          .doc(caregiverId)
          .set({
        'caregiverId': caregiverId,
        'caregiverEmail': caregiverEmail,
        'relationship': relationship,
        'status': 'Approved',
      });

      await FirebaseFirestore.instance
          .collection('Caregiver')
          .doc(caregiverId)
          .collection('KidProfileSelected')
          .doc(kid!.uid)
          .update({'status': 'Approved'});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Caregiver approved successfully.',
            style: GoogleFonts.balsamiqSans(color: Colors.white, fontSize: 16),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showErrorDialog('Error approving caregiver: $e');
    }
  }

  Future<void> _rejectCaregiver(String caregiverId) async {
    try {
      await FirebaseFirestore.instance
          .collection('Kid')
          .doc(kid!.uid)
          .collection('Caregiver')
          .doc(caregiverId)
          .delete();
      await FirebaseFirestore.instance
          .collection('Caregiver')
          .doc(caregiverId)
          .collection('KidProfileSelected')
          .doc(kid!.uid)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Caregiver request rejected.',
            style: GoogleFonts.balsamiqSans(color: Colors.white, fontSize: 16),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      _showErrorDialog('Error rejecting caregiver: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Error',
            style: GoogleFonts.balsamiqSans(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          content: Text(
            message,
            style: GoogleFonts.balsamiqSans(fontSize: 16, color: Colors.black),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: GoogleFonts.balsamiqSans(
                  color: Colors.black,
                  fontSize: 16,
                ),
              ),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          elevation: 5,
        );
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
          "My Caregivers",
          style: GoogleFonts.balsamiqSans(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFFFFCE8),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('Kid')
                    .doc(kid!.uid)
                    .collection('Caregiver')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFFFFEE82)),
                    );
                  }

                  var caregivers = snapshot.data!.docs;

                  List<QueryDocumentSnapshot> pendingCaregivers = [];
                  List<QueryDocumentSnapshot> approvedCaregivers = [];

                  for (var caregiver in caregivers) {
                    var data = caregiver.data() as Map<String, dynamic>;
                    if (data['status'] == 'Approved') {
                      approvedCaregivers.add(caregiver);
                    } else {
                      pendingCaregivers.add(caregiver);
                    }
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Approved Caregivers Section
                      if (approvedCaregivers.isNotEmpty)
                        _buildSection(
                          title: 'Approved Caregivers',
                          children: approvedCaregivers.map((doc) {
                            var data = doc.data() as Map<String, dynamic>;
                            return _buildCaregiverCard(
                              email: data['caregiverEmail'],
                              relationship: data['relationship'],
                              isPending: false,
                            );
                          }).toList(),
                        ),

                      if (approvedCaregivers.isNotEmpty && pendingCaregivers.isNotEmpty)
                        const SizedBox(height: 20),

                      // Pending Caregivers Section
                      if (pendingCaregivers.isNotEmpty)
                        _buildSection(
                          title: 'Pending Caregiver Requests',
                          children: pendingCaregivers.map((doc) {
                            var data = doc.data() as Map<String, dynamic>;
                            String caregiverId = data['caregiverId'];
                            String caregiverEmail = data['caregiverEmail'];
                            String relationship = data['relationship'];
                            return _buildCaregiverCard(
                              email: caregiverEmail,
                              relationship: relationship,
                              isPending: true,
                              onApprove: () => _approveCaregiver(caregiverId, caregiverEmail, relationship),
                              onReject: () => _rejectCaregiver(caregiverId),
                            );
                          }).toList(),
                        ),

                      // No Pending Requests Message
                      if (pendingCaregivers.isEmpty && approvedCaregivers.isEmpty)
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFFFEE82), width: 2),
                            borderRadius: BorderRadius.circular(15),
                            color: Colors.white,
                          ),
                          padding: const EdgeInsets.all(20),
                          margin: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              'No caregiver requests yet! 😊',
                              style: GoogleFonts.balsamiqSans(
                                fontSize: 18,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFFFEE82), width: 2),
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
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.balsamiqSans(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildCaregiverCard({
    required String email,
    required String relationship,
    required bool isPending,
    VoidCallback? onApprove,
    VoidCallback? onReject,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFFFEE82), width: 2),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.person,
                color: Color(0xFFFFEE82),
                size: 30,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  email,
                  style: GoogleFonts.balsamiqSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Relationship: $relationship',
            style: GoogleFonts.balsamiqSans(
              fontSize: 16,
              color: Colors.black54,
            ),
          ),
          if (isPending) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: onApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    elevation: 2,
                  ),
                  child: Text(
                    'Approve',
                    style: GoogleFonts.balsamiqSans(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: onReject,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    elevation: 2,
                  ),
                  child: Text(
                    'Reject',
                    style: GoogleFonts.balsamiqSans(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}