import 'dart:async';
import 'dart:ui';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:maps/screens/maps_home_screen.dart';
import 'package:maps/screens/on_board_screen.dart';
import 'package:maps/screens/signup_screen.dart';
import 'package:maps/util/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

   FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };
    // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
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
  bool _isSplashVisible = true; // Track if splash screen should be visible
  bool hasSeenOnboarding = false;

  @override
  void initState() {
    super.initState();

    // Show splash screen for 3 seconds
    Timer(Duration(seconds: 3), () {
      setState(() {
        _isSplashVisible = false;
        // Uncomment to implement signin onboard and signup
        // _userStatusFuture = _checkUserStatus(); // Load user status after splash
      });
    });
  }

  // Check if the user is logged in and if they have seen the onboarding screen
  Future<bool> _checkUserStatus() async {
    try {
    
      SharedPreferences prefs = await SharedPreferences.getInstance();
      hasSeenOnboarding = prefs.getBool('onboarding_seen') ?? false;
      debugPrint("myDebug test hasSeenOnboarding: $hasSeenOnboarding");
      FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user == null) {
          debugPrint('myDebug User is signed out!');
        } else {
          print('myDebug client-side authentication User is signed in!');
        }
      });

      bool loggedIn = FirebaseAuth.instance.currentUser != null;
      print("myDebug Auto Login on Main $loggedIn");
      return loggedIn;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to AutoLogin, Please login again')),
      );
      Future.delayed(Duration(seconds: 2), () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  hasSeenOnboarding ? SignUpScreen() : OnBoardScreen()),
        );
      });
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Maps App',
          theme: ThemeData(
            primaryColor: AppColors.primary,
            colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
            useMaterial3: true,
          ),
          home: _isSplashVisible
              ? _buildSplashScreen() // Show splash screen first
              : MapsHomeScreen()
              // Uncomment to implement signin onboard and signup
              // FutureBuilder<bool>(
              //     future: _userStatusFuture,
              //     builder: (context, snapshot) {
              //       if (snapshot.connectionState == ConnectionState.waiting) {
              //         return _buildSplashScreen();
              //       } else if (snapshot.hasError ||
              //           !snapshot.hasData ||
              //           !snapshot.data!) {
              //         return hasSeenOnboarding
              //             ? SignUpScreen()
              //             : OnBoardScreen();
              //       } else {
              //         return MapsHomeScreen();
              //       }
              //     },
              //   ),
        );
      },
    );
  }

  // Splash Screen Widget
  
  Widget _buildSplashScreen() {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      body: SafeArea(
        child: Container(
          margin: EdgeInsets.only(bottom: 10.h),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(
                                  28.r), // Adjust for desired roundness
                              topRight: Radius.circular(28.r),
                              bottomLeft: Radius.circular(28.r),
                              bottomRight: Radius.circular(28.r),
                            ),),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/logo.png', // Replace with your logo
                  height: 120.h,
                ),
                SizedBox(height: 100.h),
                SpinKitFadingCircle(
                  color: AppColors.primary,
                  size: 50.0.sp,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
