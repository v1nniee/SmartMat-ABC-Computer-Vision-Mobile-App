import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;

class CaregiverViewReport extends StatefulWidget {
  const CaregiverViewReport({Key? key}) : super(key: key);

  @override
  _CaregiverViewReportState createState() => _CaregiverViewReportState();
}

class _CaregiverViewReportState extends State<CaregiverViewReport> {
  Map<String, dynamic> progressData = {};
  String? selectedKidId;
  String? selectedKidEmail;
  bool _isLoading = true;
  bool _isScanLearnExpanded = false;
  bool _isWriteLearnExpanded = false;
  int totalMarks = 0;
  List<String> unlockedBadges = [];
  GlobalKey engagementChartKey = GlobalKey();
  GlobalKey alphabetChartKey = GlobalKey();
  GlobalKey handwritingChartKey = GlobalKey();
  GlobalKey alphabetHeatmapKey = GlobalKey();
  GlobalKey handwritingHeatmapKey = GlobalKey();
  Uint8List? engagementChartImage;
  Uint8List? alphabetChartImage;
  Uint8List? handwritingChartImage;
  Uint8List? alphabetHeatmapImage;
  Uint8List? handwritingHeatmapImage;

  @override
  void initState() {
    super.initState();
    _loadSelectedKidAndProgress();
  }

  Map<String, dynamic> _castToMapStringDynamic(dynamic data) {
    if (data == null) return {};
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    print('Unexpected data type: ${data.runtimeType}');
    return {};
  }

  Future<void> _loadSelectedKidAndProgress() async {
    setState(() => _isLoading = true);

    User? caregiver = FirebaseAuth.instance.currentUser;
    if (caregiver == null) {
      setState(() {
        _isLoading = false;
        selectedKidId = null;
        selectedKidEmail = null;
        progressData = {};
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No caregiver logged in.')),
      );
      return;
    }

    try {
      QuerySnapshot selectedKidDocs = await FirebaseFirestore.instance
          .collection('Caregiver')
          .doc(caregiver.uid)
          .collection('KidSelected')
          .get();

      if (selectedKidDocs.docs.isNotEmpty) {
        var selectedKidDoc =
            _castToMapStringDynamic(selectedKidDocs.docs.first.data());
        selectedKidId = selectedKidDoc['kidId'] as String?;
        selectedKidEmail = selectedKidDoc['kidEmail'] as String?;

        if (selectedKidId != null) {
          Map<String, dynamic> data =
              await fetchLearningProgress(selectedKidId!);
          print('Loaded progressData: $data');
          setState(() {
            progressData = data;
            _calculateMarksAndBadges();
          });
        } else {
          setState(() {
            selectedKidId = null;
            selectedKidEmail = null;
            progressData = {};
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No kid ID found.')),
          );
        }
      } else {
        setState(() {
          selectedKidId = null;
          selectedKidEmail = null;
          progressData = {};
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No kid selected.')),
        );
      }
    } catch (e) {
      print('Error loading selected kid: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading selected kid: $e')),
      );
      setState(() {
        selectedKidId = null;
        selectedKidEmail = null;
        progressData = {};
      });
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
          .collection('ScanToLearnAlphabetProgress')
          .doc('progress')
          .get();

      DocumentSnapshot handwritingSnapshot = await FirebaseFirestore.instance
          .collection('Kid')
          .doc(kidId)
          .collection('WriteToLearnAlphabetProgress')
          .doc('progress')
          .get();

      DocumentSnapshot matWordFormationSnapshot = await FirebaseFirestore
          .instance
          .collection('Kid')
          .doc(kidId)
          .collection('ScanToFormWordProgress')
          .doc('progress')
          .get();

      DocumentSnapshot handwritingWordFormationSnapshot =
          await FirebaseFirestore.instance
              .collection('Kid')
              .doc(kidId)
              .collection('WriteToFormWordProgress')
              .doc('progress')
              .get();

      progressData['alphabet'] = alphabetSnapshot.exists
          ? _castToMapStringDynamic(alphabetSnapshot.data())
          : {};
      progressData['handwriting'] = handwritingSnapshot.exists
          ? _castToMapStringDynamic(handwritingSnapshot.data())
          : {};
      progressData['matWordFormation'] = matWordFormationSnapshot.exists
          ? _castToMapStringDynamic(matWordFormationSnapshot.data())
          : {};
      progressData['handwritingWordFormation'] =
          handwritingWordFormationSnapshot.exists
              ? _castToMapStringDynamic(handwritingWordFormationSnapshot.data())
              : {};
    } catch (e) {
      print('Error fetching progress data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching progress data: $e')),
      );
    }

