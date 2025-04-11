import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'section_screen.dart';
import 'results_screen.dart';
import '../utils/string_extensions.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late SharedPreferences prefs;
  List<String> sections = ['alphabets', 'words', 'sentences'];
  Map<String, bool> completedSections = {};

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    prefs = await SharedPreferences.getInstance();
    setState(() {
      for (var section in sections) {
        completedSections[section] = prefs.getBool('$section-completed') ?? false;
      }
    });
  }

  bool get allSectionsCompleted => completedSections.values.every((completed) => completed);

  Future<void> _resetProgress() async {
    await prefs.clear();
    setState(() {
      completedSections.updateAll((key, value) => false);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Progress reset successfully!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Literacy Check')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: sections.map((section) {
                  return Card(
                    child: ListTile(
                      title: Text(section.capitalize()),
                      trailing: completedSections[section]! ? Icon(Icons.check, color: Colors.green) : null,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SectionScreen(section: section),
                          ),
                        ).then((_) => _loadPreferences());
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            if (allSectionsCompleted)
              Column(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ResultsScreen()),
                      );
                    },
                    child: Text('View Results'),
                  ),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _resetProgress,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: Text('Reset Progress'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}