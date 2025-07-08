import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class CaregiverManageKids extends StatefulWidget {
  const CaregiverManageKids({Key? key}) : super(key: key);

  @override
  _CaregiverManageKidsState createState() => _CaregiverManageKidsState();
}

class _CaregiverManageKidsState extends State<CaregiverManageKids> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _kidEmailController = TextEditingController();
  String? _selectedRelationship;
  User? caregiver = FirebaseAuth.instance.currentUser;
  String? _selectedKidId;
  bool _isAddKidExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _iconAnimation;

  @override
  void initState() {
    super.initState();
    _loadSelectedKid();
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

  Future<void> _loadSelectedKid() async {
    try {
      QuerySnapshot selectedKidDocs = await FirebaseFirestore.instance
          .collection('Caregiver')
          .doc(caregiver!.uid)
          .collection('KidSelected')
          .get();

      if (selectedKidDocs.docs.isNotEmpty) {
        setState(() {
          _selectedKidId = selectedKidDocs.docs.first.id;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error loading selected kid: $e',
            style: GoogleFonts.balsamiqSans(fontSize: 16),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _selectKid(String kidId, String kidEmail) async {
    try {
      QuerySnapshot existingSelections = await FirebaseFirestore.instance
          .collection('Caregiver')
          .doc(caregiver!.uid)
          .collection('KidSelected')
          .get();

      for (var doc in existingSelections.docs) {
        await doc.reference.delete();
      }

      await FirebaseFirestore.instance
          .collection('Caregiver')
          .doc(caregiver!.uid)
          .collection('KidSelected')
          .doc(kidId)
          .set({
        'kidId': kidId,
        'kidEmail': kidEmail,
        'selectedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _selectedKidId = kidId;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Kid selected successfully!',
            style: GoogleFonts.balsamiqSans(fontSize: 16),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error selecting kid: $e',
            style: GoogleFonts.balsamiqSans(fontSize: 16),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _addKidProfile() async {
    if (!_formKey.currentState!.validate()) return;

    String kidEmail = _kidEmailController.text.trim();

    try {
      QuerySnapshot kidSnapshot = await FirebaseFirestore.instance
          .collection('Kid')
          .where('email', isEqualTo: kidEmail)
          .get();

      if (kidSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Kid not found. Please check the email.',
              style: GoogleFonts.balsamiqSans(fontSize: 16),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      String kidId = kidSnapshot.docs.first.id;

      DocumentSnapshot existingRequest = await FirebaseFirestore.instance
          .collection('Caregiver')
          .doc(caregiver!.uid)
          .collection('KidProfileSelected')
          .doc(kidId)
          .get();

      if (existingRequest.exists) {
        String status = (existingRequest.data() as Map<String, dynamic>)['status'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Request already exists. Current status: $status',
              style: GoogleFonts.balsamiqSans(fontSize: 16),
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      await FirebaseFirestore.instance
          .collection('Kid')
          .doc(kidId)
          .collection('Caregiver')
          .doc(caregiver!.uid)
          .set({
        'caregiverId': caregiver!.uid,
        'caregiverEmail': caregiver!.email,
        'relationship': _selectedRelationship,
        'status': 'Pending',
      });

      await FirebaseFirestore.instance
          .collection('Caregiver')
          .doc(caregiver!.uid)
          .collection('KidProfileSelected')
          .doc(kidId)
          .set({
        'kidId': kidId,
        'kidEmail': kidEmail,
        'relationship': _selectedRelationship,
        'status': 'Pending',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Request sent. Waiting for approval.',
            style: GoogleFonts.balsamiqSans(fontSize: 16),
          ),
          backgroundColor: Colors.green,
        ),
      );

      _kidEmailController.clear();
      setState(() {
        _selectedRelationship = null;
        _isAddKidExpanded = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: $e',
            style: GoogleFonts.balsamiqSans(fontSize: 16),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _kidEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFCE8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFEE82),
        elevation: 0,
        title: Text(
          'Kids Management',
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
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildExpandableSection(
                  title: 'Add a Kid',
                  isExpanded: _isAddKidExpanded,
                  onToggle: () {
                    setState(() {
                      _isAddKidExpanded = !_isAddKidExpanded;
                    });
                  },
                  children: [
                    _buildAddKidForm(),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSectionTitle('Your Requests'),
                _buildRequestsSection(),
                const SizedBox(height: 20),
                _buildSectionTitle('Approved Kids'),
                _buildApprovedKidsSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Manage Kid Profiles',
            style: GoogleFonts.balsamiqSans(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add or select kids to track their progress.',
            style: GoogleFonts.balsamiqSans(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        title,
        style: GoogleFonts.balsamiqSans(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildExpandableSection({
    required String title,
    required bool isExpanded,
    required VoidCallback onToggle,
    required List<Widget> children,
  }) {
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
      child: Column(
        children: [
          ListTile(
            title: Text(
              title,
              style: GoogleFonts.balsamiqSans(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            trailing: Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: const Color(0xFFFFEE82),
              size: 30,
            ),
            onTap: onToggle,
          ),
          AnimatedCrossFade(
            firstChild: Container(),
            secondChild: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildAddKidForm() {
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
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _kidEmailController,
              decoration: InputDecoration(
                labelText: 'Kid Email',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.email, color: Color(0xFFFFEE82)),
                labelStyle: GoogleFonts.balsamiqSans(),
              ),
              style: GoogleFonts.balsamiqSans(color: Colors.black87),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter the kid’s email';
                }
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _selectedRelationship,
              decoration: InputDecoration(
                labelText: 'Relationship',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.family_restroom, color: Color(0xFFFFEE82)),
                labelStyle: GoogleFonts.balsamiqSans(),
              ),
              style: GoogleFonts.balsamiqSans(color: Colors.black87),
              items: const [
                DropdownMenuItem(value: 'Parent', child: Text('Parent')),
                DropdownMenuItem(value: 'Grandparent', child: Text('Grandparent')),
                DropdownMenuItem(value: 'Teacher', child: Text('Teacher')),
                DropdownMenuItem(value: 'Older Sibling', child: Text('Older Sibling')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedRelationship = value;
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Please select a relationship';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _addKidProfile,
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
                    'Send Request',
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
    );
  }

  Widget _buildRequestsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Caregiver')
          .doc(caregiver!.uid)
          .collection('KidProfileSelected')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFFEE82)));
        }

        var allRequests = snapshot.data!.docs;
        var pendingRequests = allRequests
            .where((doc) => (doc.data() as Map<String, dynamic>)['status'] == 'Pending')
            .toList();

        if (pendingRequests.isEmpty) {
          return _buildNoDataMessage('No pending requests.');
        }

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pending Approvals',
                style: GoogleFonts.balsamiqSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pendingRequests.length,
                itemBuilder: (context, index) {
                  var request = pendingRequests[index].data() as Map<String, dynamic>;
                  return _buildRequestCard(
                    request['kidEmail'] ?? 'Unknown',
                    'Relationship: ${request['relationship']}',
                    'Pending',
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildApprovedKidsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Caregiver')
          .doc(caregiver!.uid)
          .collection('KidProfileSelected')
          .where('status', isEqualTo: 'Approved')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFFEE82)));
        }

        var approvedKids = snapshot.data!.docs;

        if (approvedKids.isEmpty) {
          return _buildNoDataMessage('No approved kids yet.');
        }

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select a Kid',
                style: GoogleFonts.balsamiqSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: approvedKids.length,
                itemBuilder: (context, index) {
                  var kidData = approvedKids[index].data() as Map<String, dynamic>;
                  String kidId = approvedKids[index].id;
                  String kidEmail = kidData['kidEmail'] ?? 'Unknown';
                  String relationship = kidData['relationship'] ?? 'Unknown';
                  bool isSelected = _selectedKidId == kidId;

                  return _buildKidCard(
                    kidEmail,
                    'Relationship: $relationship',
                    kidId,
                    isSelected,
                        () => _selectKid(kidId, kidEmail),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRequestCard(String title, String subtitle, String status) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEE82),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ListTile(
        title: Text(
          title,
          style: GoogleFonts.balsamiqSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.balsamiqSans(
            fontSize: 16,
            color: Colors.black54,
          ),
        ),
        trailing: Text(
          status,
          style: GoogleFonts.balsamiqSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildKidCard(String title, String subtitle, String kidId, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFEE82) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFEE82), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ListTile(
          title: Text(
            title,
            style: GoogleFonts.balsamiqSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: GoogleFonts.balsamiqSans(
              fontSize: 16,
              color: Colors.black54,
            ),
          ),
          trailing: ScaleTransition(
            scale: _iconAnimation,
            child: Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? Colors.green : Colors.grey,
              size: 30,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoDataMessage(String message) {
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
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _iconAnimation,
              child: const Icon(
                Icons.info_outline,
                size: 60,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: GoogleFonts.balsamiqSans(
                fontSize: 18,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}