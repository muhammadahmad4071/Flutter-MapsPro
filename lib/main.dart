import 'package:firebase_auth/firebase_auth.dart';
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
    DeviceOrientation.portraitUp,
  ]);
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Future<bool>? _userStatusFuture;

  @override
  void initState() {
    super.initState();
    _userStatusFuture = _checkUserStatus();
  }

  // Check if the user is logged in and if they have seen the onboarding screen
  Future<bool> _checkUserStatus() async {
    try {
      // await FirebaseAuth.instance.signOut();

      FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user == null) {
          print('myDebug User is signed out!');
        } else {
          print('myDebug client side authentication User is signed in!');
        }
      });

      bool loggedIn = FirebaseAuth.instance.currentUser != null;
      print("myDebug Auto Login on Main $loggedIn");
      
      return loggedIn;
    } catch (e) {
      // Show error if unable to check user status
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to AutoLogin, Please login again')),
      );
      // After showing the error, navigate to the OnBoardScreen
      Future.delayed(Duration(seconds: 2), () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => OnBoardScreen()),
        );
      });
      return false;
    }
  }

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
          home: FutureBuilder<bool>(
            future: _userStatusFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError ||
                  !snapshot.hasData ||
                  !snapshot.data!) {
                return OnBoardScreen();
              } else {
                return MapsHomeScreen();
              }
            },
          ),
        );
      },
    );
  }
}
