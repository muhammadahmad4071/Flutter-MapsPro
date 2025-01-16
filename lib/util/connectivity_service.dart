// import 'dart:async';
// import 'package:connectivity_plus/connectivity_plus.dart';

// class ConnectivityService {
//   final Connectivity _connectivity = Connectivity();
//   late StreamSubscription<ConnectivityResult> _connectivitySubscription;
//   bool isInternetConnected = true;

//   // Singleton pattern
//   static final ConnectivityService _instance = ConnectivityService._internal();
//   factory ConnectivityService() => _instance;
//   ConnectivityService._internal();

//   // Callback to notify about connection changes
//   Function(bool isConnected)? onConnectionChanged;

//   void initialize() {
//     // Start listening to connectivity changes
//     _connectivitySubscription =
//         _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);

//     // Initial connectivity check
//     _checkInitialConnectivity();
//   }

//   Future<void> _checkInitialConnectivity() async {
//     try {
//       ConnectivityResult result = await _connectivity.checkConnectivity();
//       _updateConnectionStatus(result);
//     } catch (e) {
//       print("Connectivity error: $e");
//     }
//   }

//   void _updateConnectionStatus(ConnectivityResult result) {
//     bool connected =
//         result == ConnectivityResult.wifi || result == ConnectivityResult.mobile;

//     // Notify listeners only if the connection state changes
//     if (connected != isInternetConnected) {
//       isInternetConnected = connected;
//       onConnectionChanged?.call(isInternetConnected);
//     }
//   }

//   void dispose() {
//     _connectivitySubscription.cancel();
//   }
// }
