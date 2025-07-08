import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:smartmatabcapp/AdminScreen/AdminAddWords.dart';
import 'package:smartmatabcapp/AdminScreen/AdminEditProfile.dart';
import 'package:smartmatabcapp/AdminScreen/AdminHome.dart';
import 'package:smartmatabcapp/AdminScreen/AdminAddVideos.dart';
import 'package:smartmatabcapp/AdminScreen/AdminViewVideo.dart';
import 'package:smartmatabcapp/AdminScreen/AdminViewWords.dart';
import 'package:smartmatabcapp/CaregiverScreen/CaregiverAccount.dart';
import 'package:smartmatabcapp/CaregiverScreen/CaregiverChangePassword.dart';
import 'package:smartmatabcapp/CaregiverScreen/CaregiverEditProfile.dart';
import 'package:smartmatabcapp/CaregiverScreen/CaregiverHomeWrapper.dart';
import 'package:smartmatabcapp/CaregiverScreen/CaregiverTrackProgress.dart';
import 'package:smartmatabcapp/CaregiverScreen/CaregiverViewReport.dart';
import 'package:smartmatabcapp/CaregiverScreen/CaregiverManageKids.dart';
import 'package:smartmatabcapp/KidScreen/KidRewards.dart';
import 'package:smartmatabcapp/KidScreen/KidScantoLearnAlphabets.dart';
import 'package:smartmatabcapp/KidScreen/KidAccount.dart';
import 'package:smartmatabcapp/KidScreen/KidChangePassword.dart';
import 'package:smartmatabcapp/KidScreen/KidEditProfile.dart';
import 'package:smartmatabcapp/KidScreen/KidHome.dart';
import 'package:smartmatabcapp/CaregiverScreen/CaregiverHome.dart';
import 'package:smartmatabcapp/KidScreen/KidWritetoLearnWord.dart';
import 'package:smartmatabcapp/Screen/Login.dart';
import 'AdminScreen/AdminChangePassword.dart';
import 'AdminScreen/AdminHomeWrapper.dart';
import 'KidScreen/KidApproveRejectCaregiver.dart';
import 'KidScreen/KidWritetoLearnAlphabets.dart';
import 'KidScreen/KidHomeWrapper.dart';
import 'KidScreen/KidScantoLearnWord.dart';
import 'Screen/SignUp.dart';
import 'Service/AuthWrapper.dart';
import 'Service/ModelManager.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();

  if(kIsWeb) {
    await Firebase.initializeApp(options: FirebaseOptions(
        apiKey: "AIzaSyCraG63pDXWY0gSO-XyPFPuCauA2TNUGVw",
        authDomain: "smart-mat-abc-app.firebaseapp.com",
        projectId: "smart-mat-abc-app",
        storageBucket: "smart-mat-abc-app.firebasestorage.app",
        messagingSenderId: "476023449255",
        appId: "1:476023449255:web:9d976d9e3ecfbadb401d82"
    ));
  }else{
    await Firebase.initializeApp();
  }
  await ModelManager().loadModels();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartMat ABC',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // Instead of initialRoute: '/', use a "home" that checks auth status:
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const Login(),
        '/signup': (context) => const SignUp(),
        '/kidshome': (context) => KidsHome(),
        '/adminhome': (context) => AdminHome(),
        '/caregiverhome': (context) => CaregiverHome(),
        '/kidApproveRejectCaregiver': (context) => KidApproveRejectCaregiver(),
        '/kidScantoLearnAlphabets': (context) => KidScantoLearnAlphabets(),
        '/kidScantoLearnWord': (context) => KidScantoLearnWord(),
        '/kidRewards' : (context) => KidRewards(),
        '/kidWrapper': (context) => const KidHomeWrapper(),
        '/kidAccount': (context) => KidAccount(),
        '/kidEditProfile': (context) => KidEditProfile(),
        '/kidChangePassword': (context) => KidChangePassword(),
        '/caregiverAccount': (context) => CaregiverAccount(),
        '/caregiverHomeWrapper': (context) => CaregiverHomeWrapper(),
        '/caregiverEditProfile': (context) => CaregiverEditProfile(),
        '/caregiverChangePassword': (context) => CaregiverChangePassword(),
        '/caregiverTrackProgress': (context) => CaregiverTrackProgress(),
        '/caregiverViewReport': (context) => CaregiverViewReport(),
        '/kidWritetoLearnAlphabets': (context) => KidWritetoLearnAlphabets(),
        '/adminHomeWrapper': (context) => AdminHomeWrapper(),
        '/adminEditProfile': (context) => AdminEditProfile(),
        '/adminChangePassword': (context) => AdminChangePassword(),
        '/adminAddVideos': (context) => AdminAddVideos(),
        '/adminViewVideos': (context) => AdminViewVideos(),
        '/adminAddWords': (context) => AdminAddWords(),
        '/adminViewWords': (context) => AdminViewWords(),
        '/kidWritetoLearnWord': (context) => KidWritetoLearnWord(),
        '/caregiverManageKids': (context) => CaregiverManageKids(),
      },
    );
  }
}

