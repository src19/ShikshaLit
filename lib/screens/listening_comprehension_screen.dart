// import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ListeningComprehensionScreen extends StatefulWidget {
  @override
  _ListeningComprehensionScreenState createState() =>
      _ListeningComprehensionScreenState();
}

class _ListeningComprehensionScreenState
    extends State<ListeningComprehensionScreen> {
  final FlutterTts flutterTts = FlutterTts();
  List<Map<String, dynamic>> comprehensions = [];
  int currentComprehensionIndex = 0;
  int currentQuestionIndex = 0;
  bool isLoading = true;
  bool isPlaying = false;
  bool showResult = false;
  bool isCorrect = false;
  int correctAnswers = 0;
  int totalQuestions = 0;
  
  // Store shuffled options for each question
  List<List<Map<String, dynamic>>> shuffledOptionsByComprehension = [];

  @override
  void initState() {
    super.initState();
    _initTts();
    _fetchComprehensions();
  }

  Future<void> _initTts() async {
    await flutterTts.setLanguage("en-IN");
    await flutterTts.setSpeechRate(0.5); // Slower rate for better comprehension
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);

    flutterTts.setCompletionHandler(() {
      setState(() {
        isPlaying = false;
      });
    });
  }

  Future<void> _fetchComprehensions() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('literacycheck')
          .doc('comprehension')
          .get();
      
      final data = doc.data();
      if (data != null && data['comprehensions'] is List) {
        List<dynamic> rawComprehensions = data['comprehensions'];
        List<Map<String, dynamic>> parsedComprehensions = [];
        List<List<Map<String, dynamic>>> allShuffledOptions = [];
        
        int totalQuestionsCount = 0;
        
        for (var comp in rawComprehensions) {
          // Each comp is a map with one key (the paragraph)
          String paragraph = comp.keys.first;
          List<dynamic> questionsRaw = comp[paragraph];
          
          List<Map<String, dynamic>> parsedQuestions = [];
          List<Map<String, dynamic>> shuffledOptionsForThisComprehension = [];
          
          for (var questionMap in questionsRaw) {
            // Each questionMap is a map with one key (the question)
            String questionText = questionMap.keys.first;
            List<dynamic> optionsRaw = questionMap[questionText];
            
            List<Map<String, dynamic>> parsedOptions = [];
            
            // Convert each option to a proper map
            for (var option in optionsRaw) {
              parsedOptions.add(Map<String, dynamic>.from(option));
            }
            
            // Make a copy of options to shuffle
            List<Map<String, dynamic>> shuffledOptions = List.from(parsedOptions);
            shuffledOptions.shuffle();
            shuffledOptionsForThisComprehension.add({
              'question': questionText,
              'options': shuffledOptions
            });
            
            parsedQuestions.add({
              'question': questionText,
              'options': parsedOptions
            });
            
            totalQuestionsCount++;
          }
          
          parsedComprehensions.add({
            'paragraph': paragraph,
            'questions': parsedQuestions
          });
          
          allShuffledOptions.add(shuffledOptionsForThisComprehension);
        }
        
        setState(() {
          comprehensions = parsedComprehensions;
          shuffledOptionsByComprehension = allShuffledOptions;
          totalQuestions = totalQuestionsCount;
          isLoading = false;
        });
        
        // Start speaking the first paragraph
        _speakParagraph();
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error fetching comprehensions: $e');
    }
  }

  Future<void> _speakParagraph() async {
    if (comprehensions.isEmpty) return;
    
    setState(() {
      isPlaying = true;
    });
    
    String paragraph = comprehensions[currentComprehensionIndex]['paragraph'];
    await flutterTts.speak(paragraph);
  }

  Future<void> _stopSpeaking() async {
    await flutterTts.stop();
    setState(() {
      isPlaying = false;
    });
  }

  void _checkAnswer(int optionIndex) {
    if (showResult) return; // Don't allow selection during result animation
    
    Map<String, dynamic> shuffledQuestion = shuffledOptionsByComprehension[currentComprehensionIndex][currentQuestionIndex];
    List<Map<String, dynamic>> options = shuffledQuestion['options'];
    bool selectedAnswer = options[optionIndex].values.first;
    
    setState(() {
      showResult = true;
      isCorrect = selectedAnswer;
      if (selectedAnswer) correctAnswers++;
    });
    
    // Show result animation for 2 seconds before proceeding
    Future.delayed(Duration(seconds: 2), () {
      _moveToNextQuestion();
    });
  }

  void _moveToNextQuestion() {
    if (!mounted) return;
    
    setState(() {
      showResult = false;
    });
    
    List<Map<String, dynamic>> questions = 
        shuffledOptionsByComprehension[currentComprehensionIndex];
    
    if (currentQuestionIndex < questions.length - 1) {
      // Move to next question in current comprehension
      setState(() {
        currentQuestionIndex++;
      });
    } else if (currentComprehensionIndex < comprehensions.length - 1) {
      // Move to next comprehension
      setState(() {
        currentComprehensionIndex++;
        currentQuestionIndex = 0;
      });
      _speakParagraph();
    } else {
      // All comprehensions completed
      _saveResultsAndReturn();
    }
  }

  Future<void> _saveResultsAndReturn() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('comprehension-completed', true);
    await prefs.setInt('comprehension-correct', correctAnswers);
    await prefs.setInt('comprehension-total', totalQuestions);
    
    Navigator.pop(context);
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Listening Comprehension'),
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (comprehensions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Listening Comprehension'),
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: Text('No comprehension exercises available'),
        ),
      );
    }
    
    Map<String, dynamic> currentComprehension = comprehensions[currentComprehensionIndex];
    String paragraph = currentComprehension['paragraph'];
    
    Map<String, dynamic> shuffledQuestion = 
        shuffledOptionsByComprehension[currentComprehensionIndex][currentQuestionIndex];
    String questionText = shuffledQuestion['question'];
    List<Map<String, dynamic>> options = shuffledQuestion['options'];
    
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Listening Comprehension'),
          automaticallyImplyLeading: false,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                        'Listen to the story',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      GestureDetector(
                        onTap: isPlaying ? _stopSpeaking : _speakParagraph,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            shape: BoxShape.circle,
                          ),
                          padding: EdgeInsets.all(16),
                          child: Icon(
                            isPlaying ? Icons.stop : Icons.volume_up,
                            size: 32,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        isPlaying ? 'Tap to stop' : 'Tap to listen',
                        style: TextStyle(
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Question ${currentQuestionIndex + 1} of ${shuffledOptionsByComprehension[currentComprehensionIndex].length}:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 8),
              Text(
                questionText,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 24),
              Expanded(
                child: showResult 
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Lottie.asset(
                              isCorrect 
                                  ? 'assets/animations/correct.json'
                                  : 'assets/animations/incorrect.json',
                              width: 200,
                              height: 200,
                              repeat: true,
                              animate: true,
                            ),
                            SizedBox(height: 16),
                            Text(
                              isCorrect ? 'Great job!' : 'Try again next time!',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isCorrect ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          String optionText = options[index].keys.first;
                          return Card(
                            margin: EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                            child: InkWell(
                              onTap: () => _checkAnswer(index),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  optionText,
                                  style: TextStyle(fontSize: 18),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Score: $correctAnswers / $totalQuestions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}