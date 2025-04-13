import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> populateParagraphs() async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  
  // List of paragraphs for reading assessment
  List<String> paragraphs = [
    "Once upon a time, there was a small village by the river. The people who lived there were very happy. They grew crops and fished in the river. Children played games in the fields all day. Everyone helped each other when there was work to be done.",
    
    "Raju woke up early in the morning. It was his first day at a new school. He was excited but also nervous. His mother packed his favorite lunch. When he reached school, he saw many children in the playground. Soon, he made new friends and had a wonderful day.",
    
    "India is a beautiful country with many different landscapes. There are tall mountains in the north. In the south, there are beaches with blue water. The east has green forests, and the west has large deserts. People in India speak many different languages and celebrate colorful festivals throughout the year.",
    
    "Books are our best friends. They tell us stories about far-away places and magical kingdoms. They teach us about history, science, and math. Reading books helps us learn new words and ideas. We can carry books anywhere and read them whenever we want.",
    
    "The mango tree in our garden is very old. Every summer, it gives us sweet, juicy mangoes. Birds make nests in its branches. The tree provides cool shade when the sun is hot. Grandfather planted this tree when he was a young boy. It is like a member of our family.",
    
    "Water is very important for all living things. People, animals, and plants all need water to survive. We should not waste water. Every drop is precious. We can save water by turning off taps when not in use. We should also keep our rivers, lakes, and ponds clean.",
    
    "Anita is a brave girl who lives in a small village. One day, she saw that the village well was very dirty. She told everyone that they should clean it. At first, nobody listened to her. But Anita did not give up. She started cleaning the well herself. Seeing this, other villagers joined her. Soon, the well was clean, and everyone had fresh water to drink.",
    
    "Farmers work very hard to grow food for all of us. They wake up early in the morning and work in their fields all day. They plant seeds, water them, and protect the plants from insects. When the crops are ready, they harvest them and send them to markets. We should respect farmers and not waste food.",
    
    "The moon looks different each night. Sometimes it is round like a ball, which we call a full moon. Other times, we can only see half of it, or just a small curved part. This happens because the moon moves around the Earth, and we can only see the part that is lit by the sun.",
    
    "Elephants are the largest land animals. They have long trunks, big ears, and sharp tusks. Elephants are very intelligent and have excellent memory. They live in families led by the oldest female elephant. Baby elephants stay close to their mothers and learn from them. Elephants are important in many Indian stories and festivals."
  ];

  // Clear existing paragraphs and add new ones
  try {
    await firestore.collection('literacycheck').doc('reading').set({
      'items': paragraphs,
    });
    print('Successfully populated paragraphs in Firebase');
  } catch (e) {
    print('Error populating paragraphs: $e');
  }
}