import 'package:flutter/material.dart';
import 'AdminHome.dart';
import 'AdminAccount.dart';
import 'AdminBottomNavBar.dart';

class AdminHomeWrapper extends StatefulWidget {
  const AdminHomeWrapper({Key? key}) : super(key: key);

  @override
  _AdminHomeWrapperState createState() => _AdminHomeWrapperState();
}

class _AdminHomeWrapperState extends State<AdminHomeWrapper> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    AdminHome(),          // index 0
    AdminAccount(),       // index 2 (Placeholder for account)
  ];

  final List<String> _titles = [
    'Home',
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
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: AdminBottomNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
}