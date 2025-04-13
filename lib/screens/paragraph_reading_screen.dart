import 'dart:async';
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

class ParagraphReadingScreen extends StatefulWidget {
  @override
  _ParagraphReadingScreenState createState() => _ParagraphReadingScreenState();
}

class _ParagraphReadingScreenState extends State<ParagraphReadingScreen> with SingleTickerProviderStateMixin {
  late FlutterSoundRecorder _recorder;
  String? audioPath;
  bool isRecording = false;
  bool hasRecorded = false;
  bool isShowingResult = false;
  List<String> paragraphs = [];
  List<String> questions = [];
  int currentQuestionIndex = 0;
  String displayText = '';
  String transcribedText = '';
  int correctCount = 0;
  List<double> readingPercentages = [];
  List<int> pausesCounts = [];
  List<double> stutterPercentages = [];
  bool isLoading = true;
  bool isCorrect = false;
  late AnimationController _micAnimationController;
  List<Map<String, dynamic>> _pauseLocations = [];
  List<Map<String, dynamic>> _stutterLocations = [];
  
  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder();
    _micAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    _initializeRecorder();
    _fetchParagraphs();
  }

  Future<void> _initializeRecorder() async {
    await _recorder.openRecorder();
    await Permission.microphone.request();
  }

  Future<void> _fetchParagraphs() async {
    setState(() {
      isLoading = true;
    });
    try {
      final doc = await FirebaseFirestore.instance
          .collection('literacycheck')
          .doc('reading')
          .get();
      final data = doc.data();
      if (data != null && data['items'] is List) {
        setState(() {
          paragraphs = List<String>.from(data['items']);
          questions = (paragraphs..shuffle()).take(3).toList(); // Only take 3 paragraphs as they are longer
          displayText = questions[currentQuestionIndex];
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        displayText = "Could not load paragraphs. Please try again later.";
      });
    }
  }

  Future<void> toggleRecording() async {
    if (!isRecording) {
      final dir = await getTemporaryDirectory();
      audioPath = '${dir.path}/paragraph_recording.aac';
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

    // Add a timeout safety mechanism
    Future.delayed(Duration(seconds: 30), () {
      if (isLoading) {
        setState(() {
          isLoading = false;
          transcribedText = 'Request timed out. Please try again.';
        });
      }
    });

    final file = File(audioPath!);
    final bytes = await file.readAsBytes();
    final url = Uri.parse('https://api.deepgram.com/v1/listen?detect_language=true&diarize=false&punctuate=true&model=nova-2&filler_words=true&utterances=true');

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Token d9c546d470d13e5d00918648ff7422207360cfb1',
          'Content-Type': 'audio/aac',
        },
        body: bytes,
      ).timeout(Duration(seconds: 20), onTimeout: () {
        throw TimeoutException("The request timed out");
      });

      final jsonResponse = jsonDecode(response.body);
      if (jsonResponse['results'] != null) {
        final transcript = jsonResponse['results']['channels'][0]['alternatives'][0]['transcript'];
        
        // Get utterances for pause detection
        final utterances = jsonResponse['results']['utterances'] ?? [];
        int pausesCount = utterances.length > 1 ? utterances.length - 1 : 0;
        
        // Track pause locations
        List<Map<String, dynamic>> pauseLocations = [];
        if (utterances.length > 1) {
          for (int i = 0; i < utterances.length - 1; i++) {
            final endTime = utterances[i]['end'];
            final startTime = utterances[i + 1]['start'];
            final pauseDuration = startTime - endTime;
            if (pauseDuration > 0.3) { // Only count pauses longer than 300ms
              pauseLocations.add({
                'start': endTime,
                'end': startTime,
                'duration': pauseDuration,
                'text_before': utterances[i]['transcript'],
                'text_after': utterances[i + 1]['transcript'],
              });
            }
          }
        }
        
        // Get filler words for stuttering detection
        final words = jsonResponse['results']['channels'][0]['alternatives'][0]['words'] ?? [];
        int fillerWordCount = 0;
        int totalWords = words.length;
        
        // Track stutter locations
        List<Map<String, dynamic>> stutterLocations = [];
        
        for (var word in words) {
          if (word['type'] == 'filler') {
            fillerWordCount++;
            stutterLocations.add({
              'word': word['word'],
              'start': word['start'],
              'end': word['end'],
            });
          }
        }
        
        double stutterPercentage = totalWords > 0 ? (fillerWordCount / totalWords) * 100 : 0;

        setState(() {
          transcribedText = transcript.isEmpty ? 'No speech detected' : transcript;

          double percentage = _calculateParagraphMatch(
            displayText,
            transcribedText,
          );
          
          readingPercentages.add(percentage);
          pausesCounts.add(pausesCount);
          stutterPercentages.add(stutterPercentage);
          
          // Store the detailed locations for UI display
          _pauseLocations = pauseLocations;
          _stutterLocations = stutterLocations;

          // Consider a good reading if the match percentage is above 75%
          isCorrect = percentage > 75;
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

  double _calculateParagraphMatch(String expected, String actual) {
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
        _pauseLocations = [];
        _stutterLocations = [];
      });
    } else {
      _saveResultsAndReturn();
    }
  }

  Future<void> _saveResultsAndReturn() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reading-completed', true);
    await prefs.setInt('reading-correct', correctCount);
    await prefs.setString(
      'reading-percentages',
      jsonEncode(readingPercentages),
    );
    await prefs.setString(
      'reading-pauses',
      jsonEncode(pausesCounts),
    );
    await prefs.setString(
      'reading-stutters',
      jsonEncode(stutterPercentages),
    );
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
          title: Text('Paragraph Reading', 
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.teal,
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
        backgroundColor: Colors.teal.shade50,
        body: isLoading 
          ? Center(child: CircularProgressIndicator())
          : SafeArea(  // Added SafeArea to prevent bottom overlay
              child: Column(
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
                    child: SingleChildScrollView(  // Added SingleChildScrollView to handle overflow
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Paragraph card
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
                                      'Paragraph ${currentQuestionIndex + 1}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.teal,
                                      ),
                                    ),
                                    SizedBox(height: 16),
                                    Container(
                                      height: 200,
                                      child: SingleChildScrollView(
                                        child: Text(
                                          displayText,
                                          style: TextStyle(
                                            fontSize: 20, 
                                            fontWeight: FontWeight.w500,
                                            height: 1.5,
                                          ),
                                          textAlign: TextAlign.left,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            SizedBox(height: 24),
                            
                            // Microphone button or result animations
                            if (isShowingResult) ...[
                              Container(
                                height: 120,
                                width: 120,
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
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 5,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        _buildStatCard(
                                          'Reading Accuracy',
                                          '${readingPercentages[currentQuestionIndex].toStringAsFixed(1)}%',
                                          readingPercentages[currentQuestionIndex] > 75 ? Colors.green : Colors.orange,
                                          Icons.check_circle_outline,
                                        ),
                                        SizedBox(width: 12),
                                        _buildStatCard(
                                          'Pauses',
                                          '${pausesCounts[currentQuestionIndex]}',
                                          pausesCounts[currentQuestionIndex] < 5 ? Colors.green : Colors.orange,
                                          Icons.pause_circle_outline,
                                        ),
                                        SizedBox(width: 12),
                                        _buildStatCard(
                                          'Stutters',
                                          '${stutterPercentages[currentQuestionIndex].toStringAsFixed(1)}%',
                                          stutterPercentages[currentQuestionIndex] < 5 ? Colors.green : Colors.orange,
                                          Icons.repeat,
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      isCorrect ? 'Great reading! 🎉' : 'Needs more practice 🤔',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: isCorrect ? Colors.green : Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // New widget to show stutter and pause details
                              if (_pauseLocations.isNotEmpty || _stutterLocations.isNotEmpty) 
                                Container(
                                  margin: EdgeInsets.only(top: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 5,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ExpansionTile(
                                    title: Text(
                                      'Reading Details',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    children: [
                                      if (_pauseLocations.isNotEmpty) ...[
                                        Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Pauses (${_pauseLocations.length}):',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                              SizedBox(height: 8),
                                              ...List.generate(
                                                _pauseLocations.length.clamp(0, 5),  // Show max 5 pauses
                                                (index) {
                                                  final pause = _pauseLocations[index];
                                                  return Container(
                                                    margin: EdgeInsets.only(bottom: 8),
                                                    padding: EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        RichText(
                                                          text: TextSpan(
                                                            style: TextStyle(
                                                              color: Colors.black87,
                                                              fontSize: 14,
                                                            ),
                                                            children: [
                                                              TextSpan(
                                                                text: '${pause['text_before']} ',
                                                                style: TextStyle(color: Colors.black),
                                                              ),
                                                              TextSpan(
                                                                text: '(${pause['duration'].toStringAsFixed(1)}s pause)',
                                                                style: TextStyle(
                                                                  color: Colors.red,
                                                                  fontWeight: FontWeight.bold,
                                                                ),
                                                              ),
                                                              TextSpan(
                                                                text: ' ${pause['text_after']}',
                                                                style: TextStyle(color: Colors.black),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                              if (_pauseLocations.length > 5)
                                                Text('+ ${_pauseLocations.length - 5} more pauses'),
                                            ],
                                          ),
                                        ),
                                      ],
                                      if (_stutterLocations.isNotEmpty) ...[
                                        Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Stutters/Fillers (${_stutterLocations.length}):',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.orange,
                                                ),
                                              ),
                                              SizedBox(height: 8),
                                              ...List.generate(
                                                _stutterLocations.length.clamp(0, 5),  // Show max 5 stutters
                                                (index) {
                                                  final stutter = _stutterLocations[index];
                                                  final duration = (stutter['end'] - stutter['start']).toStringAsFixed(1);
                                                  return Container(
                                                    margin: EdgeInsets.only(bottom: 8),
                                                    padding: EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: Colors.orange.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      '"${stutter['word']}" (${duration}s)',
                                                      style: TextStyle(fontStyle: FontStyle.italic),
                                                    ),
                                                  );
                                                },
                                              ),
                                              if (_stutterLocations.length > 5)
                                                Text('+ ${_stutterLocations.length - 5} more stutters/fillers'),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              
                              SizedBox(height: 24),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),  // Added bottom padding
                                child: ElevatedButton(
                                  onPressed: _nextQuestion,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Text(
                                    currentQuestionIndex < questions.length - 1
                                        ? 'Next Paragraph'
                                        : 'Finish Challenge',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                ),
                              ),
                            ] else ...[
                              InkWell(
                                onTap: toggleRecording,
                                child: Container(
                                  height: 120,
                                  width: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isRecording ? Colors.red : Colors.teal,
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
                                          size: 60,
                                          color: Colors.white,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              SizedBox(height: 24),
                              Text(
                                isRecording ? 'Tap to stop' : 'Read the paragraph aloud',
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
                  ),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}