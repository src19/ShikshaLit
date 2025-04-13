// import 'package:cloud_firestore/cloud_firestore.dart';

// Future<void> populateErrorSentences() async {
//   final FirebaseFirestore firestore = FirebaseFirestore.instance;
  
//   // List of sentences with errors for the error finding assessment
//   List<Map<String, dynamic>> errorSentences = [
//     {
//       "sentence": "The child are playing on the ground.",
//       "error_word": "are",
//       "correct_word": "is",
//       "errorIndex": 1, // Index of the error word in the sentence (0-based)
//       "explanation": "The subject 'child' is singular, so it needs the singular verb 'is' instead of the plural 'are'."
//     },
//     {
//       "sentence": "The sun had come tomorrow.",
//       "error_word": "had come",
//       "correct_word": "will come",
//       "errorIndex": 2,
//       "explanation": "For future events like 'tomorrow', we use 'will come' instead of the past tense 'had come'."
//     },
//     {
//       "sentence": "I have went to the market yesterday.",
//       "error_word": "have went",
//       "correct_word": "went",
//       "errorIndex": 1,
//       "explanation": "With past time expressions like 'yesterday', we use the simple past tense 'went', not present perfect 'have went'."
//     },
//     {
//       "sentence": "They was very happy to see their friends.",
//       "error_word": "was",
//       "correct_word": "were",
//       "errorIndex": 1,
//       "explanation": "The subject 'they' is plural, so it needs the plural verb 'were' instead of the singular 'was'."
//     },
//     {
//       "sentence": "He can sings very well.",
//       "error_word": "sings",
//       "correct_word": "sing",
//       "errorIndex": 2,
//       "explanation": "After modal verbs like 'can', we use the base form of the verb 'sing', not 'sings'."
//     },
//     {
//       "sentence": "The children was playing outside all day.",
//       "error_word": "was",
//       "correct_word": "were",
//       "errorIndex": 2,
//       "explanation": "The noun 'children' is plural, so it requires the plural verb form 'were', not 'was'."
//     },
//     {
//       "sentence": "He will go to the shop yesterday.",
//       "error_word": "will go",
//       "correct_word": "went",
//       "errorIndex": 1,
//       "explanation": "For past time like 'yesterday', use the past tense 'went', not the future tense 'will go'."
//     },
//     {
//       "sentence": "We was so tired that we went to bed early.",
//       "error_word": "was",
//       "correct_word": "were",
//       "errorIndex": 1,
//       "explanation": "The subject 'we' is plural, so it needs the plural verb 'were' instead of the singular 'was'."
//     },
//     {
//       "sentence": "This is the bestest pizza I've ever eaten.",
//       "error_word": "bestest",
//       "correct_word": "best",
//       "errorIndex": 3,
//       "explanation": "The superlative form of 'good' is 'best', not 'bestest'."
//     },
//     {
//       "sentence": "The dog run quickly to fetch the ball.",
//       "error_word": "run",
//       "correct_word": "ran",
//       "errorIndex": 2,
//       "explanation": "This sentence is in past tense, so the verb should be 'ran', not 'run'."
//     },
//     {
//       "sentence": "The news are not good this morning.",
//       "error_word": "are",
//       "correct_word": "is",
//       "errorIndex": 2,
//       "explanation": "The word 'news' is singular, so it requires the singular verb 'is', not 'are'."
//     },
//     {
//       "sentence": "I have readed that book before.",
//       "error_word": "readed",
//       "correct_word": "read",
//       "errorIndex": 2,
//       "explanation": "The past participle of 'read' is 'read' (pronounced 'red'), not 'readed'."
//     },
//     {
//       "sentence": "She doesn't likes to go swimming.",
//       "error_word": "likes",
//       "correct_word": "like",
//       "errorIndex": 2,
//       "explanation": "After auxiliary verbs like 'doesn't', use the base form 'like', not 'likes'."
//     },
//     {
//       "sentence": "There is too many people in this room.",
//       "error_word": "is",
//       "correct_word": "are",
//       "errorIndex": 1,
//       "explanation": "With plural nouns like 'many people', use 'are' instead of 'is'."
//     },
//     {
//       "sentence": "It are difficult to walk on the beach.",
//       "error_word": "are",
//       "correct_word": "is",
//       "errorIndex": 1,
//       "explanation": "The subject 'it' is singular, so it needs the singular verb 'is' instead of the plural 'are'."
//     },
//     {
//       "sentence": "She told me that she had completed the project tomorrow.",
//       "error_word": "had completed",
//       "correct_word": "will complete",
//       "errorIndex": 5,
//       "explanation": "For future events like 'tomorrow', use future tense 'will complete', not past perfect 'had completed'."
//     },
//     {
//       "sentence": "The teacher asked us to completed the assignment by tomorrow.",
//       "error_word": "completed",
//       "correct_word": "complete",
//       "errorIndex": 5,
//       "explanation": "After 'to', use the base form of the verb 'complete', not the past tense 'completed'."
//     },
//     {
//       "sentence": "The book is too expensively for buy.",
//       "error_word": "expensively",
//       "correct_word": "expensive",
//       "errorIndex": 4,
//       "explanation": "We need an adjective 'expensive' to describe the book, not the adverb 'expensively'."
//     },
//     {
//       "sentence": "He dance well.",
//       "error_word": "dance",
//       "correct_word": "dances",
//       "errorIndex": 1,
//       "explanation": "For third-person singular subjects (he/she/it), add -s to the verb: 'dances', not 'dance'."
//     },
//     {
//       "sentence": "He like her.",
//       "error_word": "like",
//       "correct_word": "likes",
//       "errorIndex": 1,
//       "explanation": "For third-person singular subjects (he/she/it), add -s to the verb: 'likes', not 'like'."
//     }
//   ];

//   // Clear existing sentences and add new ones
//   try {
//     await firestore.collection('literacycheck').doc('errorfind').set({
//       'items': errorSentences,
//     });
//     print('Successfully populated error sentences in Firebase');
//   } catch (e) {
//     print('Error populating error sentences: $e');
//   }
// }