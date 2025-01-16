import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_webservice/directions.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:http/http.dart' as http;
import 'package:maps/screens/no_internet.dart';
import 'package:maps/util/app_colors.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../util/permission_services.dart';

class MapsHomeScreen extends StatefulWidget {
  const MapsHomeScreen({super.key});

  @override
  State<MapsHomeScreen> createState() => _MapsHomeScreenState();
}

class _MapsHomeScreenState extends State<MapsHomeScreen> {
  static const myApiKey = "AIzaSyBsVw09Zl_Xby65X7ed8Xs2ov8aAhaWiFk";
  late GoogleMapController mapController;
  late LatLng _initialPosition;
  Marker? _startingMarker;
  Marker? _destinationMarker;
  TextEditingController _searchController = TextEditingController();
  final GoogleMapsPlaces _places = GoogleMapsPlaces(apiKey: myApiKey);
  final GoogleMapsDirections _directions =
      GoogleMapsDirections(apiKey: myApiKey);
  Set<maps.Polyline> _polylines = {};
  List<Prediction> _predictions = [];
  late Prediction _prediction;
  bool isLoading = true;
  String? countryCode;
  bool showBottomSheet = false;
  String? distanceText;
  String? durationText;
  bool hasLocationPermission = false;
  // Position? userCurrentPosition;
  // Connectivity
  bool isInternetConnected = true;
  List<ConnectivityResult> _connectionStatus = [ConnectivityResult.none];
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _initializeApp();
    initConnectivity();
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
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
    // Don't forget to cancel the subscription when the widget is disposed
    _connectivitySubscription.cancel();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  Future<void> _initializeApp() async {
    // Check location permissions and initialize user location
    bool permissionGranted = await _checkLocationPermission();
    if (permissionGranted) {
      await _initializeUserLocation();
    } else {
      setState(() => isLoading = false); // Stop loading if no permission
    }
    debugPrint("myDebug isLoading _initializeApp() $isLoading");
  }

