import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/string_extensions.dart';
import 'package:fl_chart/fl_chart.dart';

class ResultsScreen extends StatefulWidget {
  @override
  _ResultsScreenState createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  late SharedPreferences prefs;
  Map<String, int> scores = {};
  Map<String, int> totalQuestions = {};
  List<double> sentencePercentages = [];
  List<int> listeningDetails = [];
  bool isLoading = true;
  
  final Map<String, IconData> sectionIcons = {
    'alphabets': Icons.sort_by_alpha,
    'words': Icons.text_fields,
    'sentences': Icons.short_text,
    'comprehension': Icons.hearing,
  };
  
  final Map<String, Color> sectionColors = {
    'alphabets': Colors.blue,
    'words': Colors.green,
    'sentences': Colors.orange,
    'comprehension': Colors.purple,
  };

  @override
  void initState() {
    super.initState();
    _loadScores();
  }

  Future<void> _loadScores() async {
    prefs = await SharedPreferences.getInstance();
    
    // Define default total questions for each section
    Map<String, int> defaultTotals = {
      'alphabets': 5,
      'words': 5,
      'sentences': 5,
      'comprehension': prefs.getInt('comprehension-total') ?? 5,
    };
    
    setState(() {
      // Load all scores
      for (String section in ['alphabets', 'words', 'sentences', 'comprehension']) {
        scores[section] = prefs.getInt('$section-correct') ?? 0;
        totalQuestions[section] = defaultTotals[section]!;
      }
      
      // Load sentence percentages
      String? percentagesJson = prefs.getString('sentences-percentages');
      if (percentagesJson != null) {
        sentencePercentages = List<double>.from(
          jsonDecode(percentagesJson).map((x) => double.parse(x.toString()))
        );
      }
      
      // Load listening details if available
      String? listeningJson = prefs.getString('comprehension-details');
      if (listeningJson != null) {
        listeningDetails = List<int>.from(jsonDecode(listeningJson));
      }
      
      isLoading = false;
    });
  }

  String _getGradeLabel(double percentage) {
    if (percentage >= 90) return 'A';
    if (percentage >= 80) return 'B';
    if (percentage >= 70) return 'C';
    if (percentage >= 60) return 'D';
    return 'F';
  }

  Color _getScoreColor(double percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.amber;
    if (percentage >= 40) return Colors.orange;
    return Colors.redAccent;
  }

  String _getFeedback(double overallPercentage) {
    if (overallPercentage >= 90) {
      return 'Excellent! You have a strong grasp of literacy skills.';
    } else if (overallPercentage >= 75) {
      return 'Good work! You have solid literacy skills with some room for improvement.';
    } else if (overallPercentage >= 60) {
      return 'You\'re making progress! Keep practicing to strengthen your literacy skills.';
    } else {
      return 'You\'re just starting out. Regular practice will help you improve your literacy skills.';
    }
  }

