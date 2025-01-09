import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:maps/screens/maps_home_screen.dart';
import 'package:maps/screens/on_board_screen.dart';
import 'package:maps/util/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp, // Locks to portrait mode
    // DeviceOrientation.landscapeLeft, // Uncomment for landscape mode
    // DeviceOrientation.landscapeRight, // Uncomment for landscape mode
  ]).then((_) {
    runApp(MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812), // Set your design dimensions
      minTextAdapt: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'Maps App',
          theme: ThemeData(
            primaryColor: AppColors.primary, // Set the primary color
            colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
            useMaterial3: true,
          ),
          home: MapsHomeScreen(),
          // home: OnBoardScreen(),
        );
      },
    );
  }
}
