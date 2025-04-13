import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../utils/string_extensions.dart';

class ErrorFindingScreen extends StatefulWidget {
  @override
  _ErrorFindingScreenState createState() => _ErrorFindingScreenState();
}

class _ErrorFindingScreenState extends State<ErrorFindingScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> sentences = [];
  List<Map<String, dynamic>> questions = [];
  int currentQuestionIndex = 0;
  bool isShowingResult = false;
  bool selectedCorrectWord = false;
  int selectedWordIndex = -1;
  int correctCount = 0;
  String? errorExplanation;
  late FlutterTts flutterTts;
  bool isSpeaking = false;
  
  @override
  void initState() {
    super.initState();
    _initTts();
    _fetchErrorSentences();
  }
  
  Future<void> _initTts() async {
    flutterTts = FlutterTts();
    await flutterTts.setLanguage("en-US"); // Set to Indian English
    await flutterTts.setSpeechRate(0.5); // Slower speech rate for learning
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);
    
    flutterTts.setCompletionHandler(() {
      setState(() {
        isSpeaking = false;
      });
    });
  }

  Future<void> _fetchErrorSentences() async {
    setState(() {
      isLoading = true;
    });
    try {
      final doc = await FirebaseFirestore.instance
          .collection('literacycheck')
          .doc('errorfind')
          .get();
      final data = doc.data();
      if (data != null && data['items'] is List) {
        List<dynamic> items = data['items'];
        setState(() {
          sentences = items.map((item) => {
            'sentence': item['sentence'] as String,
            'error_word': item['error_word'] as String,
            'correct_word': item['correct_word'] as String,
            'errorIndex': item['errorIndex'] as int,
            'explanation': item['explanation'] as String,
            'words': (item['sentence'] as String).split(' '),
          }).toList();
          
          // Create 5 random questions from the sentences
          sentences.shuffle();
          questions = sentences.take(5).toList();
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error fetching error sentences: $e');
    }
  }

  void _checkWord(int wordIndex) {
    if (isShowingResult) return;
    
    setState(() {
      selectedWordIndex = wordIndex;
      isShowingResult = true;
      
      int correctErrorIndex = questions[currentQuestionIndex]['errorIndex'] as int;
      selectedCorrectWord = wordIndex == correctErrorIndex;
      
      if (selectedCorrectWord) {
        correctCount++;
      }
      
      errorExplanation = questions[currentQuestionIndex]['explanation'] as String;
    });
    
    // Speak the correct word and explanation
    _speakCorrectWordAndExplanation();
  }
  
  Future<void> _speakCorrectWordAndExplanation() async {
    setState(() {
      isSpeaking = true;
    });
    
    String correctWord = questions[currentQuestionIndex]['correct_word'] as String;
    String explanation = questions[currentQuestionIndex]['explanation'] as String;
    
    // Speak both the correct word and the explanation
    await flutterTts.speak("The correct word is: $correctWord. $explanation");
  }

  void _nextQuestion() async {
    // Ensure TTS has finished speaking before moving on
    if (isSpeaking) {
      await flutterTts.stop();
      setState(() {
        isSpeaking = false;
      });
    }
    
    if (currentQuestionIndex < questions.length - 1) {
      setState(() {
        currentQuestionIndex++;
        isShowingResult = false;
        selectedWordIndex = -1;
        errorExplanation = null;
      });
    } else {
      _saveResultsAndReturn();
    }
  }

  Future<void> _saveResultsAndReturn() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('errorfind-completed', true);
    await prefs.setInt('errorfind-correct', correctCount);
    Navigator.pop(context);
  }

  Future<bool> _onWillPop() async => false;

  @override
  void dispose() {
    flutterTts.stop();
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

  Color _getWordColor(int index) {
    if (!isShowingResult) {
      return Colors.red.shade600;
    }
    
    int correctIndex = questions[currentQuestionIndex]['errorIndex'] as int;
    
    if (index == selectedWordIndex && index == correctIndex) {
      return Colors.green; // Correct selection
    } else if (index == selectedWordIndex) {
      return Colors.red; // Wrong selection
    } else if (index == correctIndex) {
      return Colors.green.shade300; // Show correct answer
    } else {
      return Colors.red.shade600; // Other words
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Find the Error', 
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red.shade700,
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
        backgroundColor: Colors.red.shade50,
        body: isLoading 
          ? Center(child: CircularProgressIndicator())
          : SafeArea(  // Added SafeArea to prevent bottom overflow
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
                            // Instruction card
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
                                        color: Colors.red.shade700,
                                      ),
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'Tap the word that makes this sentence incorrect:',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            SizedBox(height: 24),
                            
                            // Word blocks
                            if (questions.isNotEmpty) ...[
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                runSpacing: 12,
                                children: List.generate(
                                  (questions[currentQuestionIndex]['words'] as List<String>).length,
                                  (index) => GestureDetector(
                                    onTap: isShowingResult ? null : () => _checkWord(index),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: _getWordColor(index),
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black26,
                                            offset: Offset(0, 2),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        (questions[currentQuestionIndex]['words'] as List<String>)[index],
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            
                            SizedBox(height: 32),
                            
                            // Results or instructions
                            if (isShowingResult) ...[
                              Container(
                                height: 100,
                                width: 100,
                                child: selectedCorrectWord
                                  ? Lottie.asset('assets/animations/correct.json')
                                  : Lottie.asset('assets/animations/incorrect.json'),
                              ),
                              SizedBox(height: 16),
                              Card(
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    children: [
                                      Text(
                                        selectedCorrectWord ? 'Correct! 🎉' : 'Not quite right 🤔',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: selectedCorrectWord ? Colors.green : Colors.orange,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'The correct word is "${questions[currentQuestionIndex]['correct_word']}" instead of "${questions[currentQuestionIndex]['error_word']}"',
                                        style: TextStyle(fontSize: 16),
                                        textAlign: TextAlign.center,
                                      ),
                                      if (errorExplanation != null) ...[
                                        SizedBox(height: 8),
                                        Text(
                                          errorExplanation!,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade700,
                                            fontStyle: FontStyle.italic,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: 24),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),  // Added bottom padding
                                child: ElevatedButton(
                                  onPressed: isSpeaking ? null : _nextQuestion,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade700,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    disabledBackgroundColor: Colors.grey,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        currentQuestionIndex < questions.length - 1
                                            ? 'Next Question'
                                            : 'Finish Challenge',
                                        style: TextStyle(fontSize: 18),
                                      ),
                                      if (isSpeaking) ...[
                                        SizedBox(width: 12),
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ] else ...[
                              Text(
                                'Tap on the word that is incorrect in the sentence',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade700,
                                ),
                                textAlign: TextAlign.center,
                              ),
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
}