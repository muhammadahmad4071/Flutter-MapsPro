import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  final FlutterTts _flutterTts = FlutterTts();

  Future<void> speak(String text) async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.speak(text);
  }
}

// class VoiceGuidanceService {
//   final FlutterTts flutterTts = FlutterTts();

//   Future<void> initTTS() async {
//     await flutterTts.setLanguage("en-US");  // Change language as needed
//     await flutterTts.setPitch(1.0);         // 1.0 = Normal pitch
//     await flutterTts.setSpeechRate(0.5);    // 0.5 = Normal speaking rate
//   }

//   Future<void> speak(String text) async {
//     await flutterTts.speak(text);           // Start speaking
//   }

//   Future<void> stop() async {
//     await flutterTts.stop();                // Stop speaking
//   }
// }
