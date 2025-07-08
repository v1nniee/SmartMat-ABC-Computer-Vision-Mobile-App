import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:smartmatabcapp/CaregiverScreen/CaregiverHome.dart';
import 'package:smartmatabcapp/CaregiverScreen/CaregiverAccount.dart';
import 'package:smartmatabcapp/CaregiverScreen/CaregiverManageKids.dart';
import 'CaregiverBottomNavBar.dart';

class CaregiverHomeWrapper extends StatefulWidget {
  const CaregiverHomeWrapper({Key? key}) : super(key: key);

  @override
  _CaregiverHomeWrapperState createState() => _CaregiverHomeWrapperState();
}

class _CaregiverHomeWrapperState extends State<CaregiverHomeWrapper> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    CaregiverHome(),        // index 0
    CaregiverManageKids(),  // index 1
    CaregiverAccount(),     // index 2
  ];

  // Titles that match each tab
  final List<String> _titles = [
    'Home',
    'Kids Management',
    'Account',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFADD),
      // Show the correct title for whichever tab is active:
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: CaregiverBottomNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
}