// import 'dart:async';
// import 'dart:convert';
// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_polyline_points/flutter_polyline_points.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:google_maps_webservice/directions.dart';
// import 'package:google_maps_webservice/places.dart';
// import 'package:http/http.dart' as http;
// import 'package:maps/screens/no_internet.dart';
// import 'package:maps/util/app_colors.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;
// import 'package:google_maps_flutter/google_maps_flutter.dart';

// class MapsHomeScreen extends StatefulWidget {
//   const MapsHomeScreen({super.key});

//   @override
//   State<MapsHomeScreen> createState() => _MapsHomeScreenState();
// }

// class _MapsHomeScreenState extends State<MapsHomeScreen> {
//   static const myApiKey = "AIzaSyBsVw09Zl_Xby65X7ed8Xs2ov8aAhaWiFk";
//   late GoogleMapController mapController;
//   late LatLng _initialPosition;
//   Marker? _startingMarker;
//   Marker? _destinationMarker;
//   TextEditingController _searchController = TextEditingController();
//   final GoogleMapsPlaces _places = GoogleMapsPlaces(apiKey: myApiKey);
//   final GoogleMapsDirections _directions =
//       GoogleMapsDirections(apiKey: myApiKey);
//   Set<maps.Polyline> _polylines = {};
//   List<Prediction> _predictions = [];
//   late Prediction _prediction;
//   bool isLoading = true;
//   String? countryCode;
//   bool showBottomSheet = false;
//   String? distanceText;
//   String? durationText;
//   bool hasLocationPermission = false;
//   bool isInternetConnected = true;
//   List<ConnectivityResult> _connectionStatus = [ConnectivityResult.none];
//   final Connectivity _connectivity = Connectivity();
//   late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

//   @override
//   void initState() {
//     super.initState();
//     _initializeApp();
//     initConnectivity();
//     _connectivitySubscription =
//         _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
//   }

//   Future<void> initConnectivity() async {
//     List<ConnectivityResult> result;

//     try {
//       result = await _connectivity.checkConnectivity();
//     } on PlatformException catch (e) {
//       print("Connectivity error: $e");
//       return;
//     }

//     // Update the UI based on the connectivity result
//     if (!mounted) return;

//     _updateConnectionStatus(result);
//   }

//   Future<void> _updateConnectionStatus(List<ConnectivityResult> result) async {
//     setState(() {
//       _connectionStatus = result;

//       // Check if any connectivity result is either wifi or mobile
//       isInternetConnected = result.contains(ConnectivityResult.wifi) ||
//           result.contains(ConnectivityResult.mobile);
//     });

//     print('Connectivity changed: $_connectionStatus bool $isInternetConnected');
//   }

//   @override
//   void dispose() {
//     // Don't forget to cancel the subscription when the widget is disposed
//     _connectivitySubscription.cancel();
//     mapController.dispose();
//     super.dispose();
//   }

//   void _onMapCreated(GoogleMapController controller) {
//     mapController = controller;
//     setState(() {
//       isLoading = false;
//     });
//   }

//   Future<bool> _initializeApp() async {
//     bool permissionGranted = await _checkLocationPermission();
//     if (permissionGranted) {
//       // await _initializeUserLocation();
//       return await _initializeUserLocation(); // Initialization successful
//     }
//     return false; // Initialization failed (e.g., no permission)
//   }

//   // Future<void> _initializeApp() async {
//   //   // Check location permissions and initialize user location
//   //   bool permissionGranted = await _checkLocationPermission();
//   //   if (permissionGranted) {
//   //     await _initializeUserLocation();
//   //   } else {
//   //     // setState(() => isLoading = false); // Stop loading if no permission
//   //   }
//   //   debugPrint("myDebug isLoading _initializeApp() $isLoading");
//   // }

//   Future<bool> _checkLocationPermission() async {
//     LocationPermission permission = await Geolocator.requestPermission();

//     if (permission == LocationPermission.denied ||
//         permission == LocationPermission.deniedForever) {
//       setState(() {
//         hasLocationPermission = false;
//         // isLoading = false;
//         // debugPrint("myDebug isLoading _checkLocationPermission() $isLoading");
//       });
//       return false;
//     } else {
//       setState(() {
//         hasLocationPermission = true;
//       });
//       return true;
//     }
//   }

//   Future<bool> _initializeUserLocation() async {
//     try {
//       // setState(() {
//       //   isLoading = true;
//       // });
//       final position = await Geolocator.getCurrentPosition();
//       final BitmapDescriptor customIcon = await getCustomIcon();
//       final userLatLng = LatLng(position.latitude, position.longitude);

//       setState(() {
//         _initialPosition = userLatLng;
//         _startingMarker = Marker(
//           icon: customIcon,
//           markerId: const MarkerId('userLocation'),
//           position: userLatLng,
//           infoWindow: const InfoWindow(title: "Your Current Location"),
//         );
//         // isLoading = false; // Stop loading
//         // debugPrint("myDebug isLoading _initializeUserLocation() $isLoading");
//       });

//       countryCode = await getCountryCode(userLatLng);
//       mapController.animateCamera(CameraUpdate.newLatLng(userLatLng));
//       return true;
//     } catch (e) {
//       debugPrint("myDebug Error retrieving location: $e");
//       return false;
//       // setState(() => isLoading = false);
//     }
//   }

//   Future<void> _moveToUserLocation() async {
//     try {
//       if (!hasLocationPermission) {
//         debugPrint("Permission not granted. Cannot move to location.");
//         return;
//       }

//       final position = await Geolocator.getCurrentPosition();
//       final userLatLng = LatLng(position.latitude, position.longitude);
//       mapController.animateCamera(CameraUpdate.newLatLng(userLatLng));
//     } catch (e) {
//       debugPrint("Error moving to location: $e");
//     }
//   }

//   void _searchCities(String query) async {
//     if (query.isEmpty) {
//       setState(() {
//         _predictions = [];
//       });
//       return;
//     }

//     // if(countryCode!.isNotEmpty){
//     final response = await _places.autocomplete(
//       query,
//       // types: ['(cities)'], // Restrict to cities
//       components: [Component(Component.country, countryCode.toString())],
//     );
//     // }

//     if (response.isOkay) {
//       setState(() {
//         _predictions = response.predictions;
//       });
//     } else {
//       debugPrint("Places API error: ${response.errorMessage}");
//     }
//   }

//   Future<String?> getCountryCode(LatLng userCoordinates) async {
//     try {
//       // Get the nearest place details using the Places API reverse geocode
//       final response = await _places.searchNearbyWithRadius(
//         Location(lat: userCoordinates.latitude, lng: userCoordinates.longitude),
//         50, // 50 meters radius for higher accuracy
//       );

//       if (response.isOkay && response.results.isNotEmpty) {
//         final placeId = response.results.first.placeId;

//         // if (placeId != null) {
//         // Fetch place details to extract country code
//         final placeDetailsResponse = await _places.getDetailsByPlaceId(placeId);

//         if (placeDetailsResponse.isOkay) {
//           final addressComponents =
//               placeDetailsResponse.result.addressComponents;

//           // Extract the country code
//           final countryComponent = addressComponents.firstWhere(
//             (component) => component.types.contains('country'),
//             orElse: () =>
//                 AddressComponent(longName: '', shortName: '', types: []),
//           );
//           print("myDebug country ${countryComponent.shortName}");
//           return countryComponent.shortName; // Return the ISO country code
//         }
//         // }
//       }
//       return null; // Return null if no country found
//     } catch (e) {
//       print('Error fetching country code: $e');
//       return null;
//     }
//   }

//   // String getCityTitle(Prediction prediction) {
//   //   String description = prediction.description ?? '';
//   //   return description.split(',')[0]; // Extract the first part
//   // }

//   Future<BitmapDescriptor> getCustomIcon() async {
//     return await BitmapDescriptor.asset(
//       ImageConfiguration(size: Size(24.w, 24.h)), // Specify desired size
//       'assets/current_location_marker.png',
//       // 'assets/anim_location.gif',21302130
//     );
//   }

//   void _selectCity(Prediction prediction) async {
//     setState(() {
//       _predictions.clear();
//     });
//     // void _selectCity(Prediction prediction) async {
//     final placeDetails = await _places.getDetailsByPlaceId(prediction.placeId!);
//     if (placeDetails.isOkay) {
//       final location = placeDetails.result.geometry!.location;
//       final cityPosition = LatLng(location.lat, location.lng);

//       // Retrieve user's current location
//       final userPosition = _initialPosition;
//       getRoutesAndDrawPolylines(_initialPosition, cityPosition);

//       // Fetch distance and duration from Directions API
//       final directionsResponse =
//           await _fetchDirections(userPosition, cityPosition);
//       distanceText = directionsResponse['distanceText'];
//       durationText = directionsResponse['durationText'];

