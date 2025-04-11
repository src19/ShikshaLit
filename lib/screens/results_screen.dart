import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/string_extensions.dart';

class ResultsScreen extends StatefulWidget {
  @override
  _ResultsScreenState createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  late SharedPreferences prefs;
  Map<String, int> scores = {};
  List<double> sentencePercentages = [];

  @override
  void initState() {
    super.initState();
    _loadScores();
  }

  Future<void> _loadScores() async {
    prefs = await SharedPreferences.getInstance();
    setState(() {
      scores['alphabets'] = prefs.getInt('alphabets-correct') ?? 0;
      scores['words'] = prefs.getInt('words-correct') ?? 0;
      scores['sentences'] = prefs.getInt('sentences-correct') ?? 0;
      String? percentagesJson = prefs.getString('sentences-percentages');
      if (percentagesJson != null) {
        sentencePercentages = List<double>.from(jsonDecode(percentagesJson));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Results')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Your Scores', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            ...scores.entries.map((entry) => ListTile(
                  title: Text('${entry.key.capitalize()}'),
                  trailing: Text('${entry.value}/5'),
                )),
            if (sentencePercentages.isNotEmpty) ...[
              SizedBox(height: 20),
              Text('Sentence Match Percentages', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ...sentencePercentages.asMap().entries.map((entry) => ListTile(
                    title: Text('Q${entry.key + 1}'),
                    trailing: Text('${entry.value.toStringAsFixed(1)}%'),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}