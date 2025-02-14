import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:maps/screens/maps_home_screen.dart';
import 'package:maps/screens/signin_screen.dart';
import 'package:maps/util/app_colors.dart';

class SignUpScreen extends StatefulWidget {
  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  late FirebaseAuth _auth;
  late FirebaseFirestore _firestore;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

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
    _initializeFirebase();
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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

  Future<void> _initializeFirebase() async {
    final FirebaseApp app = await Firebase.initializeApp();
    _auth = FirebaseAuth.instanceFor(app: app);
    _firestore = FirebaseFirestore.instanceFor(app: app);
  }

  Future<void> _signUp() async {
    if (_validateFields()) {
      try {
        setState(() {
          _isLoading = true; // Show loader
        });

        UserCredential userCredential =
            await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // Store additional user information in Firestore
        await _firestore.collection('users').doc(userCredential.user?.uid).set({
          'fullName': _nameController.text.trim(),
          'email': _emailController.text.trim(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign-Up Successful!')),
        );

        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => MapsHomeScreen()));
      } catch (e) {
        print("myDebug error in signup: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_getErrorMessage(e))),
        );
      } finally {
        setState(() {
          _isLoading = false; // Hide loader
        });
      }
    }
  }

  String _getErrorMessage(Object error) {
    if (error is FirebaseAuthException) {
      return error.message.toString();
    } else {
      return 'An error occurred: ${error.toString()}';
    }
  }

  bool _validateFields() {
    if (_nameController.text.trim().isEmpty) {
      _showError('Please enter name');
      return false;
    }

    if (_emailController.text.trim().isEmpty ||
        !_isValidEmail(_emailController.text.trim())) {
      _showError('Please enter a valid email');
      return false;
    }

    if (_passwordController.text.trim().isEmpty) {
      _showError('Password cannot be empty');
      return false;
    }

    if (_confirmPasswordController.text.trim().isEmpty) {
      _showError('Confirm Password cannot be empty');
      return false;
    }

    if (_passwordController.text.trim() !=
        _confirmPasswordController.text.trim()) {
      _showError('Passwords do not match');
      return false;
    }

    return true;
  }

  bool _isValidEmail(String email) {
    final RegExp emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(email);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return AbsorbPointer(
      absorbing: _isLoading, 
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Container(
            color: Colors.transparent,
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 40.h),
                  child: Center(
                    child: Text(
                      "Get Started",
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 28.sp,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                ),
                _buildTextField(_nameController, "Full Name",
                    Icons.person_outlined, TextInputType.name),
                SizedBox(height: 16.h),
                _buildTextField(_emailController, "Email", Icons.email_outlined,
                    TextInputType.emailAddress),
                SizedBox(height: 16.h),
                _buildPasswordField(
                    _passwordController, "Password", _isPasswordVisible, (value) {
                  setState(() {
                    _isPasswordVisible = value;
                  });
                }),
                SizedBox(height: 16.h),
                _buildPasswordField(_confirmPasswordController,
                    "Confirm Password", _isConfirmPasswordVisible, (value) {
                  setState(() {
                    _isConfirmPasswordVisible = value;
                  });
                }),
                SizedBox(height: 32.h),
                _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 2.0,
                        ),
                      )
                    : ElevatedButton(
                        onPressed: _signUp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          minimumSize: Size(screenWidth, 50),
                        ),
                        child: const Text(
                          'Sign Up',
                          style: TextStyle(
                              fontSize: 16, color: AppColors.primaryText),
                        ),
                      ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Join us before? '),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => SignInScreen()));
                      },
                      child: const Text(
                        'Sign In',
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
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
                SizedBox(height: 20.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String labelText, IconData icon,
      [TextInputType keyboardType = TextInputType.text]) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.textField,
        borderRadius: BorderRadius.circular(10.sp),
      ),
      child: TextField(
        enabled: !_isLoading,
        style: TextStyle(color: AppColors.primaryText),
        controller: controller,
        cursorColor: AppColors.primary,
        decoration: InputDecoration(
          labelText: labelText,
          prefixIcon: Icon(icon, color: AppColors.primaryGrey),
          border: InputBorder.none,
        ),
        keyboardType: keyboardType,
      ),
    );
  }

  Widget _buildPasswordField(TextEditingController controller, String labelText,
      bool isVisible, ValueChanged<bool> onVisibilityToggle) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.textField,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        enabled: !_isLoading,
        style: TextStyle(color: AppColors.primaryText),
        controller: controller,
        cursorColor: AppColors.primary,
        decoration: InputDecoration(
          labelText: labelText,
          prefixIcon:
              const Icon(Icons.lock_outlined, color: AppColors.primaryGrey),
          suffixIcon: IconButton(
            color: AppColors.primaryGrey,
            icon: Icon(isVisible
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined),
            onPressed: () => onVisibilityToggle(!isVisible),
          ),
          border: InputBorder.none,
        ),
        obscureText: !isVisible,
      ),
    );
  }
}