  Future<bool> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.requestPermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() {
        hasLocationPermission = false;
        isLoading = false;
        debugPrint("myDebug isLoading _checkLocationPermission() $isLoading");
      });
      return false;
    } else {
      setState(() {
        hasLocationPermission = true;
      });
      return true;
    }
  }

  Future<void> _initializeUserLocation() async {
    try {
      setState(() {
        isLoading = true;
      });
      final position = await Geolocator.getCurrentPosition();
      final BitmapDescriptor customIcon = await getCustomIcon();
      final userLatLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _initialPosition = userLatLng;
        _startingMarker = Marker(
          icon: customIcon,
          markerId: const MarkerId('userLocation'),
          position: userLatLng,
          infoWindow: const InfoWindow(title: "Your Current Location"),
        );
        isLoading = false; // Stop loading
        debugPrint("myDebug isLoading _initializeUserLocation() $isLoading");
      });

      countryCode = await getCountryCode(userLatLng);
      mapController.animateCamera(CameraUpdate.newLatLng(userLatLng));
    } catch (e) {
      debugPrint("myDebug Error retrieving location: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _moveToUserLocation() async {
    try {
      if (!hasLocationPermission) {
        debugPrint("Permission not granted. Cannot move to location.");
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final userLatLng = LatLng(position.latitude, position.longitude);
      mapController.animateCamera(CameraUpdate.newLatLng(userLatLng));
    } catch (e) {
      debugPrint("Error moving to location: $e");
    }
  }

  void _searchCities(String query) async {
    if (query.isEmpty) {
      setState(() {
        _predictions = [];
      });
      return;
    }

    // if(countryCode!.isNotEmpty){
    final response = await _places.autocomplete(
      query,
      // types: ['(cities)'], // Restrict to cities
      components: [Component(Component.country, countryCode.toString())],
    );
    // }

    if (response.isOkay) {
      setState(() {
        _predictions = response.predictions;
      });
    } else {
      debugPrint("Places API error: ${response.errorMessage}");
    }
  }

  Future<String?> getCountryCode(LatLng userCoordinates) async {
    try {
      // Get the nearest place details using the Places API reverse geocode
      final response = await _places.searchNearbyWithRadius(
        Location(lat: userCoordinates.latitude, lng: userCoordinates.longitude),
        50, // 50 meters radius for higher accuracy
      );

      if (response.isOkay && response.results.isNotEmpty) {
        final placeId = response.results.first.placeId;

        // if (placeId != null) {
        // Fetch place details to extract country code
        final placeDetailsResponse = await _places.getDetailsByPlaceId(placeId);

        if (placeDetailsResponse.isOkay) {
          final addressComponents =
              placeDetailsResponse.result.addressComponents;

          // Extract the country code
          final countryComponent = addressComponents.firstWhere(
            (component) => component.types.contains('country'),
            orElse: () =>
                AddressComponent(longName: '', shortName: '', types: []),
          );
          print("myDebug country ${countryComponent.shortName}");
          return countryComponent.shortName; // Return the ISO country code
        }
        // }
      }
      return null; // Return null if no country found
    } catch (e) {
      print('Error fetching country code: $e');
      return null;
    }
  }

  String getCityTitle(Prediction prediction) {
    String description = prediction.description ?? '';
    return description.split(',')[0]; // Extract the first part
  }

  Future<BitmapDescriptor> getCustomIcon() async {
    return await BitmapDescriptor.asset(
      ImageConfiguration(size: Size(24.w, 24.h)), // Specify desired size
      'assets/current_location_marker.png',
      // 'assets/anim_location.gif',21302130
    );
  }

  void _selectCity(Prediction prediction) async {
    setState(() {
    _predictions.clear();
  });
    // void _selectCity(Prediction prediction) async {
    final placeDetails = await _places.getDetailsByPlaceId(prediction.placeId!);
    if (placeDetails.isOkay) {
      final location = placeDetails.result.geometry!.location;
      final cityPosition = LatLng(location.lat, location.lng);

      // Retrieve user's current location
      final userPosition = _initialPosition;
      getRoutesAndDrawPolylines(_initialPosition, cityPosition);

      // Fetch distance and duration from Directions API
      final directionsResponse =
          await _fetchDirections(userPosition, cityPosition);
      distanceText = directionsResponse['distanceText'];
      durationText = directionsResponse['durationText'];

      setState(() {
        _prediction = prediction;
        _destinationMarker = Marker(
          markerId: const MarkerId('cityLocation'),
          position: cityPosition,
          infoWindow: InfoWindow(title: prediction.description),
        );
        showBottomSheet = true;
      });

      mapController.animateCamera(CameraUpdate.newLatLngZoom(cityPosition, 14));

      // Dismiss the keyboard when a city is selected
      FocusScope.of(context).unfocus();

      // _predictions = [];
    } else {
      debugPrint("Error fetching place details: ${placeDetails.errorMessage}");
      setState(() {
        showBottomSheet = false;
      });
    }
  }

// Helper function to fetch directions using Directions API
  Future<Map<String, String>> _fetchDirections(
      LatLng origin, LatLng destination) async {
    final directionsUrl =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&key=AIzaSyBsVw09Zl_Xby65X7ed8Xs2ov8aAhaWiFk';
    print("Distance Function: $directionsUrl");
    try {
      final response = await http.get(Uri.parse(directionsUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final route = data['routes'][0];
        final legs = route['legs'][0];

        final distanceText = legs['distance']['text'];
        final durationText = legs['duration']['text'];

        return {'distanceText': distanceText, 'durationText': durationText};
      } else {
        throw Exception('Failed to load directions');
      }
    } catch (e) {
      debugPrint('Error fetching directions: $e');
      return {'distanceText': 'N/A', 'durationText': 'N/A'};
    }
  }

  Future<void> getRoutesAndDrawPolylines(
      LatLng origin, LatLng destination) async {
    try {
      final directionsResponse = await _directions.directions(
        Location(lat: origin.latitude, lng: origin.longitude),
        Location(lat: destination.latitude, lng: destination.longitude),
        alternatives: true,
      );

      if (directionsResponse.isOkay) {
        // Clear previous polylines
        _polylines.clear();

        PolylinePoints polylinePoints = PolylinePoints();
        double shortestDistance = double.infinity;
        Map<String, dynamic>? shortestRoute;

        for (var route in directionsResponse.routes) {
          final encodedPolyline = route.overviewPolyline.points;
          final decodedPoints = polylinePoints.decodePolyline(encodedPolyline);
          final polylineLatLng = decodedPoints
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();

          final routeDistance = route.legs[0].distance.value;

          // Find the shortest route
          if (routeDistance < shortestDistance) {
            shortestDistance = routeDistance.toDouble();
            shortestRoute = route.toJson();
          }

          // Create a unique polyline for each route
          final polylineId = PolylineId(route.summary);
          _polylines.add(maps.Polyline(
            polylineId: polylineId,
            points: polylineLatLng,
            color: Colors.grey,
            width: 5,
            onTap: () => _onRouteSelected(
                route.toJson(), polylineId), // Ensure onTap works here
          ));
        }

        // Highlight shortest route
        if (shortestRoute != null) {
          _onRouteSelected(shortestRoute, PolylineId(shortestRoute['summary']));
        }
      } else {
        print('Error fetching directions: ${directionsResponse.errorMessage}');
      }
      //  setState(() {

      // });
    } catch (e) {
      print('Error fetching directions: $e');
    }
  }

  void _onRouteSelected(Map<String, dynamic> route, PolylineId polylineId) {
    setState(() {
      print("Tapped on Polyline: $polylineId");

      // Reset all polyline colors to grey
      _polylines = _polylines.map((polyline) {
        return polyline.copyWith(colorParam: Colors.grey, widthParam: 5);
      }).toSet();

      // Find the selected polyline and change its color to blue
      final selectedPolyline = _polylines.firstWhere(
        (polyline) => polyline.polylineId == polylineId,
      );

      _polylines.remove(selectedPolyline);

      _polylines.add(
        // selectedPolyline.copyWith(colorParam: Colors.blue, widthParam: 8),
        selectedPolyline.copyWith(colorParam: AppColors.primary, widthParam: 8),
      );

      // Update the distance and duration for the selected route
      // final legs = route['legs'][0];
      // distanceText = legs['distance']['text'];
      // durationText = legs['duration']['text'];
      // setState(() {

      // });

      print("Selected Route: ${route['summary']}");
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!isInternetConnected) {
      return NoInternetWidget();
    }
    return SafeArea(
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20.sp),
                    Text(
                      "Loading Maps...",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: AppColors.primaryText,
                        fontSize: 14.sp,
                      ),
                    ),
                  ],
                ),
              )
            : hasLocationPermission
                ? GestureDetector(
                      onTap: () {
          // Unfocus to dismiss the keyboard
                  FocusScope.of(context).unfocus();
                  },
                  child: Stack(
                      children: [
                        GoogleMap(
                          onMapCreated: _onMapCreated,
                          compassEnabled: false,
                          mapType: MapType.terrain,
                          initialCameraPosition: CameraPosition(
                            target: _initialPosition,
                            zoom: 14,
                          ),
                          markers: {
                            if (_startingMarker != null) _startingMarker!,
                            if (_destinationMarker != null) _destinationMarker!,
                          },
                          polylines: _polylines,
                          trafficEnabled: true,
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(
                              vertical: 24, horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: _searchCities,
                            style: const TextStyle(color: Colors.black),
                            cursorColor: Colors.blue,
                            decoration: const InputDecoration(
                              labelText: "Search",
                              prefixIcon: Icon(Icons.search, color: Colors.grey),
                              border: InputBorder.none,
                            ),
                            keyboardType: TextInputType.streetAddress,
                          ),
                        ),
                        Positioned(
                          top: 100.h,
                          right: 30.w,
                          child: Container(
                            color: Colors.white.withAlpha(230),
                            height: 36.h,
                            width: 36.w,
                            child: Center(
                              child: IconButton(
                                iconSize: 22.sp,
                                color: AppColors.primaryGrey,
                                onPressed: _moveToUserLocation,
                                icon: Icon(Icons.my_location_outlined),
                              ),
                            ),
                          ),
                        ), 
                        if (_predictions.isNotEmpty)
                          Container(
                            margin: EdgeInsets.symmetric(
                                horizontal: 20.w, vertical: 80.h),
                            color: Colors.white,
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _predictions.length,
                              itemBuilder: (context, index) {
                                final prediction = _predictions[index];
                                return ListTile(
                                  title: Text(prediction.description ?? ''),
                                  onTap: (){ 
                                    _searchController.text = prediction.structuredFormatting?.mainText ?? _searchController.text;
                                    _selectCity(prediction);},

                                );
                              },
                            ),
                          ),
                        
                      ],
                    ),
                )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_off,
                          size: 80.sp,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 20.sp),
                        Text(
                          "Please allow location permissions\nto use the app",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16.sp,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 20.sp),
                        ElevatedButton(
                          onPressed: () async {
                            await Geolocator.openAppSettings();
                            await Geolocator.openLocationSettings();
                            _checkLocationPermission();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: EdgeInsets.symmetric(
                                horizontal: 40.w, vertical: 15.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50.sp),
                            ),
                          ),
                          child: Text(
                            'Grant Permissions',
                            style: TextStyle(
                                fontSize: 16.sp, color: AppColors.primaryText),
                          ),
                        ),
                      ],
                    ),
                  ),
        bottomSheet: showBottomSheet
            ? Container(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(Icons.access_time_filled,
                              color: AppColors.dividerGrey),
                          SizedBox(width: 5.w),
                          Padding(
                            padding: EdgeInsets.only(top: 3.h),
                            child: Text(
                              durationText ?? "N/A",
                              style: TextStyle(
                                  fontSize: 14.sp,
                                  color: AppColors.primaryGrey),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(Icons.location_pin,
                              color: AppColors.dividerGrey),
                          SizedBox(width: 5.w),
                          Padding(
                            padding: EdgeInsets.only(top: 3.h),
                            child: Text(
                              distanceText.toString(),
                              style: TextStyle(
                                  fontSize: 14.sp,
                                  color: AppColors.primaryGrey),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      Divider(color: AppColors.textField),
                      Text(
                        _prediction.structuredFormatting?.mainText ?? "N/A",
                        style: TextStyle(
                          fontSize: 20.sp,
                          color: AppColors.primaryText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        '${_prediction.description}',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppColors.dividerGrey,
                        ),
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          // Handle start button click
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: EdgeInsets.symmetric(
                              horizontal: 40.w, vertical: 15.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50.sp),
                          ),
                          minimumSize:
                              Size(MediaQuery.of(context).size.width, 50.sp),
                        ),
                        child: Text(
                          'Start',
                          style: TextStyle(
                              fontSize: 16.sp, color: AppColors.primaryText),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : SizedBox(),
      ),
    );
  }
}





// Commented backed up functions
// Select City Working
// void _selectCity(Prediction prediction) async {
//   final placeDetails = await _places.getDetailsByPlaceId(prediction.placeId!);
//   if (placeDetails.isOkay) {
//     final location = placeDetails.result.geometry!.location;
//     final cityPosition = LatLng(location.lat, location.lng);

//     setState(() {
//       _userMarker = Marker(
//         markerId: const MarkerId('cityLocation'),
//         position: cityPosition,
//         infoWindow: InfoWindow(title: prediction.description),
//       );
//     });

//     mapController.animateCamera(CameraUpdate.newLatLngZoom(cityPosition, 14));

//     // Dismiss the keyboard when a city is selected
//     FocusScope.of(context).unfocus();

//     // Show the Bottom Sheet with the details
//     showModalBottomSheet(
//       backgroundColor: Colors.white,
//       context: context,
//       isScrollControlled: true,  // To ensure the bottom sheet can expand
//       builder: (BuildContext context) {
//         return           Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 crossAxisAlignment: CrossAxisAlignment.center,
//                 children: [
//                 Icon(Icons.access_time_filled, color: AppColors.dividerGrey,),
//                 SizedBox(width: 5.w,),
//                 Padding(
//                   padding: EdgeInsets.only(top: 3.h),
//                   child: Text("10 Min", style: TextStyle(fontSize: 14.sp, color: AppColors.primaryGrey), textAlign: TextAlign.center,),
//                 )
//               ]),
//               Row(
//                 crossAxisAlignment: CrossAxisAlignment.center,
//                 children: [
//                 Icon(Icons.location_pin, color: AppColors.dividerGrey,),
//                 SizedBox(width: 5.w,),
//                 Padding(
//                   padding: EdgeInsets.only(top: 3.h),
//                   child: Text('${prediction.distanceMeters}', style: TextStyle(fontSize: 14.sp, color: AppColors.primaryGrey), textAlign: TextAlign.center,),
//                 )
//               ]),
//               Divider(color: AppColors.textField,),
//               Text(
//                 '${prediction.id}',
//                 style: TextStyle(
//                   fontSize: 20.sp,
//                   color: AppColors.primaryText,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               SizedBox(height: 10.h),
//               Text(
//                 '${prediction.description}',
//                 style: TextStyle(
//                   fontSize: 14.sp,
//                   color: AppColors.dividerGrey,
//                 ),
//               ),
//               SizedBox(height: 20),
//               ElevatedButton(
//                   onPressed: (){
//                     // _signIn();
//                   },
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: AppColors.primary,
//                     padding: EdgeInsets.symmetric(
//                         horizontal: 40.w,
//                         vertical: 15.h),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(
//                           50.sp),
//                     ),
//                     minimumSize: Size(MediaQuery.of(context).size.width, 50.sp),
//                   ),
//                   child: Text(
//                     'Start',
//                     style: TextStyle(
//                         fontSize: 16.sp, color: AppColors.primaryText),
//                   ),
//                 ),
//             ],
//           ),
//         );
//       },
//     );

//     // _searchController.clear();
//     _predictions = [];
//   } else {
//     debugPrint("Error fetching place details: ${placeDetails.errorMessage}");
//   }
// }

// Future<void> getRoutesAndDrawPolylines(
//     LatLng origin, LatLng destination) async {
//   try {
//     // Request directions
//     final directionsResponse = await _directions.directions(
//       Location(lat: origin.latitude, lng: origin.longitude),
//       Location(lat: destination.latitude, lng: destination.longitude),
//       alternatives: true, // Get alternative routes
//     );

//     if (directionsResponse.isOkay) {
//       // Clear previous polylines
//       _polylines.clear();

//       // Initialize PolylinePoints for decoding polyline strings
//       PolylinePoints polylinePoints = PolylinePoints();

//       // Find the shortest route by comparing distances
//       int shortestRouteIndex = 0;
//       double shortestDistance = double.infinity;

//       for (int i = 0; i < directionsResponse.routes.length; i++) {
//         final route = directionsResponse.routes[i];
//         final distance = route.legs[0].distance.value;

//         if (distance < shortestDistance) {
//           shortestDistance = distance.toDouble();
//           shortestRouteIndex = i;
//         }
//       }

//       // Draw polylines for all routes
//       for (int i = 0; i < directionsResponse.routes.length; i++) {
//         final route = directionsResponse.routes[i];
//         final encodedPolyline = route.overviewPolyline.points;

//         // Decode polyline
//         final decodedPoints = polylinePoints.decodePolyline(encodedPolyline);
//         final polylineLatLng = decodedPoints
//             .map((point) => LatLng(point.latitude, point.longitude))
//             .toList();

//         // Determine polyline color
//         final color = (i == shortestRouteIndex) ? Colors.blue : Colors.grey;

//         // Add polyline to the map
//         final polylineId = PolylineId(route.summary);
//         _polylines.add(maps.Polyline(
//           polylineId: polylineId,
//           points: polylineLatLng,
//           color: color,
//           width: 5,
//           onTap: () => _onRouteSelected(route, polylineId),
//         ));
//       }

//       // Set shortest route as selected initially
//       _onRouteSelected(
//         directionsResponse.routes[shortestRouteIndex],
//         PolylineId(directionsResponse.routes[shortestRouteIndex].summary),
//       );
//     } else {
//       print('Error fetching directions: ${directionsResponse.errorMessage}');
//     }
//   } catch (e) {
//     print('Error fetching directions: $e');
//   }
// }

// void _onRouteSelected(DirectionsRoute route, PolylineId polylineId) {
//   // Highlight selected polyline
//   setState(() {
//     _polylines = _polylines.map((polyline) {
//       if (polyline.polylineId == polylineId) {
//         return polyline.copyWith(colorParam: Colors.blue);
//       }
//       return polyline.copyWith(colorParam: Colors.grey);
//     }).toSet();

//     // Update distance and duration
//     final legs = route.legs[0];
//     distanceText = legs.distance.text;
//     durationText = legs.duration.text;
//   });

//   print("Selected Route: ${route.summary}");
// }


  // Future<void> getRoutesAndDrawPolylines(
  //     LatLng origin, LatLng destination) async {
  //   try {
  //     // Request directions
  //     final directionsResponse = await _directions.directions(
  //       Location(lat: origin.latitude, lng: origin.longitude),
  //       Location(lat: destination.latitude, lng: destination.longitude),
  //       alternatives: true, // Set to true to get alternative routes
  //     );

  //     if (directionsResponse.isOkay) {
  //       // Clear previous polylines
  //       _polylines.clear();

  //        // Initialize PolylinePoints for decoding polyline strings
  //     PolylinePoints polylinePoints = PolylinePoints();

  //        // Loop through all the routes and draw polylines
  //     for (var route in directionsResponse.routes) {
  //       final encodedPolyline = route.overviewPolyline.points;

  //       // Decode the polyline string into a list of LatLng points
  //       final decodedPoints = polylinePoints.decodePolyline(encodedPolyline);

  //       final polylineLatLng = decodedPoints.map((point) {
  //         return LatLng(point.latitude, point.longitude);
  //       }).toList();

  //       // Add polyline to the map
  //       final polylineId = PolylineId(route.summary); // Use summary as the ID
  //       _polylines.add(maps.Polyline(
  //         polylineId: polylineId,
  //         points: polylineLatLng,
  //         color: Colors.blue, // Choose color for the polyline
  //         width: 5, // Set the width of the polyline
  //       ));
  //     }
  //     } else {
  //       print('Error fetching directions: ${directionsResponse.errorMessage}');
  //     }
  //   } catch (e) {
  //     print('Error fetching directions: $e');
  //   }
  // }