  Widget _buildSummaryCard(BuildContext context) {
    if (scores.isEmpty) return SizedBox.shrink();
    
    int totalCorrect = scores.values.fold(0, (sum, score) => sum + score);
    int totalPossible = totalQuestions.values.fold(0, (sum, total) => sum + total);
    double overallPercentage = totalPossible > 0 ? (totalCorrect / totalPossible) * 100 : 0;
    String grade = _getGradeLabel(overallPercentage);
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.indigo.shade800,
              Colors.indigo.shade500,
            ],
          ),
        ),
        child: Column(
          children: [
            Text(
              'Overall Performance',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          height: 100,
                          width: 100,
                          child: CircularProgressIndicator(
                            value: overallPercentage / 100,
                            strokeWidth: 10,
                            backgroundColor: Colors.white.withOpacity(0.3),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _getScoreColor(overallPercentage),
                            ),
                          ),
                        ),
                        Column(
                          children: [
                            Text(
                              '${overallPercentage.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Score',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: _getScoreColor(overallPercentage),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          grade,
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Grade',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 20),
            Text(
              _getFeedback(overallPercentage),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Total Score: $totalCorrect out of $totalPossible',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreChart() {
    if (scores.isEmpty) return SizedBox.shrink();
    
    return Container(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceEvenly,
          maxY: 100,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  String text = '';
                  switch (value.toInt()) {
                    case 0: text = 'ABC'; break;
                    case 1: text = 'Words'; break;
                    case 2: text = 'Sentences'; break;
                    case 3: text = 'Listening'; break;
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      text,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  );
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value % 25 != 0) return SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Text(
                      '${value.toInt()}%',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 10,
                      ),
                    ),
                  );
                },
                reservedSize: 40,
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: [
            _buildBarGroup(0, 'alphabets'),
            _buildBarGroup(1, 'words'),
            _buildBarGroup(2, 'sentences'),
            _buildBarGroup(3, 'comprehension'),
          ],
          gridData: FlGridData(
            show: true,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey[300],
                strokeWidth: 1,
                dashArray: [5, 5],
              );
            },
          ),
        ),
      ),
    );
  }

  BarChartGroupData _buildBarGroup(int x, String section) {
    double percentage = 0;
    if (scores.containsKey(section) && totalQuestions.containsKey(section)) {
      percentage = totalQuestions[section]! > 0
          ? (scores[section]! / totalQuestions[section]!) * 100
          : 0;
    }
    
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: percentage,
          color: sectionColors[section] ?? Colors.blue,
          width: 25,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(6),
          ),
        ),
      ],
    );
  }

  Widget _buildScoreCard(String section) {
    if (!scores.containsKey(section) || !totalQuestions.containsKey(section)) {
      return SizedBox.shrink();
    }
    
    int score = scores[section]!;
    int total = totalQuestions[section]!;
    double percentage = total > 0 ? (score / total) * 100 : 0;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      sectionIcons[section] ?? Icons.check_circle,
                      color: sectionColors[section] ?? Colors.blue,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Text(
                      section.capitalize(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getScoreColor(percentage).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$score/$total',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getScoreColor(percentage),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percentage / 100,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getScoreColor(percentage),
                ),
                minHeight: 8,
              ),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${percentage.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getScoreColor(percentage),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSentenceDetails() {
    if (sentencePercentages.isEmpty) return SizedBox.shrink();
    
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.short_text, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Sentence Accuracy Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Divider(),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: sentencePercentages.length,
              itemBuilder: (context, index) {
                double percentage = sentencePercentages[index];
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _getScoreColor(percentage).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _getScoreColor(percentage),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text('Sentence ${index + 1}'),
                      Spacer(),
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getScoreColor(percentage),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListeningDetails() {
    if (listeningDetails.isEmpty) return SizedBox.shrink();
    
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.hearing, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  'Listening Comprehension Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Divider(),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: listeningDetails.length,
              itemBuilder: (context, index) {
                bool isCorrect = listeningDetails[index] == 1;
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isCorrect ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            isCorrect ? Icons.check : Icons.close,
                            color: isCorrect ? Colors.green : Colors.red,
                            size: 20,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text('Question ${index + 1}'),
                      Spacer(),
                      Text(
                        isCorrect ? 'Correct' : 'Incorrect',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isCorrect ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAreaChart() {
    List<double> percentages = [];
    for (String section in ['alphabets', 'words', 'sentences', 'comprehension']) {
      if (scores.containsKey(section) && totalQuestions.containsKey(section)) {
        double percentage = totalQuestions[section]! > 0
            ? (scores[section]! / totalQuestions[section]!) * 100
            : 0;
        percentages.add(percentage);
      } else {
        percentages.add(0);
      }
    }
    
    return Container(
      height: 180,
      padding: EdgeInsets.only(right: 16, top: 6),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  String text = '';
                  switch (value.toInt()) {
                    case 0: text = 'ABC'; break;
                    case 1: text = 'Words'; break;
                    case 2: text = 'Sentences'; break;
                    case 3: text = 'Listening'; break;
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      text,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 10,
                      ),
                    ),
                  );
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value % 25 != 0) return SizedBox();
                  return Text(
                    '${value.toInt()}%',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 10,
                    ),
                  );
                },
                reservedSize: 30,
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: 3,
          minY: 0,
          maxY: 100,
          lineBarsData: [
            LineChartBarData(
              spots: [
                FlSpot(0, percentages[0]),
                FlSpot(1, percentages[1]),
                FlSpot(2, percentages[2]),
                FlSpot(3, percentages[3]),
              ],
              isCurved: true,
              color: Colors.indigo,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => 
                  FlDotCirclePainter(
                    radius: 6,
                    color: Colors.white,
                    strokeWidth: 2,
                    strokeColor: Colors.indigo,
                  ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.indigo.withOpacity(0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Results')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Your Results'),
        backgroundColor: Colors.indigo,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.indigo, Colors.white],
            stops: [0.0, 0.3],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCard(context),
                SizedBox(height: 24),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Performance by Area',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16),
                        _buildAreaChart(),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'Performance Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                _buildScoreCard('alphabets'),
                _buildScoreCard('words'),
                _buildScoreCard('sentences'),
                _buildScoreCard('comprehension'),
                SizedBox(height: 16),
                _buildSentenceDetails(),
                _buildListeningDetails(),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Text(
                      'Return to Home',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    minimumSize: Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}