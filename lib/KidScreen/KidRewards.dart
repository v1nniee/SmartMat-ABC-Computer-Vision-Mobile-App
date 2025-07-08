import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

class KidRewards extends StatefulWidget {
  const KidRewards({Key? key}) : super(key: key);

  @override
  KidRewardsState createState() => KidRewardsState();
}

class KidRewardsState extends State<KidRewards> {
  Map<String, dynamic> progressData = {};
  int totalMarks = 0;
  List<String> unlockedBadges = [];
  bool _isScanLearnExpanded = false; // Changed to false for initial collapse
  bool _isWriteLearnExpanded = false; // Changed to false for initial collapse

  @override
  void initState() {
    super.initState();
    _loadProgressData();
  }

  Future<void> reloadData() async {
    await _loadProgressData();
  }

  Future<void> _loadProgressData() async {
    Map<String, dynamic> data = await fetchLearningProgress();
    _calculateMarksAndBadges(data);
    setState(() {
      progressData = data;
    });
  }

  Future<Map<String, dynamic>> fetchLearningProgress() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};

    String userId = user.uid;
    Map<String, dynamic> progressData = {};

    try {
      DocumentSnapshot alphabetSnapshot = await FirebaseFirestore.instance
          .collection('Kid')
          .doc(userId)
          .collection('ScanToLearnAlphabetProgress')
          .doc('progress')
          .get();

      DocumentSnapshot handwritingSnapshot = await FirebaseFirestore.instance
          .collection('Kid')
          .doc(userId)
          .collection('WriteToLearnAlphabetProgress')
          .doc('progress')
          .get();

      DocumentSnapshot matWordFormationSnapshot = await FirebaseFirestore.instance
          .collection('Kid')
          .doc(userId)
          .collection('ScanToFormWordProgress')
          .doc('progress')
          .get();

      DocumentSnapshot handwritingWordFormationSnapshot =
      await FirebaseFirestore.instance
          .collection('Kid')
          .doc(userId)
          .collection('WriteToFormWordProgress')
          .doc('progress')
          .get();

      progressData['alphabet'] = alphabetSnapshot.exists
          ? alphabetSnapshot.data() as Map<String, dynamic>
          : {};
      progressData['handwriting'] = handwritingSnapshot.exists
          ? handwritingSnapshot.data() as Map<String, dynamic>
          : {};
      progressData['matWordFormation'] = matWordFormationSnapshot.exists
          ? matWordFormationSnapshot.data() as Map<String, dynamic>
          : {};
      progressData['handwritingWordFormation'] =
      handwritingWordFormationSnapshot.exists
          ? handwritingWordFormationSnapshot.data() as Map<String, dynamic>
          : {};
    } catch (e) {
      print("Error fetching progress data: $e");
    }

    return progressData;
  }

  void _calculateMarksAndBadges(Map<String, dynamic> data) {
    int marks = 0;
    List<String> badges = [];

    if (data['alphabet'] != null && data['alphabet'] is Map) {
      data['alphabet'].forEach((letter, progress) {
        int detections = (progress['totalDetections'] as num?)?.toInt() ?? 0;
        marks += detections * 5;
      });
    }

    if (data['handwriting'] != null && data['handwriting'] is Map) {
      data['handwriting'].forEach((letter, progress) {
        int detections = (progress['successfulAttempts'] as num?)?.toInt() ?? 0;
        marks += detections * 5;
      });
    }

    if (data['matWordFormation'] != null && data['matWordFormation'] is Map) {
      data['matWordFormation'].forEach((word, progress) {
        int attempts =
            int.tryParse(progress['successfulAttempts']?.toString() ?? '0') ?? 0;
        marks += attempts * 5;
      });
    }

    if (data['handwritingWordFormation'] != null &&
        data['handwritingWordFormation'] is Map) {
      data['handwritingWordFormation'].forEach((word, progress) {
        int attempts =
            int.tryParse(progress['successfulAttempts']?.toString() ?? '0') ?? 0;
        marks += attempts * 5;
      });
    }

    totalMarks = marks;

    if (marks >= 50) badges.add("Beginner Badge 🎓");
    if (marks >= 100) badges.add("Advanced Badge 🏅");
    if (marks >= 200) badges.add("Expert Badge 🏆");
    if (marks >= 500) badges.add("Master Badge 👑");

    setState(() {
      unlockedBadges = badges;
    });
  }

  void _showRewardGuideDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFFCE8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Reward Guide",
                style: GoogleFonts.balsamiqSans(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildQuestSection(
                  icon: Icons.check_circle,
                  title: "How to Earn Marks?",
                  content: "Every activity earns 5 marks! \n",
                  bgColor: Colors.white,
                ),
                const SizedBox(height: 12),
                _buildQuestSection(
                  icon: Icons.emoji_events,
                  title: "Earn Badges!",
                  content: "50 marks: Beginner Badge 🎓\n"
                      "100 marks: Advanced Badge 🏅\n"
                      "200 marks: Expert Badge 🏆\n"
                      "500 marks: Master Badge 👑",
                  bgColor: Colors.white,
                ),
              ],
            ),
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFEE82),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 24),
                      elevation: 5,
                    ),
                    child: Text(
                      "Start Earning!",
                      style: GoogleFonts.balsamiqSans(
                        fontSize: 18,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuestSection({
    required IconData icon,
    required String title,
    required String content,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: const Color(0xFFFFEE82), width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.black, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.balsamiqSans(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  content,
                  style: GoogleFonts.balsamiqSans(
                    fontSize: 16,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFCE8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFEE82),
        elevation: 0,
        title: Text(
          'Rewards',
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: _showRewardGuideDialog,
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.info, size: 28, color: Colors.black),
                      const SizedBox(width: 10),
                      Text(
                        'Reward Guide',
                        style: GoogleFonts.balsamiqSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: progressData.isEmpty
                    ? Center(
                  child: CircularProgressIndicator(
                      color: const Color(0xFFFFEE82)),
                )
                    : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildProgressSummary(),
                      const SizedBox(height: 20),
                      _buildExpandableSection(
                        title: "Scan & Learn",
                        isExpanded: _isScanLearnExpanded,
                        onToggle: () {
                          setState(() {
                            _isScanLearnExpanded = !_isScanLearnExpanded;
                          });
                        },
                        children: [
                          _buildSectionTitle("Scan to Learn Alphabets"),
                          _buildAlphabetProgress(),
                          const SizedBox(height: 20),
                          _buildSectionTitle("Scan to Form a Word"),
                          _buildMatWordFormationProgress(),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildExpandableSection(
                        title: "Write & Learn",
                        isExpanded: _isWriteLearnExpanded,
                        onToggle: () {
                          setState(() {
                            _isWriteLearnExpanded = !_isWriteLearnExpanded;
                          });
                        },
                        children: [
                          _buildSectionTitle("Write to Learn Alphabets"),
                          _buildHandwritingProgress(),
                          const SizedBox(height: 20),
                          _buildSectionTitle("Write to Form a Word"),
                          _buildHandwritingWordFormationProgress(),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
        border: Border.all(color: const Color(0xFFFFEE82), width: 2),
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
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
              color: Colors.black,
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
            crossFadeState:
            isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSummary() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFFFEE82), width: 2),
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
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
        children: [
          _buildInfoTile(Icons.trending_up, 'Total Marks', totalMarks.toString()),
          const Divider(),
          _buildInfoTile(Icons.badge, 'Unlocked Badges', ''),
          ...unlockedBadges.map(
                (badge) => Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                badge,
                style: GoogleFonts.balsamiqSans(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String value) {
    return ListTile(
      leading: Icon(
        icon,
        color: Colors.black,
        size: 30,
      ),
      title: Text(
        title,
        style: GoogleFonts.balsamiqSans(
          fontSize: 18,
          color: Colors.grey[600],
        ),
      ),
      subtitle: Text(
        value,
        style: GoogleFonts.balsamiqSans(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
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

  Widget _buildAlphabetProgress() {
    if (progressData['alphabet'] == null || progressData['alphabet'].isEmpty) {
      return _buildNoDataMessage();
    }

    List<BarChartGroupData> barGroups = progressData['alphabet']
        .entries
        .map<BarChartGroupData>((entry) {
      double totalDetections =
          (entry.value['totalDetections'] as num?)?.toDouble() ?? 0.0;
      return BarChartGroupData(
        x: entry.key.codeUnitAt(0) - 65,
        barRods: [
          BarChartRodData(
            toY: totalDetections,
            color: const Color(0xFFFFEE82),
            width: 16,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFFFEE82), width: 2),
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14.0),
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            barGroups: barGroups,
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final letter = String.fromCharCode(value.toInt() + 65);
                    return Text(
                      letter,
                      style: GoogleFonts.balsamiqSans(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    );
                  },
                  reservedSize: 30,
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      value.toInt().toString(),
                      style: GoogleFonts.balsamiqSans(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    );
                  },
                ),
              ),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHandwritingProgress() {
    if (progressData['handwriting'] == null || progressData['handwriting'].isEmpty) {
      return _buildNoDataMessage();
    }

    List<BarChartGroupData> barGroups = progressData['handwriting']
        .entries
        .map<BarChartGroupData>((entry) {
      double totalDetections =
          (entry.value['successfulAttempts'] as num?)?.toDouble() ?? 0.0;
      return BarChartGroupData(
        x: entry.key.codeUnitAt(0) - 65,
        barRods: [
          BarChartRodData(
            toY: totalDetections,
            color: const Color(0xFFFFEE82),
            width: 16,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFFFEE82), width: 2),
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14.0),
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            barGroups: barGroups,
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final letter = String.fromCharCode(value.toInt() + 65);
                    return Text(
                      letter,
                      style: GoogleFonts.balsamiqSans(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    );
                  },
                  reservedSize: 30,
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      value.toInt().toString(),
                      style: GoogleFonts.balsamiqSans(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    );
                  },
                ),
              ),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMatWordFormationProgress() {
    if (progressData['matWordFormation'] == null ||
        progressData['matWordFormation'].isEmpty) {
      return _buildNoDataMessage();
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFFFEE82), width: 2),
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
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
        children: progressData['matWordFormation'].entries.map<Widget>((entry) {
          return ListTile(
            leading: Icon(Icons.check_circle, color: Colors.black, size: 30),
            title: Text(
              "Word: ${entry.key}",
              style: GoogleFonts.balsamiqSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            subtitle: Text(
              "Successful Attempts: ${entry.value['successfulAttempts']}",
              style: GoogleFonts.balsamiqSans(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHandwritingWordFormationProgress() {
    if (progressData['handwritingWordFormation'] == null ||
        progressData['handwritingWordFormation'].isEmpty) {
      return _buildNoDataMessage();
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFFFEE82), width: 2),
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
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
        children:
        progressData['handwritingWordFormation'].entries.map<Widget>((entry) {
          return ListTile(
            leading: Icon(Icons.check_circle, color: Colors.black, size: 30),
            title: Text(
              "Word: ${entry.key}",
              style: GoogleFonts.balsamiqSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            subtitle: Text(
              "Successful Attempts: ${entry.value['successfulAttempts']}",
              style: GoogleFonts.balsamiqSans(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNoDataMessage() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFFFEE82), width: 2),
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
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
        child: Text(
          "No progress yet! Keep playing! 😊",
          style: GoogleFonts.balsamiqSans(
            fontSize: 18,
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }
}