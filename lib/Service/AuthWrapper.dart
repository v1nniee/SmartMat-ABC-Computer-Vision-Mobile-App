import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smartmatabcapp/CaregiverScreen/CaregiverHomeWrapper.dart';
import 'package:smartmatabcapp/KidScreen/KidHomeWrapper.dart';

import '../AdminScreen/AdminHome.dart';
import '../AdminScreen/AdminHomeWrapper.dart';
import '../CaregiverScreen/CaregiverHome.dart';
import '../KidScreen/KidHome.dart';
import '../Screen/Intro.dart';

// This widget decides which screen to show based on auth state.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  Future<String?> _fetchUserType(String uid) async {
    // 1) Check if user is in Admin collection
    final adminDoc = await FirebaseFirestore.instance
        .collection('Admin')
        .doc(uid)
        .get();
    if (adminDoc.exists) return 'Admin';

    // 2) Check Caregiver collection
    final caregiverDoc = await FirebaseFirestore.instance
        .collection('Caregiver')
        .doc(uid)
        .get();
    if (caregiverDoc.exists) return 'Caregiver';

    // 3) Check Kid collection
    final kidDoc = await FirebaseFirestore.instance
        .collection('Kid')
        .doc(uid)
        .get();
    if (kidDoc.exists) return 'Kid';

    // If not found in any, return null
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // StreamBuilder listens to auth changes in real time:
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // If the connection is still loading, show a simple progress indicator
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If user is null, they're NOT logged in
        if (!snapshot.hasData || snapshot.data == null) {
          return const Intro(title: 'SmartMat ABC');
        }

        // If we do have a user, check the Firestore to determine user type
        final currentUser = snapshot.data!;
        return FutureBuilder<String?>(
          future: _fetchUserType(currentUser.uid),
          builder: (context, userTypeSnapshot) {
            if (userTypeSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final userType = userTypeSnapshot.data;

            if (userType == 'Admin') {
              return const AdminHomeWrapper();
            } else if (userType == 'Caregiver') {
              return CaregiverHomeWrapper();
            } else if (userType == 'Kid') {
              return KidHomeWrapper();
            } else {
              // If somehow the user is logged in but not found in any collection
              // either show an error or fallback to Intro
              return const Intro(title: 'SmartMat ABC');
            }
          },
        );
      },
    );
  }
}
