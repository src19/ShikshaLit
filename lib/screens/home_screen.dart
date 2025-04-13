import 'package:flutter/material.dart';
import 'package:literacy_check/screens/error_finding_screen.dart';
import 'package:literacy_check/screens/paragraph_reading_screen.dart';
import 'package:literacy_check/screens/rhyming_words_screen.dart';
import 'package:literacy_check/screens/spelling_screen.dart'; // Import the new screen
import 'package:shared_preferences/shared_preferences.dart';
import 'section_screen.dart';
import 'results_screen.dart';
import '../utils/string_extensions.dart';
import 'listening_comprehension_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late SharedPreferences prefs;
  List<String> sections = [
    'alphabets', 
    'words', 
    'sentences', 
    'comprehension', 
    'reading', 
    'errorfind',
    'rhyming',
    'spelling'  // Add the new spelling section
  ];
  
  Map<String, bool> completedSections = {};
  
  Map<String, IconData> sectionIcons = {
    'alphabets': Icons.sort_by_alpha,
    'words': Icons.text_fields,
    'sentences': Icons.short_text,
    'comprehension': Icons.hearing,
    'reading': Icons.menu_book,
    'errorfind': Icons.error_outline,
    'rhyming': Icons.music_note,
    'spelling': Icons.spellcheck,  // Icon for spelling section
  };
  
  Map<String, Color> sectionColors = {
    'alphabets': Colors.blue,
    'words': Colors.green,
    'sentences': Colors.orange,
    'comprehension': Colors.purple,
    'reading': Colors.teal,
    'errorfind': Colors.red,
    'rhyming': Colors.deepPurple,
    'spelling': Colors.amber,  // Color for spelling section
  };
  
  Map<String, String> sectionDescriptions = {
    'alphabets': 'Practice letter identification',
    'words': 'Read simple words aloud',
    'sentences': 'Read complete sentences',
    'comprehension': 'Listen and answer questions',
    'reading': 'Read paragraphs fluently',
    'errorfind': 'Find errors in sentences',
    'rhyming': 'Identify words that rhyme',
    'spelling': 'Spell words you hear',  // Description for spelling section
  };

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    prefs = await SharedPreferences.getInstance();
    setState(() {
      for (var section in sections) {
        completedSections[section] =
            prefs.getBool('$section-completed') ?? false;
      }
    });
  }

  bool get allSectionsCompleted =>
      completedSections.values.every((completed) => completed);

  Future<void> _resetProgress() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset Progress'),
        content: Text('Are you sure you want to reset all progress?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await prefs.clear();
              setState(() {
                completedSections.updateAll((key, value) => false);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Progress reset successfully!'),
                  behavior: SnackBarBehavior.floating,
                )
              );
            },
            child: Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _navigateToSection(String section) {
    switch (section) {
      case 'comprehension':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ListeningComprehensionScreen(),
          ),
        ).then((_) => _loadPreferences());
        break;
      case 'reading':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ParagraphReadingScreen(),
          ),
        ).then((_) => _loadPreferences());
        break;
      case 'errorfind':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ErrorFindingScreen(),
          ),
        ).then((_) => _loadPreferences());
        break;
      case 'rhyming':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RhymingWordsScreen(),
          ),
        ).then((_) => _loadPreferences());
        break;
      case 'spelling':  // Handle the new spelling section
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SpellingScreen(),
          ),
        ).then((_) => _loadPreferences());
        break;
      default:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SectionScreen(section: section),
          ),
        ).then((_) => _loadPreferences());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Literacy Check',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Reset Progress',
            onPressed: _resetProgress,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.indigo, Colors.indigo.shade100],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Select a learning activity',
                style: TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: sections.length,
                  itemBuilder: (context, index) {
                    final section = sections[index];
                    final isCompleted = completedSections[section] == true;
                    
                    return Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: InkWell(
                        onTap: () => _navigateToSection(section),
                        borderRadius: BorderRadius.circular(15),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 35,
                                  backgroundColor: sectionColors[section]!.withOpacity(0.2),
                                  child: Icon(
                                    sectionIcons[section],
                                    size: 40,
                                    color: sectionColors[section],
                                  ),
                                ),
                                if (isCompleted)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      padding: EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(height: 16),
                            Text(
                              section.capitalize(),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Text(
                                sectionDescriptions[section] ?? '',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (allSectionsCompleted)
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ResultsScreen(),
                      ),
                    );
                  },
                  icon: Icon(Icons.assessment),
                  label: Text('View Results'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}