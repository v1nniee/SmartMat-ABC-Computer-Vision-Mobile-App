import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';

class CaregiverTrackProgress extends StatefulWidget {
  const CaregiverTrackProgress({super.key});

  @override
  _CaregiverTrackProgressState createState() => _CaregiverTrackProgressState();
}

class _CaregiverTrackProgressState extends State<CaregiverTrackProgress> {
  Map<String, dynamic> progressData = {};
  int totalMarks = 0;
  List<String> unlockedBadges = [];
  String? selectedKidId;
  bool _isLoading = true;
  bool _isScanLearnExpanded = true;
  bool _isWriteLearnExpanded = true;

  @override
  void initState() {
    super.initState();
    _loadSelectedKidAndProgress();
  }

  Future<void> reloadData() async {
    await _loadSelectedKidAndProgress();
  }

  Future<void> _loadSelectedKidAndProgress() async {
    setState(() => _isLoading = true);

    User? caregiver = FirebaseAuth.instance.currentUser;
    if (caregiver == null) {
      setState(() {
        _isLoading = false;
        selectedKidId = null;
      });
      return;
    }

    try {
      QuerySnapshot selectedKidDocs = await FirebaseFirestore.instance
          .collection('Caregiver')
          .doc(caregiver.uid)
          .collection('KidSelected')
          .get();

      if (selectedKidDocs.docs.isNotEmpty) {
        var selectedKidDoc = selectedKidDocs.docs.first.data() as Map<String, dynamic>;
        selectedKidId = selectedKidDoc['kidId'] as String?;

        if (selectedKidId != null) {
          Map<String, dynamic> data = await fetchLearningProgress(selectedKidId!);
          _calculateMarksAndBadges(data);
          setState(() {
            progressData = data;
          });
        } else {
          setState(() => selectedKidId = null);
        }
      } else {
        setState(() => selectedKidId = null);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading progress: $e')),
      );
      setState(() => selectedKidId = null);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<Map<String, dynamic>> fetchLearningProgress(String kidId) async {
    Map<String, dynamic> progressData = {};

    try {
      DocumentSnapshot alphabetSnapshot = await FirebaseFirestore.instance
          .collection('Kid')
          .doc(kidId)
          .collection('AlphabetLearningProgress')
          .doc('progress')
          .get();

      DocumentSnapshot handwritingSnapshot = await FirebaseFirestore.instance
          .collection('Kid')
          .doc(kidId)
          .collection('HandwritingLearningProgress')
          .doc('progress')
          .get();

      DocumentSnapshot matWordFormationSnapshot = await FirebaseFirestore.instance
          .collection('Kid')
          .doc(kidId)
          .collection('MatWordFormationProgress')
          .doc('progress')
          .get();

      DocumentSnapshot handwritingWordFormationSnapshot = await FirebaseFirestore.instance
          .collection('Kid')
          .doc(kidId)
          .collection('HandwritingWordFormationProgress')
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
      progressData['handwritingWordFormation'] = handwritingWordFormationSnapshot.exists
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
        int detections = (progress['totalDetections'] as num?)?.toInt() ?? 0;
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
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.orange[300], size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'BubblegumSans',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  content,
                  style: TextStyle(
                    fontFamily: 'BubblegumSans',
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
      backgroundColor: Colors.yellow[50],
      appBar: AppBar(
        title: const Text(
          'Track Kid Progress',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'BubblegumSans',
          ),
        ),
        backgroundColor: Colors.orange[300],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: _isLoading
              ? const Center(
            child: CircularProgressIndicator(color: Colors.orangeAccent),
          )
              : selectedKidId == null
              ? const Center(
            child: Text(
              'No kid selected. Please select a kid first.',
              style: TextStyle(
                fontFamily: 'BubblegumSans',
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
          )
              : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Expanded(
                child: progressData.isEmpty
                    ? _buildNoDataMessage()
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
        border: Border.all(color: Colors.orangeAccent, width: 2),
        borderRadius: BorderRadius.circular(15),
        color: Colors.white,
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(
              title,
              style: TextStyle(
                fontFamily: 'BubblegumSans',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            trailing: Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.orange[300],
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

  Widget _buildProgressSummary() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orangeAccent, width: 2),
        borderRadius: BorderRadius.circular(15),
        color: Colors.white,
      ),
      padding: const EdgeInsets.all(14.0),
      child: Column(
        children: [
          _buildInfoTile(Icons.trending_up, 'Total Marks', totalMarks.toString()),
          const Divider(),
          _buildInfoTile(Icons.badge, 'Unlocked Badges', ''),
          ...unlockedBadges.map(
                (badge) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                badge,
                style: TextStyle(
                  fontFamily: 'BubblegumSans',
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
        color: Colors.orange[300],
        size: 30,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'BubblegumSans',
          fontSize: 18,
          color: Colors.grey[600],
        ),
      ),
      subtitle: Text(
        value,
        style: TextStyle(
          fontFamily: 'BubblegumSans',
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
        style: TextStyle(
          fontFamily: 'BubblegumSans',
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
            color: Colors.orange[300],
            width: 16,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orangeAccent, width: 2),
        borderRadius: BorderRadius.circular(15),
        color: Colors.white,
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
                      style: TextStyle(
                        fontFamily: 'BubblegumSans',
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
                      style: TextStyle(
                        fontFamily: 'BubblegumSans',
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
          (entry.value['totalDetections'] as num?)?.toDouble() ?? 0.0;
      return BarChartGroupData(
        x: entry.key.codeUnitAt(0) - 65,
        barRods: [
          BarChartRodData(
            toY: totalDetections,
            color: Colors.orange[300],
            width: 16,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orangeAccent, width: 2),
        borderRadius: BorderRadius.circular(15),
        color: Colors.white,
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
                      style: TextStyle(
                        fontFamily: 'BubblegumSans',
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
                      style: TextStyle(
                        fontFamily: 'BubblegumSans',
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
        border: Border.all(color: Colors.orangeAccent, width: 2),
        borderRadius: BorderRadius.circular(15),
        color: Colors.white,
      ),
      padding: const EdgeInsets.all(14.0),
      child: Column(
        children: progressData['matWordFormation'].entries.map<Widget>((entry) {
          return ListTile(
            leading: Icon(Icons.check_circle, color: Colors.orange[300], size: 30),
            title: Text(
              "Word: ${entry.key}",
              style: TextStyle(
                fontFamily: 'BubblegumSans',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            subtitle: Text(
              "Successful Attempts: ${entry.value['successfulAttempts']}",
              style: TextStyle(
                fontFamily: 'BubblegumSans',
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
        border: Border.all(color: Colors.orangeAccent, width: 2),
        borderRadius: BorderRadius.circular(15),
        color: Colors.white,
      ),
      padding: const EdgeInsets.all(14.0),
      child: Column(
        children:
        progressData['handwritingWordFormation'].entries.map<Widget>((entry) {
          return ListTile(
            leading: Icon(Icons.check_circle, color: Colors.orange[300], size: 30),
            title: Text(
              "Word: ${entry.key}",
              style: TextStyle(
                fontFamily: 'BubblegumSans',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            subtitle: Text(
              "Successful Attempts: ${entry.value['successfulAttempts']}",
              style: TextStyle(
                fontFamily: 'BubblegumSans',
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
        border: Border.all(color: Colors.orangeAccent, width: 2),
        borderRadius: BorderRadius.circular(15),
        color: Colors.white,
      ),
      padding: const EdgeInsets.all(14.0),
      child: Center(
        child: Text(
          "No progress yet! Keep playing! 😊",
          style: TextStyle(
            fontFamily: 'BubblegumSans',
            fontSize: 18,
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }
}