//       setState(() {
//         _prediction = prediction;
//         _destinationMarker = Marker(
//           markerId: const MarkerId('cityLocation'),
//           position: cityPosition,
//           infoWindow: InfoWindow(title: prediction.description),
//         );
//         showBottomSheet = true;
//       });

//       mapController.animateCamera(CameraUpdate.newLatLngZoom(cityPosition, 14));

//       // Dismiss the keyboard when a city is selected
//       FocusScope.of(context).unfocus();

//       // _predictions = [];
//     } else {
//       debugPrint("Error fetching place details: ${placeDetails.errorMessage}");
//       setState(() {
//         showBottomSheet = false;
//       });
//     }
//   }

//   Future<Map<String, String>> _fetchDirections(
//       LatLng origin, LatLng destination) async {
//     final directionsUrl =
//         'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&key=AIzaSyBsVw09Zl_Xby65X7ed8Xs2ov8aAhaWiFk';
//     print("Distance Function: $directionsUrl");
//     try {
//       final response = await http.get(Uri.parse(directionsUrl));
//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         final route = data['routes'][0];
//         final legs = route['legs'][0];

//         final distanceText = legs['distance']['text'];
//         final durationText = legs['duration']['text'];

//         return {'distanceText': distanceText, 'durationText': durationText};
//       } else {
//         throw Exception('Failed to load directions');
//       }
//     } catch (e) {
//       debugPrint('Error fetching directions: $e');
//       return {'distanceText': 'N/A', 'durationText': 'N/A'};
//     }
//   }

//   Future<void> getRoutesAndDrawPolylines(
//       LatLng origin, LatLng destination) async {
//     try {
//       final directionsResponse = await _directions.directions(
//         Location(lat: origin.latitude, lng: origin.longitude),
//         Location(lat: destination.latitude, lng: destination.longitude),
//         alternatives: true,
//       );

//       if (directionsResponse.isOkay) {
//         // Clear previous polylines
//         _polylines.clear();

//         PolylinePoints polylinePoints = PolylinePoints();
//         double shortestDistance = double.infinity;
//         Map<String, dynamic>? shortestRoute;

//         for (var route in directionsResponse.routes) {
//           final encodedPolyline = route.overviewPolyline.points;
//           final decodedPoints = polylinePoints.decodePolyline(encodedPolyline);
//           final polylineLatLng = decodedPoints
//               .map((point) => LatLng(point.latitude, point.longitude))
//               .toList();

//           final routeDistance = route.legs[0].distance.value;

//           // Find the shortest route
//           if (routeDistance < shortestDistance) {
//             shortestDistance = routeDistance.toDouble();
//             shortestRoute = route.toJson();
//           }

//           // Create a unique polyline for each route
//           final polylineId = PolylineId(route.summary);
//           _polylines.add(maps.Polyline(
//             polylineId: polylineId,
//             points: polylineLatLng,
//             color: Colors.grey,
//             width: 5,
//             onTap: () => _onRouteSelected(
//                 route.toJson(), polylineId), // Ensure onTap works here
//           ));
//         }

//         // Highlight shortest route
//         if (shortestRoute != null) {
//           _onRouteSelected(shortestRoute, PolylineId(shortestRoute['summary']));
//         }
//       } else {
//         print('Error fetching directions: ${directionsResponse.errorMessage}');
//       }
//       //  setState(() {

//       // });
//     } catch (e) {
//       print('Error fetching directions: $e');
//     }
//   }

//   void _onRouteSelected(Map<String, dynamic> route, PolylineId polylineId) {
//     setState(() {
//       print("Tapped on Polyline: $polylineId");

//       // Reset all polyline colors to grey
//       _polylines = _polylines.map((polyline) {
//         return polyline.copyWith(colorParam: Colors.grey, widthParam: 5);
//       }).toSet();

//       // Find the selected polyline and change its color to blue
//       final selectedPolyline = _polylines.firstWhere(
//         (polyline) => polyline.polylineId == polylineId,
//       );

//       _polylines.remove(selectedPolyline);

//       _polylines.add(
//         // selectedPolyline.copyWith(colorParam: Colors.blue, widthParam: 8),
//         selectedPolyline.copyWith(colorParam: AppColors.primary, widthParam: 8),
//       );

//       // Update the distance and duration for the selected route
//       // final legs = route['legs'][0];
//       // distanceText = legs['distance']['text'];
//       // durationText = legs['duration']['text'];
//       // setState(() {

//       // });

//       print("Selected Route: ${route['summary']}");
//     });
//   }

//   Widget showCircularProgressLoader() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           CircularProgressIndicator(),
//           SizedBox(height: 20.sp),
//           Text(
//             "Loading Maps...",
//             textAlign: TextAlign.center,
//             style: TextStyle(
//               fontWeight: FontWeight.w500,
//               color: AppColors.primaryText,
//               fontSize: 14.sp,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget showMaps() {
//     return isLoading ?  GestureDetector(
//       onTap: () {
//         // Unfocus to dismiss the keyboard
//         FocusScope.of(context).unfocus();
//       },
//       child: Stack(
//         children: [
//           GoogleMap(
//             compassEnabled: false,
//             mapType: MapType.terrain,
//             initialCameraPosition: CameraPosition(
//               target: _initialPosition,
//               zoom: 14,
//             ),
//             onMapCreated: _onMapCreated,
//             markers: {
//               if (_startingMarker != null) _startingMarker!,
//               if (_destinationMarker != null) _destinationMarker!,
//             },
//             polylines: _polylines,
//             trafficEnabled: true,
//           ),
//           Container(
//             margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(50),
//             ),
//             child: TextField(
//               controller: _searchController,
//               onChanged: _searchCities,
//               style: const TextStyle(color: Colors.black),
//               cursorColor: Colors.blue,
//               decoration: const InputDecoration(
//                 labelText: "Search",
//                 prefixIcon: Icon(Icons.search, color: Colors.grey),
//                 border: InputBorder.none,
//               ),
//               keyboardType: TextInputType.streetAddress,
//             ),
//           ),
//           Positioned(
//             top: 100.h,
//             right: 30.w,
//             child: Container(
//               color: Colors.white.withAlpha(230),
//               height: 36.h,
//               width: 36.w,
//               child: Center(
//                 child: IconButton(
//                   iconSize: 22.sp,
//                   color: AppColors.primaryGrey,
//                   onPressed: _moveToUserLocation,
//                   icon: Icon(Icons.my_location_outlined),
//                 ),
//               ),
//             ),
//           ),
//           if (_predictions.isNotEmpty)
//             Container(
//               margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 80.h),
//               color: Colors.white,
//               child: ListView.builder(
//                 shrinkWrap: true,
//                 itemCount: _predictions.length,
//                 itemBuilder: (context, index) {
//                   final prediction = _predictions[index];
//                   return ListTile(
//                     title: Text(prediction.description ?? ''),
//                     onTap: () {
//                       _searchController.text =
//                           prediction.structuredFormatting?.mainText ??
//                               _searchController.text;
//                       _selectCity(prediction);
//                     },
//                   );
//                 },
//               ),
//             ),
//         ],
//       ),
//     ) : showCircularProgressLoader();
//   }

