import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class KidBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const KidBottomNavBar({
    Key? key,
    required this.selectedIndex,
    required this.onItemTapped,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFADD), // Explicitly set the background color
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, -4),
              spreadRadius: 0, // Prevent shadow from causing color artifacts
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(context, Icons.home, 'Home', 0),
            _buildNavItem(context, Icons.star, 'Rewards', 1),
            _buildNavItem(context, Icons.person, 'Account', 2),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, String label, int index) {
    bool isSelected = selectedIndex == index;
    const Color primaryColor = Color(0xFFFAF4C8);
    const Color selectedIconColor = Color(0xFFFFE173);
    const Color selectedTextColor = Color(0xFFFFE173);

    return GestureDetector(
      onTap: () => onItemTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14), // Smaller padding
        decoration: isSelected
            ? BoxDecoration(
          color: primaryColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.3),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        )
            : BoxDecoration(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 30, // Smaller icon
              color: isSelected ? selectedIconColor : Colors.grey[600],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.balsamiqSans(
                fontSize: 12, // Smaller text
                fontWeight: FontWeight.w600,
                color: isSelected ? selectedTextColor : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
