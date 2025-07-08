import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  _LoginState createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? selectedUserType;
  bool _isLoading = false;
  bool _obscurePassword = true;

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

  Future<void> _login() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (selectedUserType == null) {
        _showErrorDialog('Please select a user type.');
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        UserCredential userCredential =
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        String userId = userCredential.user!.uid;
        String collectionName = selectedUserType == 'Admin'
            ? 'Admin'
            : selectedUserType == 'Caregiver'
            ? 'Caregiver'
            : 'Kid';

        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection(collectionName)
            .doc(userId)
            .get();

        if (userDoc.exists) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Login successful as $selectedUserType!')),
          );

          switch (selectedUserType) {
            case 'Kid':
              Navigator.pushReplacementNamed(context, '/kidWrapper');
              break;
            case 'Admin':
              Navigator.pushReplacementNamed(context, '/adminHomeWrapper');
              break;
            case 'Caregiver':
              Navigator.pushReplacementNamed(context, '/caregiverHomeWrapper');
              break;
          }
        } else {
          _showErrorDialog(
              'User role mismatch. Please select the correct user type.');
        }
      } on FirebaseAuthException catch (e) {
        String message;
        switch (e.code) {
          case 'user-not-found':
            message = 'Username not found.';
            break;
          case 'wrong-password':
            message = 'Incorrect password.';
            break;
          case 'invalid-email':
            message = 'The email address is invalid.';
            break;
          case 'user-disabled':
            message = 'This user account has been disabled.';
            break;
          default:
            message = 'Incorrect password.';
            debugPrint('FirebaseAuthException: ${e.code} - ${e.message}');
        }
        _showErrorDialog(message);
      } catch (e) {
        debugPrint('Unexpected error during login: $e');
        _showErrorDialog('An unexpected error occurred. Please try again.');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
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
      backgroundColor: Color(0xFFFFFCE8),
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
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Login',
                        style: GoogleFonts.balsamiqSans(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
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
                          value: selectedUserType,
                          hint: Text(
                            'Select User Type',
                            style: GoogleFonts.balsamiqSans(
                              color: Colors.black54,
                              fontSize: 16,
                            ),
                          ),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide:
                              const BorderSide(color: Color(0xFFFFCA28)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: const BorderSide(
                                  color: Color(0xFFFFCA28), width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white, // Changed to white
                            prefixIcon: const Icon(Icons.person,
                                color: Color(0xFFFFCA28)),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 15, horizontal: 10),
                          ),
                          items: const [
                            DropdownMenuItem<String>(
                              value: 'Admin',
                              child: Row(
                                children: [
                                  Icon(Icons.admin_panel_settings,
                                      color: Color(0xFFFFCA28)),
                                  SizedBox(width: 10),
                                  Text('Admin'),
                                ],
                              ),
                            ),
                            DropdownMenuItem<String>(
                              value: 'Caregiver',
                              child: Row(
                                children: [
                                  Icon(Icons.favorite, color: Color(0xFFFFCA28)),
                                  SizedBox(width: 10),
                                  Text('Caregiver'),
                                ],
                              ),
                            ),
                            DropdownMenuItem<String>(
                              value: 'Kid',
                              child: Row(
                                children: [
                                  Icon(Icons.child_care,
                                      color: Color(0xFFFFCA28)),
                                  SizedBox(width: 10),
                                  Text('Kid'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              selectedUserType = value;
                            });
                          },
                          validator: (value) =>
                          value == null ? 'Please select a user type' : null,
                          dropdownColor: Colors.white,
                          icon: const Icon(Icons.arrow_drop_down,
                              color: Color(0xFFFFCA28)),
                          style: GoogleFonts.balsamiqSans(
                              color: Colors.black, fontSize: 16),
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
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            labelStyle: GoogleFonts.balsamiqSans(
                                color: Colors.black87),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide:
                              const BorderSide(color: Color(0xFFFFCA28)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: const BorderSide(
                                  color: Color(0xFFFFCA28), width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white, // Changed to white
                            prefixIcon: const Icon(Icons.email,
                                color: Color(0xFFFFCA28)),
                          ),
                          style: GoogleFonts.balsamiqSans(
                              color: Colors.black, fontSize: 16),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                                .hasMatch(value)) {
                              return 'Please enter a valid email';
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
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            labelStyle: GoogleFonts.balsamiqSans(
                                color: Colors.black87),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide:
                              const BorderSide(color: Color(0xFFFFCA28)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: const BorderSide(
                                  color: Color(0xFFFFCA28), width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white, // Changed to white
                            prefixIcon: const Icon(Icons.lock,
                                color: Color(0xFFFFCA28)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: const Color(0xFFFFCA28),
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          style: GoogleFonts.balsamiqSans(
                              color: Colors.black, fontSize: 16),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 30),
                      _isLoading
                          ? const CircularProgressIndicator(
                          color: Color(0xFFFFEE82))
                          : ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFEE82),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 50, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 5,
                          shadowColor: Colors.black.withOpacity(0.2),
                        ),
                        child: Text(
                          'Login',
                          style: GoogleFonts.balsamiqSans(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, '/signup');
                        },
                        child: Text(
                          "Don't have an account? Sign up here",
                          style: GoogleFonts.balsamiqSans(
                            fontSize: 16,
                            color: Color(0xFFFFCA28), // Changed to yellow
                          ),
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}