import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RhymingWordsScreen extends StatefulWidget {
  @override
  _RhymingWordsScreenState createState() => _RhymingWordsScreenState();
}

class _RhymingWordsScreenState extends State<RhymingWordsScreen> {
  final FlutterTts flutterTts = FlutterTts();
  List<Map<String, dynamic>> rhymingExercises = [];
  int currentExerciseIndex = 0;
  bool isLoading = true;
  bool isPlaying = false;
  bool showResult = false;
  bool isCorrect = false;
  int correctAnswers = 0;
  int totalQuestions = 0;
  String currentExplanation = '';
  bool hasError = false;
  String errorMessage = '';
  
  // Store shuffled options for each question
  List<List<String>> shuffledOptionsForExercises = [];

  @override
  void initState() {
    super.initState();
    _initTts();
    _fetchRhymingExercises();
  }

  Future<void> _initTts() async {
    try {
      await flutterTts.setLanguage("en-US");
      await flutterTts.setSpeechRate(0.5); // Slower rate for better comprehension
      await flutterTts.setVolume(1.0);
      await flutterTts.setPitch(1.0);

      flutterTts.setCompletionHandler(() {
        if (mounted) {
          setState(() {
            isPlaying = false;
          });
        }
      });
    } catch (e) {
      print('TTS initialization error: $e');
      // Continue even if TTS fails
    }
  }

  Future<void> _fetchRhymingExercises() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('literacycheck')
          .doc('rhyming')
          .get();
      
      final data = doc.data();
      print('Raw document data: ${doc.data()}');
      
