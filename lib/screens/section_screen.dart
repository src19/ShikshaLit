import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/string_extensions.dart';

class SectionScreen extends StatefulWidget {
  final String section;
  SectionScreen({required this.section});

  @override
  _SectionScreenState createState() => _SectionScreenState();
}

class _SectionScreenState extends State<SectionScreen> {
  late FlutterSoundRecorder _recorder;
  String? audioPath;
  bool isRecording = false;
  bool hasRecorded = false;
  List<String> items = [];
  List<String> questions = [];
  int currentQuestionIndex = 0;
  String displayText = '';
  String transcribedText = '';
  int correctCount = 0;
  List<double> sentencePercentages = [];

  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder();
    _initializeRecorder();
    _fetchItems();
  }

  Future<void> _initializeRecorder() async {
    await _recorder.openRecorder();
    await Permission.microphone.request();
  }

  Future<void> _fetchItems() async {
    final doc = await FirebaseFirestore.instance.collection('literacycheck').doc(widget.section).get();
    final data = doc.data();
    if (data != null && data['items'] is List) {
      setState(() {
        items = List<String>.from(data['items']);
        questions = (items..shuffle()).take(5).toList();
        displayText = questions[currentQuestionIndex];
      });
    }
  }

  Future<void> toggleRecording() async {
    if (!isRecording) {
      final dir = await getTemporaryDirectory();
      audioPath = '${dir.path}/recording.aac';
      await _recorder.startRecorder(toFile: audioPath);
      setState(() => isRecording = true);
    } else {
      await _recorder.stopRecorder();
      setState(() {
        isRecording = false;
        hasRecorded = true;
      });
      await _transcribeAudio();
    }
  }

  Future<void> _transcribeAudio() async {
    if (audioPath == null) return;

    final file = File(audioPath!);
    final url = Uri.parse('http://10.3.9.30:5000/transcribe');
    final request = http.MultipartRequest('POST', url)
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    try {
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      if (responseBody.trim().startsWith('{')) {
        final jsonResponse = jsonDecode(responseBody);
        setState(() {
          if (jsonResponse.containsKey('error')) {
            transcribedText = 'Error: ${jsonResponse['error']}';
          } else {
            transcribedText = jsonResponse['transcription'] ?? 'No transcription';
            if (widget.section == 'sentences') {
              double percentage = _calculateSentenceMatch(displayText, transcribedText);
              sentencePercentages.add(percentage);
            }
            if (transcribedText.trim().toLowerCase() == displayText.trim().toLowerCase()) {
              correctCount++;
            }
          }
        });
      } else {
        setState(() {
          transcribedText = 'Server error: Unexpected response';
        });
      }
    } catch (e) {
      setState(() {
        transcribedText = 'Error: $e';
      });
    }
  }

  double _calculateSentenceMatch(String expected, String actual) {
    int maxLength = expected.length > actual.length ? expected.length : actual.length;
    if (maxLength == 0) return 100.0;
    int distance = _levenshteinDistance(expected.toLowerCase(), actual.toLowerCase());
    double similarity = (1 - distance / maxLength) * 100;
    return similarity.clamp(0.0, 100.0);
  }

  int _levenshteinDistance(String s1, String s2) {
    List<List<int>> dp = List.generate(s1.length + 1, (_) => List<int>.filled(s2.length + 1, 0));
    for (int i = 0; i <= s1.length; i++) dp[i][0] = i;
    for (int j = 0; j <= s2.length; j++) dp[0][j] = j;

    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        int cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }
    return dp[s1.length][s2.length];
  }

  void _nextQuestion() {
    if (currentQuestionIndex < questions.length - 1) {
      setState(() {
        currentQuestionIndex++;
        displayText = questions[currentQuestionIndex];
        transcribedText = '';
        hasRecorded = false;
      });
    } else {
      _saveResultsAndReturn();
    }
  }

  Future<void> _saveResultsAndReturn() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${widget.section}-completed', true);
    await prefs.setInt('${widget.section}-correct', correctCount);
    if (widget.section == 'sentences') {
      await prefs.setString('${widget.section}-percentages', jsonEncode(sentencePercentages));
    }
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    super.dispose();
  }

  // Disable back button
  Future<bool> _onWillPop() async {
    return false; // Prevents popping back to HomeScreen
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop, // Intercept back button
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.section.capitalize()} Test'),
          automaticallyImplyLeading: false, // Remove back arrow
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Q${currentQuestionIndex + 1}: $displayText',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              if (!hasRecorded)
                ElevatedButton(
                  onPressed: toggleRecording,
                  child: Text(isRecording ? 'Stop Recording' : 'Start Recording'),
                ),
              SizedBox(height: 20),
              Text(
                transcribedText.isEmpty ? 'No transcription yet' : 'You said: $transcribedText',
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 20),
              if (transcribedText.isNotEmpty) ...[
                Text(
                  transcribedText.trim().toLowerCase() == displayText.trim().toLowerCase()
                      ? 'Correct!'
                      : 'Incorrect',
                  style: TextStyle(
                    fontSize: 18,
                    color: transcribedText.trim().toLowerCase() == displayText.trim().toLowerCase()
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
                if (widget.section == 'sentences')
                  Text(
                    'Match: ${sentencePercentages.length > currentQuestionIndex ? sentencePercentages[currentQuestionIndex].toStringAsFixed(1) : 'Calculating...'}%',
                    style: TextStyle(fontSize: 16),
                  ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _nextQuestion,
                  child: Text(currentQuestionIndex < questions.length - 1 ? 'Next' : 'Finish'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}