    return progressData;
  }

  void _calculateMarksAndBadges() {
    int marks = 0;
    List<String> badges = [];

    final alphabetData = _castToMapStringDynamic(progressData['alphabet']);
    alphabetData.forEach((letter, progress) {
      int detections = (progress['totalDetections'] as num?)?.toInt() ?? 0;
      marks += detections * 5;
    });

    final handwritingData =
        _castToMapStringDynamic(progressData['handwriting']);
    handwritingData.forEach((letter, progress) {
      int detections = (progress['successfulAttempts'] as num?)?.toInt() ?? 0;
      marks += detections * 5;
    });

    final matWordData =
        _castToMapStringDynamic(progressData['matWordFormation']);
    matWordData.forEach((word, progress) {
      int successes = (progress['successfulAttempts'] as num?)?.toInt() ?? 0;
      marks += successes * 5;
    });

    final handwritingWordData =
        _castToMapStringDynamic(progressData['handwritingWordFormation']);
    handwritingWordData.forEach((word, progress) {
      int successes = (progress['successfulAttempts'] as num?)?.toInt() ?? 0;
      marks += successes * 5;
    });

    totalMarks = marks;

    if (marks >= 50) badges.add("Beginner Badge 🎓");
    if (marks >= 100) badges.add("Advanced Badge 🏅");
    if (marks >= 200) badges.add("Expert Badge 🏆");
    if (marks >= 500) badges.add("Master Badge 👑");

    setState(() {
      unlockedBadges = badges;
    });
  }

  Map<String, double> calculateModuleEngagement() {
    int totalInteractions = 0;
    Map<String, int> moduleInteractions = {
      'alphabet': 0,
      'handwriting': 0,
      'matWordFormation': 0,
      'handwritingWordFormation': 0,
    };

    progressData.forEach((key, data) {
      final moduleData = _castToMapStringDynamic(data);
      moduleData.forEach((item, value) {
        final itemData = _castToMapStringDynamic(value);
        int count = (itemData['totalDetections'] as num?)?.toInt() ??
            (itemData['successfulAttempts'] as num?)?.toInt() ??
            (itemData['attempts'] as num?)?.toInt() ??
            0;
        moduleInteractions[key] = (moduleInteractions[key] ?? 0) + count;
        totalInteractions += count;
      });
    });

    Map<String, double> engagementPercentages = {};
    moduleInteractions.forEach((key, value) {
      engagementPercentages[key] =
          totalInteractions == 0 ? 0.0 : (value / totalInteractions) * 100;
    });
    return engagementPercentages;
  }

  List<String> identifyAtRiskItems(
      Map<String, dynamic> progress, int threshold) {
    List<String> atRisk = [];
    progress.forEach((item, data) {
      final value = _castToMapStringDynamic(data);
      int count = (value['totalDetections'] as num?)?.toInt() ??
          (value['successfulAttempts'] as num?)?.toInt() ??
          (value['attempts'] as num?)?.toInt() ??
          0;
      if (count < threshold) {
        atRisk.add(item);
      }
    });
    return atRisk;
  }

  Future<Uint8List?> captureWidget(GlobalKey key) async {
    try {
      RenderRepaintBoundary? boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        print('Boundary is null for key: $key');
        return null;
      }
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        print('ByteData is null for key: $key');
        return null;
      }
      return byteData.buffer.asUint8List();
    } catch (e) {
      print('Error capturing widget: $e');
      return null;
    }
  }

  Future<void> captureAllCharts() async {
    await Future.delayed(Duration.zero);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      engagementChartImage = await captureWidget(engagementChartKey);
      alphabetChartImage = await captureWidget(alphabetChartKey);
      handwritingChartImage = await captureWidget(handwritingChartKey);
      alphabetHeatmapImage = await captureWidget(alphabetHeatmapKey);
      handwritingHeatmapImage = await captureWidget(handwritingHeatmapKey);
      print('Captured images: '
          'engagement: ${engagementChartImage != null}, '
          'alphabet: ${alphabetChartImage != null}, '
          'handwriting: ${handwritingChartImage != null}, '
          'alphabetHeatmap: ${alphabetHeatmapImage != null}, '
          'handwritingHeatmap: ${handwritingHeatmapImage != null}');
    });
  }

  Future<Uint8List> _generatePdf() async {
    await captureAllCharts();
    await Future.delayed(const Duration(milliseconds: 200));

    final pdf = pw.Document();
    final font = await PdfGoogleFonts.balsamiqSansBold();
    final regularFont = await PdfGoogleFonts.balsamiqSansRegular();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              'Kid Learning Report',
              style: pw.TextStyle(
                  font: font, fontSize: 28, color: PdfColors.black),
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'For ${selectedKidEmail ?? "Kid"}',
              style: pw.TextStyle(
                  font: regularFont, fontSize: 20, color: PdfColors.black),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Generated on: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
              style: pw.TextStyle(
                  font: regularFont, fontSize: 14, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Happy Learning!',
              style: pw.TextStyle(
                  font: font, fontSize: 18, color: PdfColors.black),
            ),
          ],
        ),
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.all(8),
          color: const PdfColor.fromInt(0xFFFFEE82),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Kid Learning Report',
                style: pw.TextStyle(
                    font: font, fontSize: 16, color: PdfColors.black),
              ),
              pw.Text(
                'Page ${context.pageNumber}',
                style: pw.TextStyle(
                    font: regularFont, fontSize: 12, color: PdfColors.black),
              ),
            ],
          ),
        ),
        build: (pw.Context context) => [
          pw.SizedBox(height: 16),
          _buildPdfSectionTitle('Progress Summary', font),
          _buildPdfProgressSummarySection(regularFont),
          pw.NewPage(),
          pw.SizedBox(height: 16),
          _buildPdfSectionTitle('Alphabet Learning', font),
          _buildPdfAlphabetSection(regularFont),
          pw.NewPage(),
          pw.SizedBox(height: 16),
          _buildPdfSectionTitle('Handwriting Practice', font),
          _buildPdfHandwritingSection(regularFont),
          pw.NewPage(),
          pw.SizedBox(height: 16),
          _buildPdfSectionTitle('Word Formation', font),
          _buildPdfWordFormationSection(regularFont),
          pw.NewPage(),
          pw.SizedBox(height: 16),
          _buildPdfSectionTitle('Recommendations', font),
          _buildPdfRecommendationsSection(regularFont),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPdfSectionTitle(String title, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFFFEE82),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(font: font, fontSize: 16, color: PdfColors.black),
      ),
    );
  }

  pw.Widget _buildPdfProgressSummarySection(pw.Font font) {
    final engagement = calculateModuleEngagement();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Total Marks: $totalMarks',
          style: pw.TextStyle(
              font: font, fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 1),
          columnWidths: {
            0: const pw.FlexColumnWidth(),
            1: const pw.FixedColumnWidth(100),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Module',
                      style: pw.TextStyle(
                          font: font,
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Engagement (%)',
                      style: pw.TextStyle(
                          font: font,
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold)),
                ),
              ],
            ),
            ...engagement.entries.map((entry) => pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(entry.key,
                          style: pw.TextStyle(font: font, fontSize: 12)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('${entry.value.toStringAsFixed(1)}%',
                          style: pw.TextStyle(font: font, fontSize: 12)),
                    ),
                  ],
                )),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPdfAlphabetSection(pw.Font font) {
    final alphabetData = _castToMapStringDynamic(progressData['alphabet']);
    if (alphabetData.isEmpty) {
      return pw.Text(
        'No progress recorded yet.',
        style: pw.TextStyle(font: font, fontSize: 12),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Alphabets Learned: ${alphabetData.length}/26',
          style: pw.TextStyle(
              font: font, fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 1),
          columnWidths: {
            0: const pw.FixedColumnWidth(50),
            1: const pw.FixedColumnWidth(100),
            2: const pw.FlexColumnWidth(),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Letter',
                      style: pw.TextStyle(
                          font: font,
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Attempts',
                      style: pw.TextStyle(
                          font: font,
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Last Practiced',
                      style: pw.TextStyle(
                          font: font,
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold)),
                ),
              ],
            ),
            ...alphabetData.entries.map<pw.TableRow>((entry) {
              final value = _castToMapStringDynamic(entry.value);
              int attempts = (value['totalDetections'] as num?)?.toInt() ?? 0;
              String lastPracticed = value['lastDetected'] is Timestamp
                  ? DateFormat('yyyy-MM-dd')
                      .format(value['lastDetected'].toDate())
                  : 'N/A';
              return pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(entry.key,
                        style: pw.TextStyle(font: font, fontSize: 12)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('${attempts}x',
                        style: pw.TextStyle(font: font, fontSize: 12)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(lastPracticed,
                        style: pw.TextStyle(font: font, fontSize: 12)),
                  ),
                ],
              );
            }).toList(),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPdfHandwritingSection(pw.Font font) {
    final handwritingData =
        _castToMapStringDynamic(progressData['handwriting']);
    if (handwritingData.isEmpty) {
      return pw.Text(
        'No progress recorded yet.',
        style: pw.TextStyle(font: font, fontSize: 12),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Alphabets Practiced: ${handwritingData.length}/26',
          style: pw.TextStyle(
              font: font, fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 1),
          columnWidths: {
            0: const pw.FixedColumnWidth(50),
            1: const pw.FixedColumnWidth(100),
            2: const pw.FlexColumnWidth(),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Letter',
                      style: pw.TextStyle(
                          font: font,
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Attempts',
                      style: pw.TextStyle(
                          font: font,
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Last Practiced',
                      style: pw.TextStyle(
                          font: font,
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold)),
                ),
              ],
            ),
            ...handwritingData.entries.map<pw.TableRow>((entry) {
              final value = _castToMapStringDynamic(entry.value);
              int attempts = (value['successfulAttempts'] as num?)?.toInt() ?? 0;
              String lastPracticed = value['lastDetected'] is Timestamp
                  ? DateFormat('yyyy-MM-dd')
                      .format(value['lastDetected'].toDate())
                  : 'N/A';
              return pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(entry.key,
                        style: pw.TextStyle(font: font, fontSize: 12)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('${attempts}x',
                        style: pw.TextStyle(font: font, fontSize: 12)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(lastPracticed,
                        style: pw.TextStyle(font: font, fontSize: 12)),
                  ),
                ],
              );
            }).toList(),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPdfWordFormationSection(pw.Font font) {
    final matData = _castToMapStringDynamic(progressData['matWordFormation']);
    final handwritingData =
        _castToMapStringDynamic(progressData['handwritingWordFormation']);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Camera Word Formation',
          style: pw.TextStyle(
              font: font, fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        _buildPdfWordFormationTable(matData, font, 'Camera'),
        pw.SizedBox(height: 16),
        pw.Text(
          'Handwritten Word Formation',
          style: pw.TextStyle(
              font: font, fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        _buildPdfWordFormationTable(handwritingData, font, 'Handwriting'),
      ],
    );
  }

  pw.Widget _buildPdfWordFormationTable(
      Map<String, dynamic> data, pw.Font font, String type) {
    if (data.isEmpty) {
      return pw.Text(
        'No $type word formation progress recorded yet.',
        style: pw.TextStyle(font: font, fontSize: 12),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Words Formed: ${data.length}',
          style: pw.TextStyle(
              font: font, fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 1),
          columnWidths: {
            0: const pw.FixedColumnWidth(100),
            1: const pw.FixedColumnWidth(100),
            2: const pw.FlexColumnWidth(),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Word',
                      style: pw.TextStyle(
                          font: font,
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Successes',
                      style: pw.TextStyle(
                          font: font,
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Last Practiced',
                      style: pw.TextStyle(
                          font: font,
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold)),
                ),
              ],
            ),
            ...data.entries.map<pw.TableRow>((entry) {
              final value = _castToMapStringDynamic(entry.value);
              int successfulAttempts =
                  (value['successfulAttempts'] as num?)?.toInt() ?? 0;
              String lastPracticed = value['lastDetected'] is Timestamp
                  ? DateFormat('yyyy-MM-dd')
                      .format(value['lastDetected'].toDate())
                  : 'N/A';
              return pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(entry.key,
                        style: pw.TextStyle(font: font, fontSize: 12)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('${successfulAttempts}x',
                        style: pw.TextStyle(font: font, fontSize: 12)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(lastPracticed,
                        style: pw.TextStyle(font: font, fontSize: 12)),
                  ),
                ],
              );
            }).toList(),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPdfRecommendationsSection(pw.Font font) {
    List<String> recommendations = [];
    final now = DateTime.now();
    const daysThreshold = 7; // Items not practiced in 7 days are stale

    // Alphabet Learning: Unattempted, Low Frequency, Stale
    final alphabetData = _castToMapStringDynamic(progressData['alphabet']);
    final unattemptedLetters = List.generate(26, (i) => String.fromCharCode(65 + i))
        .where((letter) => !alphabetData.containsKey(letter))
        .take(3)
        .toList();
    if (unattemptedLetters.isNotEmpty) {
      recommendations.add(
        "Practice new letters ${unattemptedLetters.join(', ')} in Scan & Learn.",
      );
    }
    final lowFreqLetters = alphabetData.entries
        .where((entry) => ((entry.value['totalDetections'] as num?)?.toInt() ?? 0) < 3)
        .map((entry) => entry.key)
        .take(3)
        .toList();
    if (lowFreqLetters.isNotEmpty) {
      recommendations.add(
        "Practice letters ${lowFreqLetters.join(', ')} more in Scan & Learn.",
      );
    }
    final staleLetters = alphabetData.entries
        .where((entry) {
      final lastDetected = entry.value['lastDetected'];
      if (lastDetected is! Timestamp) return false;
      final daysSince = now.difference(lastDetected.toDate()).inDays;
      return daysSince >= daysThreshold;
    })
        .map((entry) => entry.key)
        .take(3)
        .toList();
    if (staleLetters.isNotEmpty) {
      recommendations.add(
        "Practice letters ${staleLetters.join(', ')} again in Scan & Learn.",
      );
    }

    // Handwriting: Unattempted, Low Frequency, Stale
    final handwritingData = _castToMapStringDynamic(progressData['handwriting']);
    final unattemptedHandwriting = List.generate(26, (i) => String.fromCharCode(65 + i))
        .where((letter) => !handwritingData.containsKey(letter))
        .take(3)
        .toList();
    if (unattemptedHandwriting.isNotEmpty) {
      recommendations.add(
        "Practice new letters ${unattemptedHandwriting.join(', ')} in Write & Learn.",
      );
    }
    final lowFreqHandwriting = handwritingData.entries
        .where((entry) => ((entry.value['successfulAttempts'] as num?)?.toInt() ?? 0) < 3)
        .map((entry) => entry.key)
        .take(3)
        .toList();
    if (lowFreqHandwriting.isNotEmpty) {
      recommendations.add(
        "Practice letters ${lowFreqHandwriting.join(', ')} more in Write & Learn.",
      );
    }
    final staleHandwriting = handwritingData.entries
        .where((entry) {
      final lastDetected = entry.value['lastDetected'];
      if (lastDetected is! Timestamp) return false;
      final daysSince = now.difference(lastDetected.toDate()).inDays;
      return daysSince >= daysThreshold;
    })
        .map((entry) => entry.key)
        .take(3)
        .toList();
    if (staleHandwriting.isNotEmpty) {
      recommendations.add(
        "Practice letters ${staleHandwriting.join(', ')} again in Write & Learn.",
      );
    }

    // Fallback if no recommendations
    if (recommendations.isEmpty) {
      recommendations.add(
        "Practice new letters in Scan & Learn or Write & Learn.",
      );
    }

    // Limit to 5 recommendations
    recommendations = recommendations.take(5).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Suggestions for Caregivers:',
          style: pw.TextStyle(
              font: font, fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        ...recommendations.map(
              (rec) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Text(
              rec,
              style: pw.TextStyle(font: font, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Future<int> getAndroidSdkVersion() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    return androidInfo.version.sdkInt;
  }

  Future<void> _savePdfToDevice() async {
    try {
      setState(() => _isLoading = true);
      final pdfBytes = await _generatePdf();

      bool permissionGranted = false;
      if (Platform.isAndroid) {
        int sdkInt = await getAndroidSdkVersion();
        if (sdkInt >= 30) {
          permissionGranted =
              await Permission.manageExternalStorage.request().isGranted;
          if (!permissionGranted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content:
                      Text('Please allow "All files access" in app settings')),
            );
            await openAppSettings();
            return;
          }
        } else {
          permissionGranted = await Permission.storage.request().isGranted;
          if (!permissionGranted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Storage permission denied')),
            );
            return;
          }
        }
      } else {
        permissionGranted = true;
      }

      if (!permissionGranted) return;

      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to access storage directory')),
        );
        return;
      }

      final timeStamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/kid_report_$timeStamp.pdf';
      final file = File(filePath);

      await file.writeAsBytes(pdfBytes);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF saved to: $filePath')),
      );
    } catch (e) {
      print('Error saving PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving PDF: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFADD),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFEE82),
        elevation: 0,
        title: Text(
          'Kid Progress Report',
          style: GoogleFonts.balsamiqSans(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _loadSelectedKidAndProgress,
            tooltip: 'Refresh Progress',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
          child: _isLoading
              ? Center(
                  child:
                      CircularProgressIndicator(color: const Color(0xFFFFEE82)))
              : selectedKidId == null
                  ? Center(
                      child: Text(
                        'No kid selected. Please select a kid first.',
                        style: GoogleFonts.balsamiqSans(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildHeader(),
                                const SizedBox(height: 20),
                                _buildProgressSummary(),
                                const SizedBox(height: 20),
                                _isDataEmpty()
                                    ? _buildNoDataMessage()
                                    : Column(
                                        children: [
                                          _buildExpandableSection(
                                            title: "Scan & Learn",
                                            isExpanded: _isScanLearnExpanded,
                                            onToggle: () {
                                              setState(() {
                                                _isScanLearnExpanded =
                                                    !_isScanLearnExpanded;
                                              });
                                            },
                                            children: [
                                              _buildSectionTitle(
                                                  "Scan to Learn Alphabets"),
                                              _buildAlphabetReport(),
                                              const SizedBox(height: 20),
                                              _buildSectionTitle(
                                                  "Alphabet Practice Heatmap"),
                                              _buildAlphabetHeatmap(),
                                              const SizedBox(height: 20),
                                              _buildSectionTitle(
                                                  "Scan to Form a Word"),
                                              _buildSingleWordFormationCard(
                                                  _castToMapStringDynamic(
                                                      progressData[
                                                          'matWordFormation']),
                                                  'Camera Word Formation'),
                                            ],
                                          ),
                                          const SizedBox(height: 20),
                                          _buildExpandableSection(
                                            title: "Write & Learn",
                                            isExpanded: _isWriteLearnExpanded,
                                            onToggle: () {
                                              setState(() {
                                                _isWriteLearnExpanded =
                                                    !_isWriteLearnExpanded;
                                              });
                                            },
                                            children: [
                                              _buildSectionTitle(
                                                  "Write to Learn Alphabets"),
                                              _buildHandwritingReport(),
                                              const SizedBox(height: 20),
                                              _buildSectionTitle(
                                                  "Handwriting Practice Heatmap"),
                                              _buildHandwritingHeatmap(),
                                              const SizedBox(height: 20),
                                              _buildSectionTitle(
                                                  "Write to Form a Word"),
                                              _buildSingleWordFormationCard(
                                                  _castToMapStringDynamic(
                                                      progressData[
                                                          'handwritingWordFormation']),
                                                  'Handwritten Word Formation'),
                                            ],
                                          ),
                                          const SizedBox(height: 20),
                                          _buildSectionTitle("Recommendations"),
                                          _buildRecommendations(),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _savePdfToDevice,
        backgroundColor: const Color(0xFFFFEE82),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.black)
            : const Icon(Icons.download, color: Colors.black),
        tooltip: 'Download PDF Report',
      ),
    );
  }

  bool _isDataEmpty() {
    if (progressData.isEmpty) return true;
    return progressData.values
        .every((value) => _castToMapStringDynamic(value).isEmpty);
  }

  Widget _buildHeader() {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Progress Report for ${selectedKidEmail ?? "Kid"}',
            style: GoogleFonts.balsamiqSans(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
            style: GoogleFonts.balsamiqSans(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSummary() {
    final engagement = calculateModuleEngagement();
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
          _buildInfoTile(
              Icons.trending_up, 'Total Marks', totalMarks.toString()),
          const Divider(),
          const SizedBox(height: 15),
          RepaintBoundary(
            key: engagementChartKey,
            child: _buildEngagementPieChart(),
          ),
          const SizedBox(height: 15),
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
      subtitle: value.isNotEmpty
          ? Text(
              value,
              style: GoogleFonts.balsamiqSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            )
          : null,
    );
  }

  Widget _buildEngagementPieChart() {
    final engagement = calculateModuleEngagement();
    List<PieChartSectionData> sections = [
      PieChartSectionData(
        value: engagement['alphabet'] ?? 0.0,
        title: 'Scan Alphabet',
        color: const Color(0xFFFFEE82),
        radius: 100,
        titleStyle: GoogleFonts.balsamiqSans(fontSize: 14, color: Colors.black),
      ),
      PieChartSectionData(
        value: engagement['handwriting'] ?? 0.0,
        title: 'Write Alphabet',
        color: const Color(0xFFFFD700),
        radius: 100,
        titleStyle: GoogleFonts.balsamiqSans(fontSize: 14, color: Colors.black),
      ),
      PieChartSectionData(
        value: engagement['matWordFormation'] ?? 0.0,
        title: 'Scan Word',
        color: const Color(0xFFFFB6C1),
        radius: 100,
        titleStyle: GoogleFonts.balsamiqSans(fontSize: 14, color: Colors.black),
      ),
      PieChartSectionData(
        value: engagement['handwritingWordFormation'] ?? 0.0,
        title: 'Write Word',
        color: const Color(0xFFADD8E6),
        radius: 100,
        titleStyle: GoogleFonts.balsamiqSans(fontSize: 14, color: Colors.black),
      ),
    ].where((section) => section.value > 0).toList();

    return Container(
      height: 250,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: sections.isEmpty
          ? Center(
              child: Text(
                'No engagement data available.',
                style: GoogleFonts.balsamiqSans(
                    fontSize: 16, color: Colors.grey[600]),
              ),
            )
          : PieChart(
              PieChartData(
                sections: sections,
                sectionsSpace: 2,
                centerSpaceRadius: 40,
              ),
            ),
    );
  }

  Widget _buildAlphabetHeatmap() {
    final alphabetData = _castToMapStringDynamic(progressData['alphabet']);
    if (alphabetData.isEmpty) {
      return Center(
        child: Text(
          'No alphabet practice data available.',
          style:
              GoogleFonts.balsamiqSans(fontSize: 16, color: Colors.grey[600]),
        ),
      );
    }

    double maxAttempts = alphabetData.values
            .map((e) => (e['totalDetections'] as num?)?.toDouble() ?? 0.0)
            .reduce((a, b) => a > b ? a : b) +
        1.0;

    return RepaintBoundary(
      key: alphabetHeatmapKey,
      child: Container(
        width: double.infinity,
        height: 250,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 400,
            maxHeight: 250,
          ),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: 26,
            itemBuilder: (context, index) {
              String letter = String.fromCharCode(65 + index);
              double attempts =
                  (alphabetData[letter]?['totalDetections'] as num?)
                          ?.toDouble() ??
                      0.0;
              double intensity = attempts / maxAttempts;
              return Container(
                decoration: BoxDecoration(
                  color: Color.lerp(Colors.grey[200], const Color(0xFFFFEE82),
                      intensity.clamp(0.0, 1.0)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    letter,
                    style: GoogleFonts.balsamiqSans(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHandwritingHeatmap() {
    final handwritingData =
        _castToMapStringDynamic(progressData['handwriting']);
    if (handwritingData.isEmpty) {
      return Center(
        child: Text(
          'No handwriting practice data available.',
          style:
              GoogleFonts.balsamiqSans(fontSize: 16, color: Colors.grey[600]),
        ),
      );
    }

    double maxAttempts = handwritingData.values
            .map((e) => (e['successfulAttempts'] as num?)?.toDouble() ?? 0.0)
            .reduce((a, b) => a > b ? a : b) +
        1.0;

    return RepaintBoundary(
      key: handwritingHeatmapKey,
      child: Container(
        width: double.infinity,
        height: 250,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 400,
            maxHeight: 250,
          ),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: 26,
            itemBuilder: (context, index) {
              String letter = String.fromCharCode(65 + index);
              double attempts =
                  (handwritingData[letter]?['successfulAttempts'] as num?)
                          ?.toDouble() ??
                      0.0;
              double intensity = attempts / maxAttempts;
              return Container(
                decoration: BoxDecoration(
                  color: Color.lerp(Colors.grey[200], const Color(0xFFFFEE82),
                      intensity.clamp(0.0, 1.0)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    letter,
                    style: GoogleFonts.balsamiqSans(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
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
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
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

  Widget _buildAlphabetReport() {
    final alphabetData = _castToMapStringDynamic(progressData['alphabet']);
    if (alphabetData.isEmpty) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Alphabets Learned: ${alphabetData.length}/26',
            style: GoogleFonts.balsamiqSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          RepaintBoundary(
            key: alphabetChartKey,
            child: _buildAlphabetChart(),
          ),
          const SizedBox(height: 8),
          ...alphabetData.entries.map<Widget>((entry) {
            final value = _castToMapStringDynamic(entry.value);
            int attempts = (value['totalDetections'] as num?)?.toInt() ?? 0;
            String lastPracticed = value['lastDetected'] is Timestamp
                ? DateFormat('yyyy-MM-dd')
                    .format(value['lastDetected'].toDate())
                : 'N/A';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${entry.key}: ${attempts}x',
                      style: GoogleFonts.balsamiqSans(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Text(
                    'Last: $lastPracticed',
                    style: GoogleFonts.balsamiqSans(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildAlphabetChart() {
    final alphabetData = _castToMapStringDynamic(progressData['alphabet']);
    List<BarChartGroupData> barGroups =
        alphabetData.entries.map<BarChartGroupData>((entry) {
      double attempts =
          (entry.value['totalDetections'] as num?)?.toDouble() ?? 0.0;
      return BarChartGroupData(
        x: entry.key.codeUnitAt(0) - 65,
        barRods: [
          BarChartRodData(
            toY: attempts,
            gradient: const LinearGradient(
              colors: [Color(0xFFFFEE82), Color(0xFFFFD700)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            width: 12,
            borderRadius: BorderRadius.circular(6),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: max(
                      alphabetData.values
                          .map((e) =>
                              (e['totalDetections'] as num?)?.toDouble() ?? 0.0)
                          .reduce((a, b) => a > b ? a : b),
                      5) +
                  2,
              color: Colors.grey.withOpacity(0.1),
            ),
          ),
        ],
      );
    }).toList();

    double maxY = alphabetData.isNotEmpty
        ? max(
                alphabetData.values
                    .map((e) =>
                        (e['totalDetections'] as num?)?.toDouble() ?? 0.0)
                    .reduce((a, b) => a > b ? a : b),
                5) +
            2
        : 7;

    return Container(
      height: 250,
      width: double.infinity,
      child: BarChart(
        BarChartData(
          barGroups: barGroups,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => Colors.black87.withOpacity(0.8),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final letter = String.fromCharCode(group.x + 65);
                return BarTooltipItem(
                  '$letter\n${rod.toY.toInt()} times',
                  GoogleFonts.balsamiqSans(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final letter = String.fromCharCode(value.toInt() + 65);
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      letter,
                      style: GoogleFonts.balsamiqSans(
                        fontSize: 12,
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
                reservedSize: 38,
                interval: 1,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  if (value % 1 != 0) return const SizedBox();
                  return Text(
                    value.toInt().toString(),
                    style: GoogleFonts.balsamiqSans(
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                  );
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
          ),
          maxY: maxY,
          minY: 0,
        ),
      ),
    );
  }

  Widget _buildHandwritingReport() {
    final handwritingData =
        _castToMapStringDynamic(progressData['handwriting']);
    if (handwritingData.isEmpty) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Alphabets Practiced: ${handwritingData.length}/26',
            style: GoogleFonts.balsamiqSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          RepaintBoundary(
            key: handwritingChartKey,
            child: _buildHandwritingChart(),
          ),
          const SizedBox(height: 8),
          ...handwritingData.entries.map<Widget>((entry) {
            final value = _castToMapStringDynamic(entry.value);
            int attempts = (value['totalDetections'] as num?)?.toInt() ?? 0;
            String lastPracticed = value['lastDetected'] is Timestamp
                ? DateFormat('yyyy-MM-dd')
                    .format(value['lastDetected'].toDate())
                : 'N/A';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${entry.key}: ${attempts}x',
                      style: GoogleFonts.balsamiqSans(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Text(
                    'Last: $lastPracticed',
                    style: GoogleFonts.balsamiqSans(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildHandwritingChart() {
    final handwritingData =
        _castToMapStringDynamic(progressData['handwriting']);
    List<BarChartGroupData> barGroups =
        handwritingData.entries.map<BarChartGroupData>((entry) {
      double attempts =
          (entry.value['successfulAttempts'] as num?)?.toDouble() ?? 0.0;
      return BarChartGroupData(
        x: entry.key.codeUnitAt(0) - 65,
        barRods: [
          BarChartRodData(
            toY: attempts,
            gradient: const LinearGradient(
              colors: [Color(0xFFFFEE82), Color(0xFFFFD700)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            width: 12,
            borderRadius: BorderRadius.circular(6),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: max(
                      handwritingData.values
                          .map((e) =>
                              (e['successfulAttempts'] as num?)?.toDouble() ?? 0.0)
                          .reduce((a, b) => a > b ? a : b),
                      5) +
                  2,
              color: Colors.grey.withOpacity(0.1),
            ),
          ),
        ],
      );
    }).toList();

    double maxY = handwritingData.isNotEmpty
        ? max(
                handwritingData.values
                    .map((e) =>
                        (e['successfulAttempts'] as num?)?.toDouble() ?? 0.0)
                    .reduce((a, b) => a > b ? a : b),
                5) +
            2
        : 7;

    return Container(
      height: 250,
      width: double.infinity,
      child: BarChart(
        BarChartData(
          barGroups: barGroups,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => Colors.black87.withOpacity(0.8),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final letter = String.fromCharCode(group.x + 65);
                return BarTooltipItem(
                  '$letter\n${rod.toY.toInt()} times',
                  GoogleFonts.balsamiqSans(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final letter = String.fromCharCode(value.toInt() + 65);
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      letter,
                      style: GoogleFonts.balsamiqSans(
                        fontSize: 12,
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
                reservedSize: 38,
                interval: 1,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  if (value % 1 != 0) return const SizedBox();
                  return Text(
                    value.toInt().toString(),
                    style: GoogleFonts.balsamiqSans(
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                  );
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
          ),
          maxY: maxY,
          minY: 0,
        ),
      ),
    );
  }

  Widget _buildSingleWordFormationCard(Map<String, dynamic> data, String type) {
    final wordData = data;
    if (wordData.isEmpty) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Words Formed: ${wordData.length}',
            style: GoogleFonts.balsamiqSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          ...wordData.entries.map<Widget>((entry) {
            final value = _castToMapStringDynamic(entry.value);
            int successfulAttempts =
                (value['successfulAttempts'] as num?)?.toInt() ?? 0;
            String lastPracticed = value['lastDetected'] is Timestamp
                ? DateFormat('yyyy-MM-dd')
                    .format(value['lastDetected'].toDate())
                : 'N/A';
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
                "Successful Attempts: ${successfulAttempts}x\nLast: $lastPracticed",
                style: GoogleFonts.balsamiqSans(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildRecommendations() {
    List<String> recommendations = [];
    final now = DateTime.now();
    const daysThreshold = 7; // Items not practiced in 7 days are stale

    // Alphabet Learning: Unattempted, Low Frequency, Stale
    final alphabetData = _castToMapStringDynamic(progressData['alphabet']);
    final unattemptedLetters =
        List.generate(26, (i) => String.fromCharCode(65 + i))
            .where((letter) => !alphabetData.containsKey(letter))
            .take(3)
            .toList();
    if (unattemptedLetters.isNotEmpty) {
      recommendations.add(
        "Practice new letters ${unattemptedLetters.join(', ')} in Scan & Learn.",
      );
    }
    final lowFreqLetters = alphabetData.entries
        .where((entry) =>
            ((entry.value['totalDetections'] as num?)?.toInt() ?? 0) < 3)
        .map((entry) => entry.key)
        .take(3)
        .toList();
    if (lowFreqLetters.isNotEmpty) {
      recommendations.add(
        "Practice letters ${lowFreqLetters.join(', ')} more in Scan & Learn.",
      );
    }
    final staleLetters = alphabetData.entries
        .where((entry) {
          final lastDetected = entry.value['lastDetected'];
          if (lastDetected is! Timestamp) return false;
          final daysSince = now.difference(lastDetected.toDate()).inDays;
          return daysSince >= daysThreshold;
        })
        .map((entry) => entry.key)
        .take(3)
        .toList();
    if (staleLetters.isNotEmpty) {
      recommendations.add(
        "Practice letters ${staleLetters.join(', ')} again in Scan & Learn.",
      );
    }

    // Handwriting: Unattempted, Low Frequency, Stale
    final handwritingData =
        _castToMapStringDynamic(progressData['handwriting']);
    final unattemptedHandwriting =
        List.generate(26, (i) => String.fromCharCode(65 + i))
            .where((letter) => !handwritingData.containsKey(letter))
            .take(3)
            .toList();
    if (unattemptedHandwriting.isNotEmpty) {
      recommendations.add(
        "Practice new letters ${unattemptedHandwriting.join(', ')} in Write & Learn.",
      );
    }
    final lowFreqHandwriting = handwritingData.entries
        .where((entry) =>
            ((entry.value['successfulAttempts'] as num?)?.toInt() ?? 0) < 3)
        .map((entry) => entry.key)
        .take(3)
        .toList();
    if (lowFreqHandwriting.isNotEmpty) {
      recommendations.add(
        "Practice letters ${lowFreqHandwriting.join(', ')} more in Write & Learn.",
      );
    }
    final staleHandwriting = handwritingData.entries
        .where((entry) {
          final lastDetected = entry.value['lastDetected'];
          if (lastDetected is! Timestamp) return false;
          final daysSince = now.difference(lastDetected.toDate()).inDays;
          return daysSince >= daysThreshold;
        })
        .map((entry) => entry.key)
        .take(3)
        .toList();
    if (staleHandwriting.isNotEmpty) {
      recommendations.add(
        "Practice letters ${staleHandwriting.join(', ')} again in Write & Learn.",
      );
    }

    // Fallback if no recommendations
    if (recommendations.isEmpty) {
      recommendations.add(
        "Practice new letters in Scan & Learn or Write & Learn.",
      );
    }

    // Limit to 5 recommendations
    recommendations = recommendations.take(5).toList();

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Suggestions for Caregivers:',
            style: GoogleFonts.balsamiqSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          ...recommendations.map(
            (recommendation) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.star, color: Colors.black, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      recommendation,
                      style: GoogleFonts.balsamiqSans(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