      if (data != null && data['exercies'] is List) {
        List<dynamic> rawExercises = data['exercies'];
        List<Map<String, dynamic>> parsedExercises = [];
        List<List<String>> allShuffledOptions = [];
        
        for (var exercise in rawExercises) {
          if (exercise is Map<String, dynamic>) {
            String targetWord = exercise['targetWord'] ?? '';
            List<dynamic> optionsRaw = exercise['options'] ?? [];
            String correctAnswer = exercise['correctAnswer'] ?? '';
            String explanation = exercise['explanation'] ?? '';
            
            // Convert options to List<String>
            List<String> options = List<String>.from(optionsRaw);
            
            // Make a copy of options to shuffle
            List<String> shuffledOptions = List.from(options);
            shuffledOptions.shuffle();
            allShuffledOptions.add(shuffledOptions);
            
            parsedExercises.add({
              'targetWord': targetWord,
              'options': options,
              'correctAnswer': correctAnswer,
              'explanation': explanation
            });
          }
        }
        
        if (mounted) {
          setState(() {
            rhymingExercises = parsedExercises;
            shuffledOptionsForExercises = allShuffledOptions;
            totalQuestions = parsedExercises.length;
            isLoading = false;
            
            // Only speak if we have exercises
            if (parsedExercises.isNotEmpty) {
              _speakTargetWord();
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            isLoading = false;
            hasError = true;
            errorMessage = 'No rhyming exercises found. Please try again later.';
          });
        }
      }
    } catch (e) {
      print('Error fetching rhyming exercises: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          hasError = true;
          errorMessage = 'Error loading exercises. Please try again later.';
        });
      }
    }
  }

  Future<void> _speakTargetWord() async {
    if (rhymingExercises.isEmpty || !mounted) return;
    
    setState(() {
      isPlaying = true;
    });
    
    try {
      String targetWord = rhymingExercises[currentExerciseIndex]['targetWord'];
      await flutterTts.speak("Which word rhymes with $targetWord?");
    } catch (e) {
      print('TTS error: $e');
      if (mounted) {
        setState(() {
          isPlaying = false;
        });
      }
    }
  }
  
  Future<void> _speakOption(String option) async {
    if (!mounted) return;
    
    setState(() {
      isPlaying = true;
    });
    
    try {
      await flutterTts.speak(option);
    } catch (e) {
      print('TTS error: $e');
      if (mounted) {
        setState(() {
          isPlaying = false;
        });
      }
    }
  }
  
  Future<void> _speakExplanation() async {
    if (!mounted) return;
    
    setState(() {
      isPlaying = true;
    });
    
    try {
      String explanation = currentExplanation;
      await flutterTts.speak(explanation);
    } catch (e) {
      print('TTS error: $e');
      if (mounted) {
        setState(() {
          isPlaying = false;
        });
      }
    }
  }

  Future<void> _stopSpeaking() async {
    try {
      await flutterTts.stop();
      if (mounted) {
        setState(() {
          isPlaying = false;
        });
      }
    } catch (e) {
      print('TTS error: $e');
    }
  }

  void _checkAnswer(String selectedOption) {
    if (showResult || !mounted) return; // Don't allow selection during result animation
    
    Map<String, dynamic> currentExercise = rhymingExercises[currentExerciseIndex];
    String correctAnswer = currentExercise['correctAnswer'];
    
    setState(() {
      showResult = true;
      isCorrect = selectedOption == correctAnswer;
      currentExplanation = currentExercise['explanation'];
      if (isCorrect) correctAnswers++;
    });
    
    // Speak the explanation
    _speakExplanation();
    
    // Removed auto-advance timer to allow user control
  }

  void _moveToNextQuestion() {
    if (!mounted) return;
    
    setState(() {
      showResult = false;
    });
    
    if (currentExerciseIndex < rhymingExercises.length - 1) {
      // Move to next exercise
      setState(() {
        currentExerciseIndex++;
      });
      _speakTargetWord();
    } else {
      // All exercises completed
      _saveResultsAndReturn();
    }
  }

  Future<void> _saveResultsAndReturn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('rhyming-completed', true);
      await prefs.setInt('rhyming-correct', correctAnswers);
      await prefs.setInt('rhyming-total', totalQuestions);
    } catch (e) {
      print('Error saving results: $e');
    } finally {
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<bool> _onWillPop() async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Are you sure?'),
        content: Text('You will lose your progress if you exit now.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Exit'),
          ),
        ],
      ),
    ) ?? false;
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
          title: Text('Rhyming Words', 
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.deepPurple,
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Exit', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: Colors.deepPurple.shade50,
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.deepPurple,
          ),
        ),
      );
    }
    
    if (hasError) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Rhyming Words', 
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.deepPurple,
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
        backgroundColor: Colors.deepPurple.shade50,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              SizedBox(height: 16),
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    isLoading = true;
                    hasError = false;
                  });
                  _fetchRhymingExercises();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                child: Text('Try Again'),
              ),
              SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }
    
    if (rhymingExercises.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Rhyming Words',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.deepPurple,
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
        backgroundColor: Colors.deepPurple.shade50,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 64,
                color: Colors.amber,
              ),
              SizedBox(height: 16),
              Text(
                'No rhyming exercises available',
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                child: Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }
    
    Map<String, dynamic> currentExercise = rhymingExercises[currentExerciseIndex];
    String targetWord = currentExercise['targetWord'];
    List<String> shuffledOptions = shuffledOptionsForExercises[currentExerciseIndex];
    
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Rhyming Words',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.deepPurple,
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
        backgroundColor: Colors.deepPurple.shade50,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress bar
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        rhymingExercises.length,
                        (index) => Container(
                          margin: EdgeInsets.symmetric(horizontal: 2),
                          width: 24,
                          height: 8,
                          decoration: BoxDecoration(
                            color: index < currentExerciseIndex
                              ? Colors.deepPurple
                              : index == currentExerciseIndex
                                ? Colors.amber
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Text(
                          'Listen to the word',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16),
                        GestureDetector(
                          onTap: isPlaying ? _stopSpeaking : _speakTargetWord,
                          child: Container(
                            height: 80,
                            width: 80,
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.shade100,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 5,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              isPlaying ? Icons.stop : Icons.volume_up,
                              size: 40,
                              color: Colors.deepPurple,
                            ),
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          isPlaying ? 'Tap to stop' : 'Tap to listen',
                          style: TextStyle(
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 24),
                        Text(
                          'Which word rhymes with "$targetWord"?',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Question ${currentExerciseIndex + 1} of ${rhymingExercises.length}:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 16),
                Expanded(
                  child: showResult 
                      ? SingleChildScrollView( // Make result view scrollable to avoid overflow
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                height: 120,
                                width: 120,
                                child: isCorrect 
                                    ? Lottie.asset('assets/animations/correct.json')
                                    : Lottie.asset('assets/animations/incorrect.json'),
                              ),
                              SizedBox(height: 16),
                              Text(
                                isCorrect ? 'Great job! 🎉' : 'Try again next time! 🤔',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: isCorrect ? Colors.green : Colors.orange,
                                ),
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
                                    Text(
                                      'Explanation:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      currentExplanation,
                                      style: TextStyle(
                                        fontSize: 16,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: isPlaying ? _stopSpeaking : _speakExplanation,
                                    icon: Icon(isPlaying ? Icons.stop : Icons.volume_up),
                                    label: Text(isPlaying ? 'Stop' : 'Listen'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.deepPurple.shade300,
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  ElevatedButton.icon(
                                    onPressed: _moveToNextQuestion,
                                    icon: Icon(Icons.arrow_forward),
                                    label: Text(currentExerciseIndex < rhymingExercises.length - 1 ? 'Next' : 'Finish'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.deepPurple,
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: shuffledOptions.length,
                          itemBuilder: (context, index) {
                            String option = shuffledOptions[index];
                            return Card(
                              margin: EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                              child: InkWell(
                                onTap: () => _checkAnswer(option),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          option,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.volume_up, color: Colors.deepPurple),
                                        onPressed: () => _speakOption(option),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade100,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      'Score: $correctAnswers / $totalQuestions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
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