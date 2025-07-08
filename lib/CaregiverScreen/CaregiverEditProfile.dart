import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

class CaregiverEditProfile extends StatefulWidget {
  const CaregiverEditProfile({Key? key}) : super(key: key);

  @override
  _CaregiverEditProfileState createState() => _CaregiverEditProfileState();
}

class _CaregiverEditProfileState extends State<CaregiverEditProfile> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final User? user = FirebaseAuth.instance.currentUser;

  // Controllers
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  String? _selectedGender;

  // Loading state
  bool _isLoading = false;

  // Animation
  late AnimationController _animationController;
  late Animation<double> _iconAnimation;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFFFFCA28),
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    _loadUserData();
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

  // Fetch current user data from Firestore
  Future<void> _loadUserData() async {
    try {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('Caregiver')
          .doc(user?.uid)
          .get();

      if (snapshot.exists) {
        setState(() {
          _fullNameController.text = snapshot.get('fullName') ?? '';
          _dobController.text = snapshot.get('dateOfBirth') ?? '';
          _selectedGender = snapshot.get('gender');
        });
      }
    } catch (e) {
      _showErrorDialog('Error loading profile: $e');
    }
  }

  // Date picker for DOB
  Future<void> _selectDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFFCA28),
              onPrimary: Colors.black,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (pickedDate != null) {
      setState(() {
        _dobController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
      });
    }
  }

  // Save updated profile to Firestore
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance.collection('Caregiver').doc(user?.uid).update({
        'fullName': _fullNameController.text.trim(),
        'dateOfBirth': _dobController.text.trim(),
        'gender': _selectedGender,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profile updated successfully!',
            style: GoogleFonts.balsamiqSans(fontSize: 16),
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      _showErrorDialog('Error updating profile: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
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

  @override
  void dispose() {
    _fullNameController.dispose();
    _dobController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFADD),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFEE82),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Profile',
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
                color: Color(0xFFFFFADD),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _fullNameController,
                        decoration: InputDecoration(
                          labelText: 'Full Name',
                          labelStyle: GoogleFonts.balsamiqSans(color: Colors.black87),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(color: Color(0xFFFFCA28)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(color: Color(0xFFFFCA28), width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: ScaleTransition(
                            scale: _iconAnimation,
                            child: const Icon(Icons.person_outline, color: Color(0xFFFFCA28)),
                          ),
                        ),
                        style: GoogleFonts.balsamiqSans(color: Colors.black, fontSize: 16),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your full name';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _dobController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Date of Birth',
                          labelStyle: GoogleFonts.balsamiqSans(color: Colors.black87),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(color: Color(0xFFFFCA28)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(color: Color(0xFFFFCA28), width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: ScaleTransition(
                            scale: _iconAnimation,
                            child: const Icon(Icons.calendar_today, color: Color(0xFFFFCA28)),
                          ),
                          suffixIcon: IconButton(
                            icon: ScaleTransition(
                              scale: _iconAnimation,
                              child: const Icon(Icons.date_range, color: Color(0xFFFFCA28)),
                            ),
                            onPressed: () => _selectDate(context),
                          ),
                        ),
                        style: GoogleFonts.balsamiqSans(color: Colors.black, fontSize: 16),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select your date of birth';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedGender,
                        hint: Text(
                          'Select Gender',
                          style: GoogleFonts.balsamiqSans(color: Colors.black54, fontSize: 16),
                        ),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(color: Color(0xFFFFCA28)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(color: Color(0xFFFFCA28), width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: ScaleTransition(
                            scale: _iconAnimation,
                            child: const Icon(Icons.people, color: Color(0xFFFFCA28)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                        ),
                        items: const [
                          DropdownMenuItem<String>(
                            value: 'Male',
                            child: Row(
                              children: [
                                Icon(Icons.male, color: Color(0xFFFFCA28)),
                                SizedBox(width: 10),
                                Text('Male'),
                              ],
                            ),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Female',
                            child: Row(
                              children: [
                                Icon(Icons.female, color: Color(0xFFFFCA28)),
                                SizedBox(width: 10),
                                Text('Female'),
                              ],
                            ),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Other',
                            child: Row(
                              children: [
                                Icon(Icons.transgender, color: Color(0xFFFFCA28)),
                                SizedBox(width: 10),
                                Text('Other'),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedGender = value;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select a gender';
                          }
                          return null;
                        },
                        dropdownColor: Colors.white,
                        icon: ScaleTransition(
                          scale: _iconAnimation,
                          child: const Icon(Icons.arrow_drop_down, color: Color(0xFFFFCA28)),
                        ),
                        style: GoogleFonts.balsamiqSans(color: Colors.black, fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 30),
                    _isLoading
                        ? const CircularProgressIndicator(color: Color(0xFFFFEE82))
                        : GestureDetector(
                      onTap: _saveProfile,
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
                            'Save Changes',
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
        ],
      ),
    );
  }
}