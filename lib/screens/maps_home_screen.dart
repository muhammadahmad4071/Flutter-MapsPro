import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:maps/util/app_colors.dart';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapsHomeScreen extends StatefulWidget {
  const MapsHomeScreen({super.key});

  @override
  State<MapsHomeScreen> createState() => _MapsHomeScreenState();
}

class _MapsHomeScreenState extends State<MapsHomeScreen> {
  late GoogleMapController mapController;
  late LatLng _initialPosition;
  // const LatLng(37.7749, -122.4194); // Default location (San Francisco)
  Marker? _startingMarker; // Marker for the user's location
  Marker? _destinationMarker; // Marker for the user's location
  final TextEditingController _searchController = TextEditingController();
  final GoogleMapsPlaces _places =
      GoogleMapsPlaces(apiKey: "AIzaSyBsVw09Zl_Xby65X7ed8Xs2ov8aAhaWiFk");
  List<Prediction> _predictions = [];
  bool isLoading = true;
  String? countryCode;
  // Position? userCurrentPosition;

  @override
  void initState() {
    super.initState();
    _initializeUserLocation();
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  Future<void> _initializeUserLocation() async {
    try {
      // Position position = await _getUserLocation();
      Position position = await _getUserLocation();
      final BitmapDescriptor customIcon = await getCustomIcon();
      setState(() {
        _initialPosition = LatLng(position.latitude, position.longitude);
        _startingMarker = Marker(
          icon: customIcon,
          markerId: const MarkerId('userLocation'),
          position: _initialPosition!,
          infoWindow: const InfoWindow(title: "Your Current Location"),
        );
        isLoading = false; // Stop loading
      });
      countryCode = await getCountryCode(_initialPosition);
      mapController.animateCamera(CameraUpdate.newLatLng(_initialPosition!));
    } catch (e) {
      debugPrint("Error retrieving location: $e");
      setState(() {
        isLoading = false; // Stop loading even if there's an error
      });
    }
  }

  Future<Position> _getUserLocation() async {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return Future.error('Location permission denied');
    }
    return await Geolocator.getCurrentPosition();
  }

  void _moveToUserLocation() async {
    try {
      Position position = await _getUserLocation();
      LatLng userPosition = LatLng(position.latitude, position.longitude);
      mapController.animateCamera(CameraUpdate.newLatLng(userPosition));
    } catch (e) {
      // Handle location error
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
      components:  [Component(Component.country, countryCode.toString())],
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

        if (placeId != null) {
          // Fetch place details to extract country code
          final placeDetailsResponse =
              await _places.getDetailsByPlaceId(placeId);

          if (placeDetailsResponse.isOkay) {
            final addressComponents =
                placeDetailsResponse.result.addressComponents;

            // Extract the country code
            final countryComponent = addressComponents.firstWhere(
              (component) => component.types.contains('country'),
              orElse: () =>
                  AddressComponent(longName: '', shortName: '', types: []),
            );

            return countryComponent.shortName; // Return the ISO country code
          }
        }
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
    final placeDetails = await _places.getDetailsByPlaceId(prediction.placeId!);
    if (placeDetails.isOkay) {
      final location = placeDetails.result.geometry!.location;
      final cityPosition = LatLng(location.lat, location.lng);

      // Retrieve user's current location
      final userPosition = _initialPosition;

      // Fetch distance and duration from Directions API
      final directionsResponse =
          await _fetchDirections(userPosition, cityPosition);
      final distanceText = directionsResponse['distanceText'];
      final durationText = directionsResponse['durationText'];

      setState(() {
        _destinationMarker = Marker(
          markerId: const MarkerId('cityLocation'),
          position: cityPosition,
          infoWindow: InfoWindow(title: prediction.description),
        );
      });

      mapController.animateCamera(CameraUpdate.newLatLngZoom(cityPosition, 14));

      // Dismiss the keyboard when a city is selected
      FocusScope.of(context).unfocus();

      // Show the Bottom Sheet with the details
      showModalBottomSheet(
        backgroundColor: Colors.white,
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) {
          return Padding(
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
                            fontSize: 14.sp, color: AppColors.primaryGrey),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.location_pin, color: AppColors.dividerGrey),
                    SizedBox(width: 5.w),
                    Padding(
                      padding: EdgeInsets.only(top: 3.h),
                      child: Text(
                        distanceText.toString(),
                        style: TextStyle(
                            fontSize: 14.sp, color: AppColors.primaryGrey),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                Divider(color: AppColors.textField),
                Text(
                  prediction.structuredFormatting?.mainText ?? "N/A",
                  style: TextStyle(
                    fontSize: 20.sp,
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  '${prediction.description}',
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
                    padding:
                        EdgeInsets.symmetric(horizontal: 40.w, vertical: 15.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50.sp),
                    ),
                    minimumSize: Size(MediaQuery.of(context).size.width, 50.sp),
                  ),
                  child: Text(
                    'Start',
                    style: TextStyle(
                        fontSize: 16.sp, color: AppColors.primaryText),
                  ),
                ),
              ],
            ),
          );
        },
      );

      _predictions = [];
    } else {
      debugPrint("Error fetching place details: ${placeDetails.errorMessage}");
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: isLoading
          ? Center(
              child: CircularProgressIndicator(), // Show progress while loading
            )
          : Scaffold(
              body: Stack(
                children: [
                  GoogleMap(
                    onMapCreated: _onMapCreated,
                    initialCameraPosition: CameraPosition(
                      target: _initialPosition,
                      zoom: 14,
                    ),
                    markers: {
                      if (_startingMarker != null) _startingMarker!,
                      if (_destinationMarker != null) _destinationMarker!,
                    },
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
                            onTap: () => _selectCity(prediction),
                          );
                        },
                      ),
                    ),
                  Positioned(
                      bottom: 100.h,
                      right: 11.w,
                      child: Container(
                        // color: AppColors.primary.withValues(alpha: 0.9),
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 36.h,
                        width: 36.w,
                        child: Center(
                          child: IconButton(
                              iconSize: 22.sp,
                              color: AppColors.primaryGrey,
                              onPressed: _moveToUserLocation,
                              icon: Icon(Icons.my_location_outlined)),
                        ),
                      )
                      // IconButton.filled(onPressed: _moveToUserLocation, icon: Icon(Icons.my_location_outlined),color: AppColors.primary,),
                      ),
                ],
              ),
            ),
    );
  }
}
