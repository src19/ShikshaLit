import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import '../utils/string_extensions.dart';

class SectionScreen extends StatefulWidget {
  final String section;
  SectionScreen({required this.section});

  @override
  _SectionScreenState createState() => _SectionScreenState();
}

class _SectionScreenState extends State<SectionScreen> with SingleTickerProviderStateMixin {
  late FlutterSoundRecorder _recorder;
  String? audioPath;
  bool isRecording = false;
  bool hasRecorded = false;
  bool isShowingResult = false;
  List<String> items = [];
  List<String> questions = [];
  int currentQuestionIndex = 0;
  String displayText = '';
  String transcribedText = '';
  int correctCount = 0;
  List<double> sentencePercentages = [];
  bool isLoading = true;
  bool isCorrect = false;
  late AnimationController _micAnimationController;
  
  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder();
    _micAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    _initializeRecorder();
    _fetchItems();
  }

  Future<void> _initializeRecorder() async {
    await _recorder.openRecorder();
    await Permission.microphone.request();
  }

  Future<void> _fetchItems() async {
    setState(() {
      isLoading = true;
    });
    try {
      final doc = await FirebaseFirestore.instance
          .collection('literacycheck')
          .doc(widget.section)
          .get();
      final data = doc.data();
      if (data != null && data['items'] is List) {
        setState(() {
          items = List<String>.from(data['items']);
          questions = (items..shuffle()).take(5).toList();
          displayText = questions[currentQuestionIndex];
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> toggleRecording() async {
    if (!isRecording) {
      final dir = await getTemporaryDirectory();
      audioPath = '${dir.path}/recording.aac';
      await _recorder.startRecorder(toFile: audioPath);
      setState(() => isRecording = true);
      _micAnimationController.repeat(reverse: true);
    } else {
      await _recorder.stopRecorder();
      _micAnimationController.stop();
      _micAnimationController.reset();
      setState(() {
        isRecording = false;
        hasRecorded = true;
      });
      await _transcribeAudio();
    }
  }

  Future<void> _transcribeAudio() async {
    if (audioPath == null) return;

    setState(() {
      isLoading = true;
    });

    final file = File(audioPath!);
    final bytes = await file.readAsBytes();
    final url = Uri.parse('https://api.deepgram.com/v1/listen');

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Token d9c546d470d13e5d00918648ff7422207360cfb1',
          'Content-Type': 'audio/aac',
        },
        body: bytes,
      );

      final jsonResponse = jsonDecode(response.body);
      if (jsonResponse['results'] != null) {
        final transcript =
            jsonResponse['results']['channels'][0]['alternatives'][0]['transcript'];

        setState(() {
          transcribedText = transcript.isEmpty ? 'No speech detected' : transcript;

          if (widget.section == 'sentences') {
            double percentage = _calculateSentenceMatch(
              displayText,
              transcribedText,
            );
            sentencePercentages.add(percentage);
          }

          String normalizedTranscribed = _normalizeText(transcribedText);
          String normalizedDisplay = _normalizeText(displayText);

          isCorrect = normalizedTranscribed == normalizedDisplay;
          if (isCorrect) {
            correctCount++;
          }
          
          isShowingResult = true;
          isLoading = false;
        });
      } else {
        setState(() {
          transcribedText = 'Transcription error: No results';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        transcribedText = 'Error: $e';
        isLoading = false;
      });
    }
  }

  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  double _calculateSentenceMatch(String expected, String actual) {
    String normExpected = _normalizeText(expected);
    String normActual = _normalizeText(actual);
    int maxLength = normExpected.length > normActual.length
        ? normExpected.length
        : normActual.length;
    if (maxLength == 0) return 100.0;
    int distance = _levenshteinDistance(normExpected, normActual);
    double similarity = (1 - distance / maxLength) * 100;
    return similarity.clamp(0.0, 100.0);
  }

  int _levenshteinDistance(String s1, String s2) {
    List<List<int>> dp = List.generate(
      s1.length + 1,
      (_) => List<int>.filled(s2.length + 1, 0),
    );
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
        isShowingResult = false;
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
      await prefs.setString(
        '${widget.section}-percentages',
        jsonEncode(sentencePercentages),
      );
    }
    Navigator.pop(context);
  }

  Future<bool> _onWillPop() async => false;

  @override
  void dispose() {
    _recorder.closeRecorder();
    _micAnimationController.dispose();
    super.dispose();
  }

  Color _getProgressColor(int index) {
    if (index < currentQuestionIndex) {
      // Completed question
      return Colors.blue;
    } else if (index == currentQuestionIndex) {
      // Current question
      return Colors.amber;
    } else {
      // Upcoming question
      return Colors.grey.shade300;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.section.capitalize()} Challenge', 
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.blue.shade700,
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Are you sure?'),
                    content: Text('You will lose your progress if you exit now.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Stay'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pop(context);
                        },
                        child: Text('Exit'),
                      ),
                    ],
                  ),
                );
              },
              child: Text('Exit', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: Colors.blue.shade50,
        body: isLoading 
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Progress bar
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      questions.length,
                      (index) => Container(
                        margin: EdgeInsets.symmetric(horizontal: 4),
                        width: MediaQuery.of(context).size.width / (questions.length + 2),
                        height: 8,
                        decoration: BoxDecoration(
                          color: _getProgressColor(index),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Question card
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Text(
                                  'Question ${currentQuestionIndex + 1}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  displayText,
                                  style: TextStyle(
                                    fontSize: 28, 
                                    fontWeight: FontWeight.bold,
                                    height: 1.3,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        SizedBox(height: 24),
                        
                        // Microphone button or result animations
                        if (isShowingResult) ...[
                          Container(
                            height: 150,
                            width: 150,
                            child: isCorrect
                              ? Lottie.asset('assets/animations/correct.json')
                              : Lottie.asset('assets/animations/incorrect.json'),
                          ),
                          SizedBox(height: 16),
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'You said:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  transcribedText,
                                  style: TextStyle(
                                    fontSize: 20, 
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  isCorrect ? 'Correct! 🎉' : 'Not quite right 🤔',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: isCorrect ? Colors.green : Colors.orange,
                                  ),
                                ),
                                if (widget.section == 'sentences' && 
                                    sentencePercentages.isNotEmpty && 
                                    currentQuestionIndex < sentencePercentages.length) ...[
                                  SizedBox(height: 8),
                                  Text(
                                    'Match: ${sentencePercentages[currentQuestionIndex].toStringAsFixed(1)}%',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _nextQuestion,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              currentQuestionIndex < questions.length - 1
                                  ? 'Next Question'
                                  : 'Finish Challenge',
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                        ] else ...[
                          InkWell(
                            onTap: toggleRecording,
                            child: Container(
                              height: 150,
                              width: 150,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isRecording ? Colors.red : Colors.blue.shade700,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 10,
                                    offset: Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: AnimatedBuilder(
                                animation: _micAnimationController,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale: isRecording 
                                      ? 1.0 + (_micAnimationController.value * 0.2) 
                                      : 1.0,
                                    child: Icon(
                                      isRecording ? Icons.stop : Icons.mic,
                                      size: 80,
                                      color: Colors.white,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          SizedBox(height: 24),
                          Text(
                            isRecording ? 'Tap to stop' : 'Tap to speak',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (isRecording) ...[
                            SizedBox(height: 16),
                            Lottie.asset(
                              'assets/animations/wave_animation.json',
                              height: 80,
                              width: 200,
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
      ),
    );
  }
}