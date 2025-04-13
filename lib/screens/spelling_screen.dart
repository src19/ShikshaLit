import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_tts/flutter_tts.dart';

class SpellingScreen extends StatefulWidget {
  @override
  _SpellingScreenState createState() => _SpellingScreenState();
}

class _SpellingScreenState extends State<SpellingScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> wordList = [];
  List<Map<String, dynamic>> questions = [];
  int currentQuestionIndex = 0;
  bool isShowingResult = false;
  int correctCount = 0;
  late FlutterTts flutterTts;
  bool isSpeaking = false;
  
  // For handling letter selection
  List<String> availableLetters = [];
  List<String> selectedLetters = [];
  String currentWord = '';
  
  @override
  void initState() {
    super.initState();
    _initTts();
    _fetchSpellingWords();
  }
  
  Future<void> _initTts() async {
    flutterTts = FlutterTts();
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5); // Slower speech rate for learning
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);
    
    flutterTts.setCompletionHandler(() {
      setState(() {
        isSpeaking = false;
      });
    });
  }

  Future<void> _fetchSpellingWords() async {
    setState(() {
      isLoading = true;
    });
    try {
      final doc = await FirebaseFirestore.instance
          .collection('literacycheck')
          .doc('spelling')
          .get();
      final data = doc.data();
      if (data != null && data['items'] is List) {
        List<dynamic> items = data['items'];
        setState(() {
          wordList = items.map((item) => {
            'word': item['word'] as String,
            'hint': item['hint'] as String,
            'difficulty': item['difficulty'] as String,
          }).toList();
          
          // Create 5 random questions from the word list
          wordList.shuffle();
          questions = wordList.take(5).toList();
          _prepareCurrentQuestion();
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error fetching spelling words: $e');
    }
  }
  
  void _prepareCurrentQuestion() {
    if (questions.isEmpty) return;
    
    currentWord = questions[currentQuestionIndex]['word'] as String;
    
    // Reset selected letters
    selectedLetters = List.generate(currentWord.length, (_) => '');
    
    // Create available letters - include the correct letters plus some random ones
    Set<String> letterSet = currentWord.split('').toSet();
    
    // Add some random letters to make it challenging
    Random random = Random();
    String alphabet = 'abcdefghijklmnopqrstuvwxyz';
    
    // Add random letters until we have 12 total options (or however many you want)
    while (letterSet.length < min(12, 26)) {
      String randomLetter = alphabet[random.nextInt(alphabet.length)];
      letterSet.add(randomLetter);
    }
    
    // Convert to list and shuffle
    availableLetters = letterSet.toList()..shuffle();
  }
  
  void _speakCurrentWord() async {
    setState(() {
      isSpeaking = true;
    });
    
    String wordToSpeak = questions[currentQuestionIndex]['word'] as String;
    String hint = questions[currentQuestionIndex]['hint'] as String;
    
    await flutterTts.speak("The word is: $wordToSpeak. $hint");
  }
  
  void _selectLetter(String letter) {
    if (isShowingResult) return;
    
    // Find the first empty slot in selected letters
    int emptyIndex = selectedLetters.indexOf('');
    if (emptyIndex != -1) {
      setState(() {
        selectedLetters[emptyIndex] = letter;
        
        // Removing the used letter from available letters
        // availableLetters.remove(letter); // Uncomment if you want letters to disappear after selection
      });
      
      // Check if all slots are filled
      if (!selectedLetters.contains('')) {
        _checkAnswer();
      }
    }
  }
  
  void _removeLetter(int index) {
    if (isShowingResult) return;
    
    if (index >= 0 && index < selectedLetters.length && selectedLetters[index].isNotEmpty) {
      setState(() {
        // Add the letter back to available letters if needed
        // availableLetters.add(selectedLetters[index]); // Uncomment if you're removing letters from available
        selectedLetters[index] = '';
      });
    }
  }
  
  void _checkAnswer() {
    String attemptedWord = selectedLetters.join('');
    bool isCorrect = attemptedWord.toLowerCase() == currentWord.toLowerCase();
    
    setState(() {
      isShowingResult = true;
      if (isCorrect) {
        correctCount++;
      }
    });
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
        _prepareCurrentQuestion();
      });
    } else {
      _saveResultsAndReturn();
    }
  }

  Future<void> _saveResultsAndReturn() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('spelling-completed', true);
    await prefs.setInt('spelling-correct', correctCount);
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

  @override
  Widget build(BuildContext context) {
    // Calculate the responsive letter box size based on screen width and word length
    double screenWidth = MediaQuery.of(context).size.width;
    double padding = 32; // Account for padding (16 on each side)
    double spacing = 8; // Spacing between boxes
    double availableWidth = screenWidth - padding;
    
    // Calculate box size - minimum of 30, maximum of 50
    double letterBoxSize = min(
      50.0, // Maximum size
      max(
        30.0, // Minimum size
        (availableWidth - (currentWord.length - 1) * spacing) / currentWord.length
      )
    );
    
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Spelling Challenge', 
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
          : SafeArea(
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
                    child: SingleChildScrollView(
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
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'Listen to the word and spell it correctly',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    SizedBox(height: 24),
                                    ElevatedButton.icon(
                                      onPressed: isSpeaking ? null : _speakCurrentWord,
                                      icon: Icon(Icons.volume_up),
                                      label: Text(isSpeaking ? 'Speaking...' : 'Listen to Word'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue.shade700,
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                    if (questions.isNotEmpty && questions[currentQuestionIndex]['hint'] != null) ...[
                                      SizedBox(height: 16),
                                      Text(
                                        'Hint: ${questions[currentQuestionIndex]['hint']}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontStyle: FontStyle.italic,
                                          color: Colors.grey.shade700,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            
                            SizedBox(height: 32),
                            
                            // Selected letters display with responsive sizing
                            // If the word is long, we'll use Wrap to handle potential overflow
                            currentWord.length <= 8 
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  currentWord.length,
                                  (index) => _buildLetterBox(index, letterBoxSize),
                                ),
                              )
                            : Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: List.generate(
                                  currentWord.length,
                                  (index) => _buildLetterBox(index, letterBoxSize),
                                ),
                              ),
                            
                            SizedBox(height: 32),
                            
                            // Available letters (keyboard-like layout)
                            if (!isShowingResult) ...[
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                runSpacing: 12,
                                children: availableLetters.map((letter) {
                                  return GestureDetector(
                                    onTap: () => _selectLetter(letter),
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade700,
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black26,
                                            offset: Offset(0, 2),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        letter.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                            
                            SizedBox(height: 32),
                            
                            // Results or instructions
                            if (isShowingResult) ...[
                              Container(
                                height: 100,
                                width: 100,
                                child: selectedLetters.join('').toLowerCase() == currentWord.toLowerCase()
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
                                        selectedLetters.join('').toLowerCase() == currentWord.toLowerCase()
                                          ? 'Correct! 🎉'
                                          : 'Not quite right 🤔',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: selectedLetters.join('').toLowerCase() == currentWord.toLowerCase()
                                            ? Colors.green
                                            : Colors.orange,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'The correct spelling is "${currentWord.toUpperCase()}"',
                                        style: TextStyle(fontSize: 16),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: 24),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: ElevatedButton(
                                  onPressed: isSpeaking ? null : _nextQuestion,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade700,
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
                                            ? 'Next Word'
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
                            ] else if (selectedLetters.contains('')) ...[
                              Text(
                                'Tap the letters to spell the word you hear',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ] else ...[
                              ElevatedButton(
                                onPressed: _checkAnswer,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  'Check Spelling',
                                  style: TextStyle(fontSize: 18),
                                ),
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
  
  // Extract the letter box widget to a separate method
  Widget _buildLetterBox(int index, double size) {
    return GestureDetector(
      onTap: () => _removeLetter(index),
      child: Container(
        margin: EdgeInsets.all(4),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isShowingResult
              ? (selectedLetters[index].toLowerCase() == currentWord[index].toLowerCase()
                  ? Colors.green
                  : Colors.red.shade300)
              : (selectedLetters[index].isEmpty
                  ? Colors.white
                  : Colors.blue.shade200),
          border: Border.all(
            color: Colors.blue.shade800,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.contain,
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Text(
              selectedLetters[index].toUpperCase(),
              style: TextStyle(
                fontSize: size > 40 ? 24 : 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }
}