//   Widget showPermissionScreen() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(
//             Icons.location_off,
//             size: 80.sp,
//             color: Colors.grey,
//           ),
//           SizedBox(height: 20.sp),
//           Text(
//             "Please allow location permissions\nto use the app",
//             textAlign: TextAlign.center,
//             style: TextStyle(
//               fontSize: 16.sp,
//               color: Colors.grey,
//             ),
//           ),
//           SizedBox(height: 20.sp),
//           ElevatedButton(
//             onPressed: () async {
//               await Geolocator.openAppSettings();
//               await Geolocator.openLocationSettings();
//               _checkLocationPermission();
//             },
//             style: ElevatedButton.styleFrom(
//               backgroundColor: AppColors.primary,
//               padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 15.h),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(50.sp),
//               ),
//             ),
//             child: Text(
//               'Grant Permissions',
//               style: TextStyle(fontSize: 16.sp, color: AppColors.primaryText),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget bottomSheetDesign() {
//     return showBottomSheet
//         ? Container(
//             child: Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Row(
//                     crossAxisAlignment: CrossAxisAlignment.center,
//                     children: [
//                       Icon(Icons.access_time_filled,
//                           color: AppColors.dividerGrey),
//                       SizedBox(width: 5.w),
//                       Padding(
//                         padding: EdgeInsets.only(top: 3.h),
//                         child: Text(
//                           durationText ?? "N/A",
//                           style: TextStyle(
//                               fontSize: 14.sp, color: AppColors.primaryGrey),
//                           textAlign: TextAlign.center,
//                         ),
//                       ),
//                     ],
//                   ),
//                   Row(
//                     crossAxisAlignment: CrossAxisAlignment.center,
//                     children: [
//                       Icon(Icons.location_pin, color: AppColors.dividerGrey),
//                       SizedBox(width: 5.w),
//                       Padding(
//                         padding: EdgeInsets.only(top: 3.h),
//                         child: Text(
//                           distanceText.toString(),
//                           style: TextStyle(
//                               fontSize: 14.sp, color: AppColors.primaryGrey),
//                           textAlign: TextAlign.center,
//                         ),
//                       ),
//                     ],
//                   ),
//                   Divider(color: AppColors.textField),
//                   Text(
//                     _prediction.structuredFormatting?.mainText ?? "N/A",
//                     style: TextStyle(
//                       fontSize: 20.sp,
//                       color: AppColors.primaryText,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   SizedBox(height: 10.h),
//                   Text(
//                     '${_prediction.description}',
//                     style: TextStyle(
//                       fontSize: 14.sp,
//                       color: AppColors.dividerGrey,
//                     ),
//                   ),
//                   SizedBox(height: 20),
//                   ElevatedButton(
//                     onPressed: () {
//                       // Handle start button click
//                     },
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: AppColors.primary,
//                       padding: EdgeInsets.symmetric(
//                           horizontal: 40.w, vertical: 15.h),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(50.sp),
//                       ),
//                       minimumSize:
//                           Size(MediaQuery.of(context).size.width, 50.sp),
//                     ),
//                     child: Text(
//                       'Start',
//                       style: TextStyle(
//                           fontSize: 16.sp, color: AppColors.primaryText),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           )
//         : SizedBox();
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (!isInternetConnected) {
//       return NoInternetWidget();
//     }

//     return FutureBuilder<bool>(
//     future: _initializeUserLocation(), // Initialize app and check permissions
//     builder: (context, snapshot) {
//       if (snapshot.connectionState == ConnectionState.waiting) {
//         // Show loader while initializing
//         return SafeArea(
//           child: Scaffold(
//             body: showCircularProgressLoader(),
//           ),
//         );
//       }

//       if (snapshot.data == true && !hasLocationPermission) {
//         // Handle error or missing permissions
//         return SafeArea(
//           child: Scaffold(
//             body: showPermissionScreen(),
//           ),
//         );
//       }

//       if (snapshot.data == true) {
//         // Handle error or missing permissions
//         return SafeArea(
//           child: Scaffold(
//             body: showPermissionScreen(),
//           ),
//         );
//       }

//       // Show the map when initialization is successful
//       return SafeArea(
//         child: Scaffold(
//           resizeToAvoidBottomInset: false,
//           body: showMaps(),
//           bottomSheet: bottomSheetDesign(),
//         ),
//       );
//     },
//   );

//   //   return SafeArea(
//   //     child: Scaffold(
//   //         resizeToAvoidBottomInset: false,
//   //         body: hasLocationPermission
//   //             ? isLoading
//   //                 ? showMaps()
//   //                 : showCircularProgressLoader()
//   //             : showPermissionScreen(),
//   //         bottomSheet: bottomSheetDesign()),
//   //   );
//   // }
// }
// }




// // Commented backed up functions
// // Select City Working
// // void _selectCity(Prediction prediction) async {
// //   final placeDetails = await _places.getDetailsByPlaceId(prediction.placeId!);
// //   if (placeDetails.isOkay) {
// //     final location = placeDetails.result.geometry!.location;
// //     final cityPosition = LatLng(location.lat, location.lng);

// //     setState(() {
// //       _userMarker = Marker(
// //         markerId: const MarkerId('cityLocation'),
// //         position: cityPosition,
// //         infoWindow: InfoWindow(title: prediction.description),
// //       );
// //     });

// //     mapController.animateCamera(CameraUpdate.newLatLngZoom(cityPosition, 14));

// //     // Dismiss the keyboard when a city is selected
// //     FocusScope.of(context).unfocus();

// //     // Show the Bottom Sheet with the details
// //     showModalBottomSheet(
// //       backgroundColor: Colors.white,
// //       context: context,
// //       isScrollControlled: true,  // To ensure the bottom sheet can expand
// //       builder: (BuildContext context) {
// //         return           Padding(
// //           padding: const EdgeInsets.all(16.0),
// //           child: Column(
// //             mainAxisSize: MainAxisSize.min,
// //             crossAxisAlignment: CrossAxisAlignment.start,
// //             children: [
// //               Row(
// //                 crossAxisAlignment: CrossAxisAlignment.center,
// //                 children: [
// //                 Icon(Icons.access_time_filled, color: AppColors.dividerGrey,),
// //                 SizedBox(width: 5.w,),
// //                 Padding(
// //                   padding: EdgeInsets.only(top: 3.h),
// //                   child: Text("10 Min", style: TextStyle(fontSize: 14.sp, color: AppColors.primaryGrey), textAlign: TextAlign.center,),
// //                 )
// //               ]),
// //               Row(
// //                 crossAxisAlignment: CrossAxisAlignment.center,
// //                 children: [
// //                 Icon(Icons.location_pin, color: AppColors.dividerGrey,),
// //                 SizedBox(width: 5.w,),
// //                 Padding(
// //                   padding: EdgeInsets.only(top: 3.h),
// //                   child: Text('${prediction.distanceMeters}', style: TextStyle(fontSize: 14.sp, color: AppColors.primaryGrey), textAlign: TextAlign.center,),
// //                 )
// //               ]),
// //               Divider(color: AppColors.textField,),
// //               Text(
// //                 '${prediction.id}',
// //                 style: TextStyle(
// //                   fontSize: 20.sp,
// //                   color: AppColors.primaryText,
// //                   fontWeight: FontWeight.bold,
// //                 ),
// //               ),
// //               SizedBox(height: 10.h),
// //               Text(
// //                 '${prediction.description}',
// //                 style: TextStyle(
// //                   fontSize: 14.sp,
// //                   color: AppColors.dividerGrey,
// //                 ),
// //               ),
// //               SizedBox(height: 20),
// //               ElevatedButton(
// //                   onPressed: (){
// //                     // _signIn();
// //                   },
// //                   style: ElevatedButton.styleFrom(
// //                     backgroundColor: AppColors.primary,
// //                     padding: EdgeInsets.symmetric(
// //                         horizontal: 40.w,
// //                         vertical: 15.h),
// //                     shape: RoundedRectangleBorder(
// //                       borderRadius: BorderRadius.circular(
// //                           50.sp),
// //                     ),
// //                     minimumSize: Size(MediaQuery.of(context).size.width, 50.sp),
// //                   ),
// //                   child: Text(
// //                     'Start',
// //                     style: TextStyle(
// //                         fontSize: 16.sp, color: AppColors.primaryText),
// //                   ),
// //                 ),
// //             ],
// //           ),
// //         );
// //       },
// //     );

// //     // _searchController.clear();
// //     _predictions = [];
// //   } else {
// //     debugPrint("Error fetching place details: ${placeDetails.errorMessage}");
// //   }
// // }

// // Future<void> getRoutesAndDrawPolylines(
// //     LatLng origin, LatLng destination) async {
// //   try {
// //     // Request directions
// //     final directionsResponse = await _directions.directions(
// //       Location(lat: origin.latitude, lng: origin.longitude),
// //       Location(lat: destination.latitude, lng: destination.longitude),
// //       alternatives: true, // Get alternative routes
// //     );

// //     if (directionsResponse.isOkay) {
// //       // Clear previous polylines
// //       _polylines.clear();

// //       // Initialize PolylinePoints for decoding polyline strings
// //       PolylinePoints polylinePoints = PolylinePoints();

// //       // Find the shortest route by comparing distances
// //       int shortestRouteIndex = 0;
// //       double shortestDistance = double.infinity;

// //       for (int i = 0; i < directionsResponse.routes.length; i++) {
// //         final route = directionsResponse.routes[i];
// //         final distance = route.legs[0].distance.value;

// //         if (distance < shortestDistance) {
// //           shortestDistance = distance.toDouble();
// //           shortestRouteIndex = i;
// //         }
// //       }

// //       // Draw polylines for all routes
// //       for (int i = 0; i < directionsResponse.routes.length; i++) {
// //         final route = directionsResponse.routes[i];
// //         final encodedPolyline = route.overviewPolyline.points;

// //         // Decode polyline
// //         final decodedPoints = polylinePoints.decodePolyline(encodedPolyline);
// //         final polylineLatLng = decodedPoints
// //             .map((point) => LatLng(point.latitude, point.longitude))
// //             .toList();

// //         // Determine polyline color
// //         final color = (i == shortestRouteIndex) ? Colors.blue : Colors.grey;

// //         // Add polyline to the map
// //         final polylineId = PolylineId(route.summary);
// //         _polylines.add(maps.Polyline(
// //           polylineId: polylineId,
// //           points: polylineLatLng,
// //           color: color,
// //           width: 5,
// //           onTap: () => _onRouteSelected(route, polylineId),
// //         ));
// //       }

// //       // Set shortest route as selected initially
// //       _onRouteSelected(
// //         directionsResponse.routes[shortestRouteIndex],
// //         PolylineId(directionsResponse.routes[shortestRouteIndex].summary),
// //       );
// //     } else {
// //       print('Error fetching directions: ${directionsResponse.errorMessage}');
// //     }
// //   } catch (e) {
// //     print('Error fetching directions: $e');
// //   }
// // }

// // void _onRouteSelected(DirectionsRoute route, PolylineId polylineId) {
// //   // Highlight selected polyline
// //   setState(() {
// //     _polylines = _polylines.map((polyline) {
// //       if (polyline.polylineId == polylineId) {
// //         return polyline.copyWith(colorParam: Colors.blue);
// //       }
// //       return polyline.copyWith(colorParam: Colors.grey);
// //     }).toSet();

// //     // Update distance and duration
// //     final legs = route.legs[0];
// //     distanceText = legs.distance.text;
// //     durationText = legs.duration.text;
// //   });

// //   print("Selected Route: ${route.summary}");
// // }


//   // Future<void> getRoutesAndDrawPolylines(
//   //     LatLng origin, LatLng destination) async {
//   //   try {
//   //     // Request directions
//   //     final directionsResponse = await _directions.directions(
//   //       Location(lat: origin.latitude, lng: origin.longitude),
//   //       Location(lat: destination.latitude, lng: destination.longitude),
//   //       alternatives: true, // Set to true to get alternative routes
//   //     );

//   //     if (directionsResponse.isOkay) {
//   //       // Clear previous polylines
//   //       _polylines.clear();

//   //        // Initialize PolylinePoints for decoding polyline strings
//   //     PolylinePoints polylinePoints = PolylinePoints();

//   //        // Loop through all the routes and draw polylines
//   //     for (var route in directionsResponse.routes) {
//   //       final encodedPolyline = route.overviewPolyline.points;

//   //       // Decode the polyline string into a list of LatLng points
//   //       final decodedPoints = polylinePoints.decodePolyline(encodedPolyline);

//   //       final polylineLatLng = decodedPoints.map((point) {
//   //         return LatLng(point.latitude, point.longitude);
//   //       }).toList();

//   //       // Add polyline to the map
//   //       final polylineId = PolylineId(route.summary); // Use summary as the ID
//   //       _polylines.add(maps.Polyline(
//   //         polylineId: polylineId,
//   //         points: polylineLatLng,
//   //         color: Colors.blue, // Choose color for the polyline
//   //         width: 5, // Set the width of the polyline
//   //       ));
//   //     }
//   //     } else {
//   //       print('Error fetching directions: ${directionsResponse.errorMessage}');
//   //     }
//   //   } catch (e) {
//   //     print('Error fetching directions: $e');
//   //   }
//   // }


// Dynamic Polylines Backup

// import 'dart:async';
// import 'dart:convert';
// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_polyline_points/flutter_polyline_points.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:google_maps_webservice/directions.dart' as gmaps;
// import 'package:google_maps_webservice/places.dart';
// import 'package:http/http.dart' as http;
// import 'package:maps/screens/no_internet.dart';
// import 'package:maps/util/app_colors.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;
// import 'package:location/location.dart' as loc;

// // import '../util/permission_services.dart';

// class MapsHomeScreen extends StatefulWidget {
//   const MapsHomeScreen({super.key});

//   @override
//   State<MapsHomeScreen> createState() => _MapsHomeScreenState();
// }

// class _MapsHomeScreenState extends State<MapsHomeScreen> {
//   static const myApiKey = "AIzaSyBsVw09Zl_Xby65X7ed8Xs2ov8aAhaWiFk";
//   TextEditingController _searchController = TextEditingController();

//   final GoogleMapsPlaces _places = GoogleMapsPlaces(apiKey: myApiKey);
//   final gmaps.GoogleMapsDirections _directions =
//       gmaps.GoogleMapsDirections(apiKey: myApiKey);
//   GoogleMapController? mapController;
//   late LatLng _initialPosition;
//   late LatLng _destinationPosition;
//   Marker? _startingMarker;
//   BitmapDescriptor? userLocationMarker;
//   Marker? _destinationMarker;
//   Set<maps.Polyline> _polylines = {};
//   List<Prediction> _predictions = [];
//   late Prediction _prediction;
//   String? distanceText;
//   String? durationText;
//   String? tollInfoText;

//   String _selectedMode = "driving";
//   String? countryCode;
//   bool isLoading = true;
//   bool showBottomSheet = false;
//   bool hasLocationPermission = false;
//   bool isInternetConnected = true;
//   bool isJourneyStarted = false;
//   String destinationText = "N/A";
//   // Position? userCurrentPosition;
//   // Connectivity
//   final Connectivity _connectivity = Connectivity();
//   List<ConnectivityResult> _connectionStatus = [ConnectivityResult.none];
//   late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

//   final loc.Location _location = loc.Location();
//   late StreamSubscription<loc.LocationData> _locationSubscription;
//   List<LatLng> selectedRoutePoints = [];

//   @override
//   void initState() {
//     super.initState();
//     _initializeApp();
//     initConnectivity();
//     _connectivitySubscription =
//         _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
//   }

//   Future<void> initConnectivity() async {
//     List<ConnectivityResult> result;

//     try {
//       result = await _connectivity.checkConnectivity();
//     } on PlatformException catch (e) {
//       print("Connectivity error: $e");
//       return;
//     }

//     // Update the UI based on the connectivity result
//     if (!mounted) return;

//     _updateConnectionStatus(result);
//   }

//   Future<void> _updateConnectionStatus(List<ConnectivityResult> result) async {
//     setState(() {
//       _connectionStatus = result;

//       // Check if any connectivity result is either wifi or mobile
//       isInternetConnected = result.contains(ConnectivityResult.wifi) ||
//           result.contains(ConnectivityResult.mobile);
//     });

//     print('Connectivity changed: $_connectionStatus bool $isInternetConnected');
//   }

//   @override
//   void dispose() {
//     // Don't forget to cancel the subscription when the widget is disposed
//     _connectivitySubscription.cancel();
//     super.dispose();
//   }

//   void _onMapCreated(GoogleMapController controller) {
//     mapController = controller;
//   }

//   Future<void> _initializeApp() async {
//     bool permissionGranted = await _checkLocationPermission();
//     userLocationMarker = await getCustomIcon();
//     if (permissionGranted) {
//       await _initializeUserLocation();
//     } else {
//       setState(() => isLoading = false); // Stop loading if no permission
//     }
//     debugPrint("myDebug isLoading _initializeApp() $isLoading");
//   }

//   Future<bool> _checkLocationPermission() async {
//     // location
//     loc.PermissionStatus permissionStatus = await _location.requestPermission();
//     if (permissionStatus == loc.PermissionStatus.granted) {
//       setState(() => hasLocationPermission = true);
//       debugPrint("myDebugLoc isLoading _checkLocationPermission() $isLoading");
//       return true;
//     } else {
//       setState(() {
//         hasLocationPermission = false;
//         // isLoading = false; // byme
//       });
//       return false;
//     }
//   }

//   bool hasReachedDestination(LatLng currentLocation, LatLng destination,
//       {double thresholdInMeters = 50.0}) {
//     final double distance = Geolocator.distanceBetween(
//       currentLocation.latitude,
//       currentLocation.longitude,
//       destination.latitude,
//       destination.longitude,
//     );

//     return distance <= thresholdInMeters;
//   }

//   void _onReachedDestination() {
//     // Stop location tracking if needed
//     _locationSubscription?.cancel();

//     // Display a notification or dialog
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text("Destination Reached"),
//           content: Text("You have arrived at your destination."),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 _resetState();
//                 Navigator.of(context).pop();
//               },
//               child: Text("OK"),
//             ),
//           ],
//         );
//       },
//     );
//   }

// // Function to check if route recalculation is needed
//   bool shouldRecalculateRoute(LatLng currentPosition, LatLng destination) {
//     const double deviationThresholdInMiles = 0.0621371; // 0.1 km in miles
//     double distanceToRouteInMiles =
//         _calculateDistance(currentPosition, _initialPosition) * 0.621371;
//     debugPrint(
//         "myDebug Recalculating Distance Function ${distanceToRouteInMiles > deviationThresholdInMiles}");
//     return distanceToRouteInMiles > deviationThresholdInMiles;
//   }

//   double _calculateDistance(LatLng start, LatLng end) {
//     double distanceInMeters = Geolocator.distanceBetween(
//       start.latitude,
//       start.longitude,
//       end.latitude,
//       end.longitude,
//     );
//     // debugPrint("myDebug Remaining Distance ${distanceInMeters / 1000} KM");
//     return distanceInMeters / 1000; // Convert to kilometers
//   }
//   // bool shouldRecalculateRoute(LatLng currentPosition, LatLng destination) {
//   //   const double deviationThresholdInMiles =
//   //       0.0621371; // Example threshold in miles (0.1 km = 0.0621371 miles)
//   //   double distanceToRouteInMiles =
//   //       _calculateDistance(currentPosition, _initialPosition) *
//   //           0.621371; // Convert km to miles

//   //   return distanceToRouteInMiles > deviationThresholdInMiles;
//   // }

//   Future<void> _initializeUserLocation() async {
//     try {
//       bool isServiceEnabled = await _location.serviceEnabled();
//       if (!isServiceEnabled) {
//         isServiceEnabled = await _location.requestService();
//         if (!isServiceEnabled) {
//           throw Exception("Location services are disabled.");
//         }
//       }
//       final locationData = await _location.getLocation();
//       _updateUserLocation(locationData);

//       countryCode = await getCountryCode(
//           LatLng(locationData.latitude!, locationData.longitude!));

//       setState(() => isLoading = false); // byme
//     } catch (e) {
//       debugPrint("Error initializing user location: $e");
//       setState(() => isLoading = false);
//     }
//   }

// // Function to update the user's location marker
//   void _updateUserLocation(loc.LocationData locationData) {
//     final userLatLng = LatLng(locationData.latitude!, locationData.longitude!);
//     setState(() {
//       _initialPosition = userLatLng;
//       _startingMarker = Marker(
//         markerId: const MarkerId('userLocation'),
//         position: userLatLng,
//         icon: userLocationMarker ?? BitmapDescriptor.defaultMarker,
//         infoWindow: const InfoWindow(title: "Your Current Location"),
//       );
//       isLoading = false;
//     });
//   }
//   // void _updateUserLocation(loc.LocationData locationData) {
//   //   final userLatLng = LatLng(locationData.latitude!, locationData.longitude!);

//   //   // GeoLocator
//   //   setState(() {
//   //     _initialPosition = userLatLng;
//   //     _startingMarker = Marker(
//   //       icon: BitmapDescriptor.defaultMarker,
//   //       // icon: myCustomIcon,
//   //       markerId: const MarkerId('userLocation'),
//   //       position: userLatLng,
//   //       infoWindow: const InfoWindow(title: "Your Current Location"),
//   //     );
//   //     isLoading = false; // Stop loading
//   //     debugPrint("myDebug _updateUserLocation triggered");
//   //   });
//   // }

//   Future<void> _moveToUserLocation() async {
//     try {
//       if (!hasLocationPermission) {
//         debugPrint("myDebug Permission not granted. Cannot move to location.");
//         return;
//       }
//       final locationData = await _location.getLocation();
//       final userLatLng =
//           LatLng(locationData.latitude!, locationData.longitude!);
//       mapController?.animateCamera(CameraUpdate.newLatLngZoom(userLatLng, 14));
//     } catch (e) {
//       debugPrint("Error moving to location: $e");
//     }
//   }

//   void _searchCities(String query) async {
//     if (query.isEmpty) {
//       setState(() {
//         _predictions = [];
//       });
//       return;
//     }

//     // if(countryCode!.isNotEmpty){
//     final response = await _places.autocomplete(
//       query,
//       // types: ['(cities)'], // Restrict to cities
//       components: [Component(Component.country, countryCode.toString())],
//     );
//     // }

//     if (response.isOkay) {
//       setState(() {
//         _predictions = response.predictions;
//       });
//     } else {
//       debugPrint("Places API error: ${response.errorMessage}");
//     }
//   }

//   Future<String?> getCountryCode(LatLng userCoordinates) async {
//     try {
//       // Get the nearest place details using the Places API reverse geocode
//       final response = await _places.searchNearbyWithRadius(
//         Location(lat: userCoordinates.latitude, lng: userCoordinates.longitude),
//         50, // 50 meters radius for higher accuracy
//       );

//       if (response.isOkay && response.results.isNotEmpty) {
//         final placeId = response.results.first.placeId;

//         // if (placeId != null) {
//         // Fetch place details to extract country code
//         final placeDetailsResponse = await _places.getDetailsByPlaceId(placeId);

//         if (placeDetailsResponse.isOkay) {
//           final addressComponents =
//               placeDetailsResponse.result.addressComponents;

//           // Extract the country code
//           final countryComponent = addressComponents.firstWhere(
//             (component) => component.types.contains('country'),
//             orElse: () =>
//                 AddressComponent(longName: '', shortName: '', types: []),
//           );
//           debugPrint("myDebug country ${countryComponent.shortName}");
//           return countryComponent.shortName; // Return the ISO country code
//         }
//         // }
//       }
//       return null; // Return null if no country found
//     } catch (e) {
//       debugPrint('Error fetching country code: $e');
//       return null;
//     }
//   }

//   String getCityTitle(Prediction prediction) {
//     String description = prediction.description ?? '';
//     return description.split(',')[0]; // Extract the first part
//   }

//   Future<BitmapDescriptor> getCustomIcon() async {
//     return await BitmapDescriptor.asset(
//       ImageConfiguration(size: Size(24.w, 24.h)), // Specify desired size
//       'assets/current_location_marker.png',
//       // 'assets/anim_location.gif',21302130
//     );
//   }

//   void _selectCity(Prediction prediction) async {
//     FocusScope.of(context).unfocus();
//     setState(() {
//       _predictions.clear();
//     });

//     final placeDetails = await _places.getDetailsByPlaceId(prediction.placeId!);

//     if (placeDetails.isOkay) {
//       final location = placeDetails.result.geometry!.location;
//       _destinationPosition = LatLng(location.lat, location.lng);

//       setState(() {
//         _prediction = prediction;
//         _destinationMarker = Marker(
//           markerId: const MarkerId('cityLocation'),
//           position: _destinationPosition,
//           infoWindow: InfoWindow(title: prediction.description),
//         );
//         showBottomSheet = true;
//       });

//       mapController!
//           .animateCamera(CameraUpdate.newLatLngZoom(_destinationPosition, 14));

//       await _fetchAndDrawRoutes();
//     } else {
//       debugPrint("Error fetching place details: ${placeDetails.errorMessage}");
//     }
//   }

// // Function to fetch and draw routes
//   Future<void> _fetchAndDrawRoutes() async {
//     try {
//       if (_initialPosition == null || _destinationPosition == null) {
//         throw Exception("Initial or destination position is not set.");
//       }

//       final directionsUrl =
//           'https://maps.googleapis.com/maps/api/directions/json?origin=${_initialPosition.latitude},${_initialPosition.longitude}&destination=${_destinationPosition.latitude},${_destinationPosition.longitude}&mode=$_selectedMode&alternatives=true&key=$myApiKey';
//       final response = await http.get(Uri.parse(directionsUrl));
//       debugPrint("myDebug _fetchAndDrawRoutes() inilat${_initialPosition.latitude} , inilat${_initialPosition.longitude} destination=${_destinationPosition.latitude},${_destinationPosition.longitude}");

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         if (data['routes'] != null && data['routes'].isNotEmpty) {
//           final route = data['routes'][0];
//           final legs = route['legs'][0];
//           setState(() {
//             distanceText = legs['distance']['text'];
//             durationText = legs['duration']['text'];
//             _polylines.clear(); // Clear previous polylines
//           });
//           await _drawPolylines(data['routes']);
//         } else {
//           debugPrint("No routes found for the selected mode.");
//         }
//       } else {
//         throw Exception('Failed to load directions: ${response.statusCode}');
//       }
//     } catch (e) {
//       debugPrint('Error fetching directions: $e');
//       setState(() {
//         distanceText = 'N/A';
//         durationText = 'N/A';
//       });
//     }
//   }

//   Future<void> _drawPolylines(List<dynamic> routes) async {
//     try {
//       debugPrint("myDebug _DrawPolylines Called");
//       final PolylinePoints polylinePoints = PolylinePoints();
//       final newPolylines = <Polyline>{};
//       double shortestDistance = double.infinity;
//       List<LatLng> shortestRoutePoints = [];

//       for (var route in routes) {
//         final points =
//             polylinePoints.decodePolyline(route['overview_polyline']['points']);
//         final polylineLatLng = points
//             .map((point) => LatLng(point.latitude, point.longitude))
//             .toList();
//         final routeDistance = route['legs'][0]['distance']['value'];

//         // Track the shortest route
//         if (routeDistance < shortestDistance) {
//           shortestDistance = routeDistance.toDouble();
//           shortestRoutePoints = polylineLatLng;
//         }

//         // Add polyline for the route
//         final polylineId = PolylineId(route['summary']);
//         newPolylines.add(Polyline(
//           polylineId: polylineId,
//           points: polylineLatLng,
//           color: Colors.grey,
//           width: 5,
//         ));
//       }

//       // Highlight the shortest route
//       newPolylines.add(Polyline(
//         polylineId: const PolylineId("shortestRoute"),
//         points: shortestRoutePoints,
//         color: AppColors.primary,
//         width: 8,
//       ));

//       // Update state with new polylines
//       setState(() {
//         _polylines = newPolylines;
//       });
//     } catch (e) {
//       debugPrint('Error drawing polylines: $e');
//     }
//   }

//   // Future<void> getRoutesAndDrawPolylines() async {
//   //   try {
//   //     final _travelMode = getTravelMode(_selectedMode);

//   //     debugPrint('Fetching routes for mode: $_selectedMode');
//   //     setState(() {
//   //       _polylines.clear(); // Clear previous polylines before fetching new ones
//   //     });
//   //     debugPrint('myDebug Fetching polylines cleard');

//   //     final directionsResponse = await _directions.directions(
//   //       gmaps.Location(
//   //         lat: _initialPosition.latitude,
//   //         lng: _initialPosition.longitude,
//   //       ),
//   //       gmaps.Location(
//   //         lat: _destinationPosition.latitude,
//   //         lng: _destinationPosition.longitude,
//   //       ),
//   //       travelMode: _travelMode,
//   //       alternatives: true,
//   //     );

//   //     if (directionsResponse.isOkay) {
//   //       final PolylinePoints polylinePoints = PolylinePoints();
//   //       double shortestDistance = double.infinity;
//   //       gmaps.Route? shortestRoute;

//   //       final newPolylines = <maps.Polyline>{};

//   //       for (gmaps.Route route in directionsResponse.routes) {
//   //         final encodedPolyline = route.overviewPolyline.points;
//   //         final decodedPoints = polylinePoints.decodePolyline(encodedPolyline);
//   //         final polylineLatLng = decodedPoints
//   //             .map((point) => LatLng(point.latitude, point.longitude))
//   //             .toList();

//   //         final routeDistance = route.legs[0].distance.value;

//   //         // Find the shortest route
//   //         if (routeDistance < shortestDistance) {
//   //           shortestDistance = routeDistance.toDouble();
//   //           shortestRoute = route;
//   //           debugPrint("myDebugPoly routeDistance: $routeDistance");
//   //           debugPrint(
//   //               "myDebugPoly shortestRoute: ${shortestRoute.legs[0].distance.value}");
//   //         }

//   //         // Create a unique polyline for each route
//   //         final polylineId = PolylineId(route.summary);
//   //         newPolylines.add(maps.Polyline(
//   //           polylineId: polylineId,
//   //           points: polylineLatLng,
//   //           color: Colors.grey,
//   //           width: 5,
//   //           consumeTapEvents: true,
//   //           onTap: () {
//   //             debugPrint("myDebugPoly _onRouteSelected tapped");
//   //             _onRouteSelected(route, polylineId);
//   //           },
//   //         ));
//   //       }

//   //       // Highlight the shortest route
//   //       if (shortestRoute != null) {
//   //         final shortestPolylineId = PolylineId(shortestRoute.summary);
//   //         newPolylines.add(
//   //           newPolylines
//   //               .firstWhere(
//   //                   (polyline) => polyline.polylineId == shortestPolylineId)
//   //               .copyWith(colorParam: AppColors.primary, widthParam: 8),
//   //         );
//   //         debugPrint(
//   //             "myDebugPoly shortestRoute yellow polylineCreated: $shortestPolylineId");
//   //       }

//   //       // Update state with new polylines
//   //       setState(() {
//   //         _polylines = newPolylines;
//   //       });
//   //       debugPrint(
//   //           "myDebugPoly number of polylines in list ${_polylines.length}");
//   //     } else {
//   //       debugPrint(
//   //           'Error fetching directions: ${directionsResponse.errorMessage}');
//   //     }
//   //   } catch (e) {
//   //     debugPrint('Error fetching routes: $e');
//   //   }
//   // }

//   void _onRouteSelected(gmaps.Route selectedRoute, PolylineId polylineId) {
//     debugPrint(
//         "myDebugPoly _onRouteSelected ${selectedRoute} polylineID: $polylineId");
//     final updatedPolylines = _polylines.map((polyline) {
//       if (polyline.polylineId == polylineId) {
//         return polyline.copyWith(colorParam: AppColors.primary, widthParam: 8);
//       } else {
//         return polyline.copyWith(colorParam: Colors.grey, widthParam: 5);
//       }
//     }).toSet();

//     // Check if the route contains tolls
//     final List<dynamic>? warnings = selectedRoute.warnings;
//     bool containsTolls = warnings?.any(
//             (warning) => warning.toString().toLowerCase().contains('toll')) ??
//         false;

//     setState(() {
//       _polylines = updatedPolylines;
//       final selectedRouteDetails =
//           selectedRoute.legs[0]; // First leg of the route
//       distanceText = selectedRouteDetails.distance.text; // Distance as a string
//       durationText = selectedRouteDetails.duration.text; // Duration as a string
//       tollInfoText = containsTolls ? "This Route Contain tools" : "Doesn't";
//     });

//     selectedRoutePoints =
//         _decodePolyline(selectedRoute.overviewPolyline.points);

//     debugPrint('Route selected: ${selectedRoute.summary}');
//   }

//   List<LatLng> _decodePolyline(String encoded) {
//     PolylinePoints polylinePoints = PolylinePoints();
//     List<LatLng> polylineLatLng = polylinePoints
//         .decodePolyline(encoded)
//         .map((point) => LatLng(point.latitude, point.longitude))
//         .toList();
//     return polylineLatLng;
//   }

//   void _startLiveNavigation() {
//     _moveToUserLocation();
//     _locationSubscription = loc.Location.instance.onLocationChanged.listen(
//       (locationData) async {
//         if (locationData.latitude == null || locationData.longitude == null) {
//           return;
//         }

//         final currentLocation =
//             LatLng(locationData.latitude!, locationData.longitude!);

//         // Check if the destination is reached
//         if (hasReachedDestination(currentLocation, _destinationPosition)) {
//           _onReachedDestination();
//           return;
//         }

//         // Check for route deviation and recalculate if needed
//         if (shouldRecalculateRoute(currentLocation, _destinationPosition)) {
//           debugPrint('User deviated from the route. Recalculating...');
//           _fetchAndDrawRoutes(); // Recalculate route and redraw polylines
//         }

//         _updateUserLocation(locationData);
//       },
//     );
//   }
//   // void _startLiveNavigation() {
//   //   _locationSubscription = loc.Location.instance.onLocationChanged.listen(
//   //     (locationData) async {
//   //       if (locationData.latitude == null || locationData.longitude == null) {
//   //         return;
//   //       }

//   //       final currentLocation =
//   //           LatLng(locationData.latitude!, locationData.longitude!);

//   //       // Check if the destination is reached
//   //       if (hasReachedDestination(currentLocation, _destinationPosition)) {
//   //         _onReachedDestination();
//   //         return;
//   //       }

//   //       // Check for route deviation and recalculate if needed
//   //       if (shouldRecalculateRoute(currentLocation, _destinationPosition)) {
//   //         debugPrint('User deviated from the route. Recalculating...');
//   //         _fetchAndDrawRoutes(); // Recalculate route and redraw polylines
//   //       }

//   //       // Update distance and duration
//   //       _updateDistanceAndDuration(currentLocation);
//   //       final remainingDistance = _calculateDistance(currentLocation, _destinationPosition);
//   //       final remainingTime =

//   //       // Update user location marker
//   //       _updateUserLocation(locationData);
//   //       // _updateUserLocation(locationData, myCustomIcon);
//   //     },
//   //   );
//   // }

//   // void _updateDistanceAndDuration(LatLng currentLocation) {
//   //   double remainingDistance = 0.0;
//   //   Duration totalRemainingTime = Duration.zero;

//   //   // Calculate remaining distance and time
//   //   for (int i = 0; i < selectedRoutePoints.length - 1; i++) {
//   //     LatLng start = (i == 0) ? currentLocation : selectedRoutePoints[i];
//   //     LatLng end = selectedRoutePoints[i + 1];

//   //     double segmentDistance = _calculateDistance(start, end);
//   //     remainingDistance += segmentDistance;

//   //     // Assuming a constant speed (e.g., 40 km/h)
//   //     double speed = 40.0; // km/h
//   //     totalRemainingTime += Duration(
//   //       minutes: ((segmentDistance / speed) * 60).toInt(),
//   //     );
//   //   }

//   //   setState(() {
//   //     distanceText = "Rem: ${remainingDistance.toStringAsFixed(2)} km";
//   //     durationText = "Rem ${totalRemainingTime.inMinutes} min";
//   //   });
//   // }

//   // double _calculateDistance(LatLng start, LatLng end) {
//   //   double distanceInMeters = Geolocator.distanceBetween(
//   //     start.latitude,
//   //     start.longitude,
//   //     end.latitude,
//   //     end.longitude,
//   //   );
//   //   debugPrint("myDebug Remaining Distance ${distanceInMeters / 1000} KM");
//   //   return distanceInMeters / 1000; // Convert to kilometers
//   // }

//   // double _calculateTime(LatLng start, LatLng end) {
//   //   double distanceInMeters = Geolocator.distanceBetween(
//   //     start.latitude,
//   //     start.longitude,
//   //     end.latitude,
//   //     end.longitude,
//   //   );
//   //   debugPrint("myDebug Remaining Distance ${distanceInMeters / 1000} KM");
//   //   return distanceInMeters / 1000; // Convert to kilometers
//   // }

//   // void _updateDuration(int currentIndex, List<LatLng> routePoints) {
//   //   if (currentIndex < routePoints.length - 1) {
//   //     LatLng currentPoint = routePoints[currentIndex];
//   //     LatLng nextPoint = routePoints[currentIndex + 1];

//   //     // Calculate time taken to travel between two points
//   //     double distance = _calculateDistance(currentPoint, nextPoint);
//   //     double speed = 40.0; // Speed in km/h (can be adjusted)

//   //     double timeInHours = distance / speed;
//   //     Duration timeDuration = Duration(
//   //         hours: timeInHours.toInt(), minutes: (timeInHours * 60).toInt() % 60);

//   //     setState(() {
//   //       durationText = "Remaining Time: ${timeDuration.inMinutes} min";
//   //     });
//   //   }
//   // }

//   gmaps.TravelMode getTravelMode(String mode) {
//     switch (mode.toLowerCase()) {
//       case 'driving':
//         return gmaps.TravelMode.driving;
//       case 'walking':
//         return gmaps.TravelMode.walking;
//       case 'bicycling':
//         return gmaps.TravelMode.bicycling;
//       case 'transit':
//         return gmaps.TravelMode.transit;
//       default:
//         return gmaps.TravelMode.driving;
//     }
//   }

//   String convertKmToMiles(String distanceText) {
//     final kmToMilesFactor = 0.621371;

//     // Extract the numeric value from the text
//     final regex = RegExp(r"([\d.]+)"); // Match numbers including decimals
//     final match = regex.firstMatch(distanceText);

//     if (match != null) {
//       final kmValue = double.parse(match.group(1)!); // Convert to double
//       final milesValue = kmValue * kmToMilesFactor;

//       // Return the formatted miles value with 'mi'
//       return "${milesValue.toStringAsFixed(2)} mi";
//     } else {
//       // If no number is found, return the original text
//       return distanceText;
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (!isInternetConnected) {
//       return NoInternetWidget();
//     }
//     return SafeArea(
//       child: Scaffold(
//         resizeToAvoidBottomInset: false,
//         body: isLoading
//             ? Center(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     CircularProgressIndicator(),
//                     SizedBox(height: 20.sp),
//                     Text(
//                       "Loading Maps...",
//                       textAlign: TextAlign.center,
//                       style: TextStyle(
//                         fontWeight: FontWeight.w500,
//                         color: AppColors.primaryText,
//                         fontSize: 14.sp,
//                       ),
//                     ),
//                   ],
//                 ),
//               )
//             : hasLocationPermission
//                 ? Stack(
//                     children: [
//                       GestureDetector(
//                         onTap: () {
//                           // Unfocus to dismiss the keyboard
//                           FocusScope.of(context).unfocus();
//                         },
//                         child: GoogleMap(
//                           onMapCreated: _onMapCreated,
//                           compassEnabled: false,
//                           mapType: MapType.normal,
//                           initialCameraPosition: CameraPosition(
//                             target: _initialPosition,
//                             zoom: 14,
//                           ),
//                           markers: {
//                             if (_startingMarker != null) _startingMarker!,
//                             if (_destinationMarker != null) _destinationMarker!,
//                           },
//                           polylines: _polylines,
//                           trafficEnabled: true,
//                         ),
//                       ),
//                       IntrinsicHeight(
//                         child: Container(
//                           margin: const EdgeInsets.symmetric(
//                               vertical: 24, horizontal: 20),
//                           // color: Colors.amber,
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               if (isJourneyStarted)
//                                 _startPositionCard("From: ", "Your Location"),
//                               if (isJourneyStarted)
//                                 Padding(
//                                   padding: EdgeInsets.only(left: 18.w),
//                                   child: Icon(
//                                     Icons.keyboard_double_arrow_down_rounded,
//                                     color: AppColors.primaryGrey,
//                                     size: 15.sp,
//                                   ),
//                                 ),
//                               if (isJourneyStarted)
//                                 _stopPositionCard(
//                                     "To: ", _searchController.text),
//                               SizedBox(
//                                 height: 10.h,
//                               ),
//                               if (!isJourneyStarted) searchTextFieldCard(),
//                               SizedBox(
//                                 height: 10.h,
//                               ),
//                               Align(
//                                 alignment: Alignment
//                                     .centerRight, // Align to the right side
//                                 child: CircleAvatar(
//                                   backgroundColor: Colors.white,
//                                   radius: 22.sp,
//                                   child: CircleAvatar(
//                                     backgroundColor: AppColors.secondary,
//                                     child: Center(
//                                       child: IconButton(
//                                         iconSize: 22.sp,
//                                         color: AppColors.primaryGrey,
//                                         onPressed: _moveToUserLocation,
//                                         icon: Icon(Icons.my_location_outlined),
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                       _predictions.isNotEmpty
//                           ? Container(
//                               margin: EdgeInsets.symmetric(
//                                   horizontal: 30.w, vertical: 90.h),
//                               decoration: BoxDecoration(
//                                   color: Colors.white,
//                                   borderRadius: BorderRadius.only(
//                                       bottomLeft: Radius.circular(20.r),
//                                       bottomRight: Radius.circular(20.r))),
//                               child: ListView.builder(
//                                 shrinkWrap: true,
//                                 itemCount: _predictions.length,
//                                 itemBuilder: (context, index) {
//                                   final prediction = _predictions[index];
//                                   return ListTile(
//                                     leading: Icon(
//                                       Icons.location_on,
//                                       color: AppColors.primary,
//                                     ),
//                                     title: Text(prediction.description ?? ''),
//                                     onTap: () {
//                                       _searchController.text = prediction
//                                               .structuredFormatting?.mainText ??
//                                           _searchController.text;
//                                       _selectCity(prediction);
//                                     },
//                                   );
//                                 },
//                               ),
//                             )
//                           : SizedBox(),
//                     ],
//                   )
//                 : Center(
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Icon(
//                           Icons.location_off,
//                           size: 80.sp,
//                           color: Colors.grey,
//                         ),
//                         SizedBox(height: 20.sp),
//                         Text(
//                           "Please allow location permissions\nto use the app",
//                           textAlign: TextAlign.center,
//                           style: TextStyle(
//                             fontSize: 16.sp,
//                             color: Colors.grey,
//                           ),
//                         ),
//                         SizedBox(height: 20.sp),
//                         ElevatedButton(
//                           onPressed: () async {
//                             await Geolocator.openAppSettings();
//                             // await Geolocator.openLocationSettings();
//                             // _checkLocationPermission();
//                           },
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: AppColors.primary,
//                             padding: EdgeInsets.symmetric(
//                                 horizontal: 40.w, vertical: 15.h),
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(50.sp),
//                             ),
//                           ),
//                           child: Text(
//                             'Grant Permissions',
//                             style: TextStyle(
//                                 fontSize: 16.sp, color: AppColors.primaryText),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//         bottomSheet: showBottomSheet ? bottomSheetWidget() : SizedBox(),
//       ),
//     );
//   }

//   void _resetState() {
//     setState(() {
//       isJourneyStarted = false;
//       showBottomSheet = false;
//       _polylines.clear(); // Clear all polylines
//       _destinationMarker = null;
//       _searchController.text = '';
//       // _initialPosition = null; // Reset the initial position
//       // _destinationPosition = null; // Reset the destination position
//       distanceText = ''; // Clear distance text
//       durationText = ''; // Clear duration text
//       tollInfoText = ''; // Clear toll info text
//       _selectedMode = ''; // Reset travel mode if needed
//       _locationSubscription.cancel();
//       // Any other variables you want to reset
//     });
//     _initializeUserLocation();
//   }

//   Widget bottomSheetWidget() {
//     return Container(
//       // color: Colors.black,
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.only(
//           topLeft: Radius.circular(25.r), // Top-left corner rounded
//           topRight: Radius.circular(25.r), // Top-right corner rounded
//         ),
//       ),
//       child: Padding(
//         padding: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 16.w),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Container(
//               height: 4.h, // Height of the divider
//               width: double.infinity, // Full width or customize as needed
//               margin: EdgeInsets.symmetric(
//                   horizontal: 150.w, vertical: 16.h), // Adjust margin as needed
//               decoration: BoxDecoration(
//                 color: AppColors.dividerGrey, // Divider color
//                 borderRadius: BorderRadius.circular(2.h), // Rounded edges
//               ),
//             ),
//             isJourneyStarted
//                 ? SizedBox()
//                 : Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                     children: [
//                       _transportationOption(
//                           icon: Icons.directions_car,
//                           label: "Car",
//                           mode: 'driving'),
//                       _transportationOption(
//                           icon: Icons.directions_walk,
//                           label: "Walking",
//                           mode: 'walking'),
//                       _transportationOption(
//                           icon: Icons.directions_bike,
//                           label: "Bike",
//                           mode: 'bicycling'),
//                       _transportationOption(
//                           icon: Icons.train, label: "Transit", mode: 'transit'),
//                     ],
//                   ),
//             Divider(color: AppColors.textField),
//             // Row(
//             //   crossAxisAlignment: CrossAxisAlignment.center,
//             //   children: [
//             // Icon(Icons.alt_route_outlined,
//             //     size: 22.sp, color: AppColors.dividerGrey),
//             // SizedBox(width: 5.w),
//             // Padding(
//             //   padding: EdgeInsets.only(top: 3.h),
//             //   child: Text(
//             //     tollInfoText ?? "N/A",
//             //     style: TextStyle(
//             //         fontSize: 14.sp,
//             //         color: AppColors.primaryGrey),
//             //     textAlign: TextAlign.center,
//             //   ),
//             // ),
//             //   ],
//             // ),
//             // Horizontal Row Commented
//             // Row(
//             //   crossAxisAlignment: CrossAxisAlignment.center,
//             //   children: [
//             // Icon(Icons.access_time_filled,
//             //     size: 22.sp, color: AppColors.dividerGrey),
//             // SizedBox(width: 5.w),
//             // Padding(
//             //   padding: EdgeInsets.only(top: 3.h),
//             //   child: Text(
//             //     durationText ?? "N/A",
//             //     style: TextStyle(
//             //         fontSize: 14.sp,
//             //         color: AppColors.primaryGrey),
//             //     textAlign: TextAlign.center,
//             //   ),
//             // ),
//             //   ],
//             // ),
//             // Row(
//             //   crossAxisAlignment: CrossAxisAlignment.center,
//             //   children: [
//             //     Icon(Icons.location_pin,
//             //         color: AppColors.dividerGrey),
//             //     SizedBox(width: 5.w),
//             //     Padding(
//             //       padding: EdgeInsets.only(top: 3.h),
//             //       child: Text(
//             //         convertKmToMiles(distanceText.toString()),
//             //         style: TextStyle(
//             //             fontSize: 14.sp,
//             //             color: AppColors.primaryGrey),
//             //         textAlign: TextAlign.center,
//             //       ),
//             //     ),
//             //   ],
//             // ),
//             Row(
//               crossAxisAlignment: CrossAxisAlignment.center,
//               children: [
//                 Icon(Icons.access_time_filled,
//                     size: 22.sp, color: AppColors.primary),
//                 SizedBox(width: 5.w),
//                 Padding(
//                   padding: EdgeInsets.only(top: 3.h),
//                   child: Text(
//                     durationText ?? "N/A",
//                     style: TextStyle(
//                         fontSize: 14.sp, color: AppColors.primaryGrey),
//                     textAlign: TextAlign.center,
//                   ),
//                 ),
//                 SizedBox(
//                   width: 10.w,
//                 ),
//                 Icon(Icons.location_pin, color: AppColors.primary),
//                 SizedBox(width: 5.w),
//                 Padding(
//                   padding: EdgeInsets.only(top: 3.h),
//                   child: Text(
//                     distanceText.toString(),
//                     // convertKmToMiles(distanceText.toString()),
//                     style: TextStyle(
//                         fontSize: 14.sp, color: AppColors.primaryGrey),
//                     textAlign: TextAlign.center,
//                   ),
//                 ),
//               ],
//             ),
//             Divider(color: AppColors.textField),
//             Text(
//               _prediction.structuredFormatting?.mainText ?? "N/A",
//               style: TextStyle(
//                 fontSize: 20.sp,
//                 color: AppColors.primaryText,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             SizedBox(height: 10.h),
//             Text(
//               '${_prediction.description}',
//               style: TextStyle(
//                 fontSize: 14.sp,
//                 color: AppColors.dividerGrey,
//               ),
//             ),
//             SizedBox(height: 20),
//             // Start Journet
//             ElevatedButton(
//               onPressed: () {
//                 if (!isJourneyStarted) {
//                   // _startNavigation(selectedRoutePoints);
//                   _startLiveNavigation();
//                   setState(() {
//                     isJourneyStarted = true;
//                   });
//                 } else {
//                   _resetState();
//                 }
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: isJourneyStarted
//                     ? AppColors.primaryText
//                     : AppColors.primary,
//                 padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 15.h),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(10.sp),
//                 ),
//                 minimumSize: Size(MediaQuery.of(context).size.width, 50.sp),
//               ),
//               child: isJourneyStarted
//                   ? Text(
//                       'Exit',
//                       style: TextStyle(fontSize: 16.sp, color: Colors.white),
//                     )
//                   : Text(
//                       'Start',
//                       style: TextStyle(
//                           fontSize: 16.sp, color: AppColors.primaryText),
//                     ),
//             ),
//             SizedBox(height: 20.h),
//             // Transportation mode selection
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _startPositionCard(String title, String? _selectedDestination) {
//     return Container(
//       width: double.infinity,
//       height: 45.h,
//       // margin: EdgeInsets.symmetric(horizontal: 20.w),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(50),
//       ),
//       child: Padding(
//         padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 12.h),
//         child: Row(
//           children: [
//             Image.asset(
//               'assets/current_location_marker.png',
//               height: 20.h,
//             ),
//             SizedBox(
//               width: 5.w,
//             ),
//             Text(
//               title,
//               style: TextStyle(color: AppColors.dividerGrey, fontSize: 12.sp),
//             ),
//             Text(
//               _selectedDestination.toString(),
//               style: TextStyle(color: AppColors.primaryGrey, fontSize: 14.sp),
//             )
//           ],
//         ),
//       ),
//     );
//   }

//   Widget searchTextFieldCard() {
//     return Container(
//       // margin: const EdgeInsets.symmetric(
//       //     vertical: 24, horizontal: 20),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(50),
//       ),
//       child: TextField(
//         controller: _searchController,
//         onChanged: _searchCities,
//         style: const TextStyle(color: Colors.black),
//         cursorColor: AppColors.primary,
//         decoration: const InputDecoration(
//           labelText: "Search",
//           prefixIcon: Icon(Icons.search, color: Colors.grey),
//           border: InputBorder.none,
//         ),
//         keyboardType: TextInputType.streetAddress,
//       ),
//     );
//   }

//   Widget _stopPositionCard(String title, String? _selectedDestination) {
//     return Container(
//       width: double.infinity,
//       height: 45.h,
//       // margin: EdgeInsets.symmetric(horizontal: 20.w),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(50),
//       ),
//       child: Padding(
//         padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 12.h),
//         child: Row(
//           children: [
//             Icon(
//               Icons.location_pin,
//               color: Colors.red,
//             ),
//             SizedBox(
//               width: 5.w,
//             ),
//             Text(
//               title,
//               style: TextStyle(color: AppColors.dividerGrey, fontSize: 12.sp),
//             ),
//             Text(
//               _selectedDestination.toString(),
//               style: TextStyle(color: AppColors.primaryGrey, fontSize: 14.sp),
//             )
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _transportationOption(
//       {required IconData icon, required String label, required String mode}) {
//     return GestureDetector(
//       onTap: () async {
//         setState(() {
//           _selectedMode = mode;
//           _polylines.clear();
//           // Update directions based on the selected mode
//         });
//         await _fetchAndDrawRoutes();
//       },
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Container(
//             decoration: BoxDecoration(
//               shape: BoxShape.rectangle,
//               borderRadius: BorderRadius.all(Radius.circular(8.sp)),
//               color: _selectedMode == mode
//                   ? AppColors.secondary
//                   : AppColors.textField,
//               border: _selectedMode == mode
//                   ? Border.all(
//                       color: AppColors.primary,
//                       width: 1.w,
//                     )
//                   : Border.all(
//                       color: Colors.white,
//                       width: 1.w,
//                     ),
//             ),
//             padding: EdgeInsets.all(8.sp),
//             child: Icon(icon, color: AppColors.primaryText),
//           ),
//           SizedBox(height: 5.h),
//           // Text(
//           //   label,
//           //   style: TextStyle(
//           //     fontSize: 12.sp,
//           //     color: _selectedMode == mode
//           //         ? AppColors.primaryText
//           //         : AppColors.primaryGrey,
//           //   ),
//           // ),
//         ],
//       ),
//     );
//   }
// }
