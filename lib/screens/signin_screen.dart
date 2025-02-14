import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:maps/screens/no_internet.dart';
import 'package:maps/screens/signup_screen.dart';
import 'maps_home_screen.dart';
import 'package:maps/util/app_colors.dart';

class SignInScreen extends StatefulWidget {
  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  late FirebaseAuth _auth;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // To toggle visibility of password
  bool _isPasswordVisible = false;

  bool _isLoading = false;

  bool isInternetConnected = true;
  List<ConnectivityResult> _connectionStatus = [ConnectivityResult.none];
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    initConnectivity();
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
    _initializeFirebaseAuth();
  }

  Future<void> initConnectivity() async {
    List<ConnectivityResult> result;

    try {
      result = await _connectivity.checkConnectivity();
    } on PlatformException catch (e) {
      print("Connectivity error: $e");
      return;
    }

    // Update the UI based on the connectivity result
    if (!mounted) return;

    _updateConnectionStatus(result);
  }

  Future<void> _updateConnectionStatus(List<ConnectivityResult> result) async {
    setState(() {
      _connectionStatus = result;

      // Check if any connectivity result is either wifi or mobile
      isInternetConnected = result.contains(ConnectivityResult.wifi) ||
          result.contains(ConnectivityResult.mobile);
    });

    print('Connectivity changed: $_connectionStatus bool $isInternetConnected');
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _initializeFirebaseAuth() async {
    // Initialize a specific Firebase app instance
    final FirebaseApp app = await Firebase.initializeApp();
    _auth = FirebaseAuth.instanceFor(app: app);
  }

  // Function to handle sign-in logic
  Future<void> _signIn() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all fields.')),
      );
      return;
    }

    try {
      setState(() {
        _isLoading = true; // Show loader
      });
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(content: Text('Sign-In Successful!')),
      // );
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => MapsHomeScreen()));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_getErrorMessage(e))),
      );
    } finally {
      setState(() {
        _isLoading = false; // Hide loader
      });
    }
  }

  String _getErrorMessage(Object error) {
    if (error is FirebaseAuthException) {
      return error.message.toString();
    } else {
      return 'An error occurred: ${error.toString()}';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isInternetConnected) {
      return NoInternetWidget();
    }
    double screenWidth = MediaQuery.of(context).size.width;
    return AbsorbPointer(
      absorbing: _isLoading, 
      child: Scaffold(
         resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Container(
            color: Colors.white,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.h),
                    child: Center(
                        child: Text(
                      "Welcome Back",
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 28.sp,
                        color: AppColors.primaryText,
                      ),
                    )),
                  ),
      
                  // Email TextField
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.textField, // Set background color
                      borderRadius:
                          BorderRadius.circular(10), // 10-pixel corner radius
                    ),
                    child: TextField(
                      enabled: !_isLoading,
                      controller: _emailController, // Email controller
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined), // Left-side icon
                        border: InputBorder.none, // No border
                      ),
                      keyboardType: TextInputType.emailAddress, // Email keyboard
                    ),
                  ),
                  SizedBox(height: 16.h),
      
                  // Password TextField with show/hide icon and rounded corners
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.textField, // Set background color
                      borderRadius:
                          BorderRadius.circular(10), // 10-pixel corner radius
                    ),
                    child: TextField(
                      enabled: !_isLoading,
                      controller: _passwordController, // Password controller
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outlined), // Left-side icon
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                        border: InputBorder.none, // No border
                      ),
                      obscureText: !_isPasswordVisible, // Show/Hide password
                    ),
                  ),
      
                  // Submit Button
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.h),
                    child: _isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                              strokeWidth: 2.0,
                            ),
                          )
                        : ElevatedButton(
                            onPressed: () {
                              _signIn();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 40.w,
                                  vertical: 15.h), // Add padding for size
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    10.sp), // Set the radius for rounded corners
                              ),
                              minimumSize: Size(screenWidth, 50.sp),
                            ),
                            child: Text(
                              'Sign In',
                              style: TextStyle(
                                  fontSize: 16.sp, color: AppColors.primaryText),
                            ),
                          ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Don\'t have an account? ',
                        style: TextStyle(fontSize: 16.sp),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => SignUpScreen()));
                        },
                        child: Text(
                          'Sign Up',
                          style: TextStyle(
                            fontSize: 16.sp,
                            color:
                                Colors.blue, // Blue color for the "Sign In" text
                          ),
                        ),
                      ),
                    ],
                  ),
                  Spacer(),
                  Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Continue as a ',
                      style: TextStyle(
                          fontSize: 14.sp, color: AppColors.primaryGrey),
                    ),
                    GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => MapsHomeScreen()));
                        },
                        child: Text(
                          'Guest',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14.sp,
                            color:
                                Colors.blue, // Blue color for the "Sign In" text
                          ),
                        )),
                  ],
                ),
                  
                  SizedBox(height: 20.h)
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
