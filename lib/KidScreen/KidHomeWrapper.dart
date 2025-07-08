import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:smartmatabcapp/KidScreen/KidAccount.dart';
import 'KidRewards.dart';
import 'KidBottomNavBar.dart';
import 'KidHome.dart';

class KidHomeWrapper extends StatefulWidget {
  const KidHomeWrapper({Key? key}) : super(key: key);

  @override
  _KidHomeWrapperState createState() => _KidHomeWrapperState();
}

class _KidHomeWrapperState extends State<KidHomeWrapper> {
  int _selectedIndex = 0;

  final GlobalKey<KidRewardsState> _rewardsKey = GlobalKey();

  late final List<Widget> _screens = [
    const KidsHome(),                     // index 0
    KidRewards(key: _rewardsKey), // index 1
    const KidAccount(),                  // index 2
  ];

  final List<String> _titles = [
    'Home',
    'Rewards',
    'Account',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Trigger reload when "My Stars" tab is tapped
    if (index == 1) {
      _rewardsKey.currentState?.reloadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFADD),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: KidBottomNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
}
