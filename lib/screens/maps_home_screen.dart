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
  LatLng _initialPosition =
      const LatLng(37.7749, -122.4194); // Default location (San Francisco)
  Marker? _userMarker; // Marker for the user's location
  final TextEditingController _searchController = TextEditingController();
  final GoogleMapsPlaces _places = GoogleMapsPlaces(
      apiKey: "AIzaSyBsVw09Zl_Xby65X7ed8Xs2ov8aAhaWiFk");
  List<Prediction> _predictions = [];

  @override
  void initState() {
    super.initState();
    _initializeUserLocation();
  }

  // void _onMapCreated(GoogleMapController controller) {
  //   mapController = controller;
  //   if (_userMarker != null) {
  //     mapController.animateCamera(CameraUpdate.newLatLng(_initialPosition));
  //   }
  // }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  // Future<void> _initializeUserLocation() async {
  //   try {
  //     Position position = await _getUserLocation();
  //     setState(() {
  //       _initialPosition = LatLng(position.latitude, position.longitude);
  //       _userMarker = Marker(
  //         // icon: Icons.location_pin,
  //         icon: BitmapDescriptor.defaultMarker,
  //         markerId: const MarkerId('userLocation'),
  //         position: _initialPosition,
  //         infoWindow: const InfoWindow(title: "Your Current Location"),
  //       );
  //     });
  //     // Move the camera to the user's location
  //     mapController.animateCamera(CameraUpdate.newLatLng(_initialPosition));
  //   } catch (e) {
  //     // Handle location error
  //     debugPrint("Error retrieving location: $e");
  //   }
  // }

  Future<void> _initializeUserLocation() async {
    try {
      Position position = await _getUserLocation();
      setState(() {
        _initialPosition = LatLng(position.latitude, position.longitude);
        _userMarker = Marker(
          markerId: const MarkerId('userLocation'),
          position: _initialPosition,
          infoWindow: const InfoWindow(title: "Your Current Location"),
        );
      });
      mapController.animateCamera(CameraUpdate.newLatLng(_initialPosition));
    } catch (e) {
      debugPrint("Error retrieving location: $e");
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

    final response = await _places.autocomplete(
      query,
      // types: ['(cities)'], // Restrict to cities
    );

    if (response.isOkay) {
      setState(() {
        _predictions = response.predictions;
      });
    } else {
      debugPrint("Places API error: ${response.errorMessage}");
    }
  }

  void _selectCity(Prediction prediction) async {
    final placeDetails = await _places.getDetailsByPlaceId(prediction.placeId!);
    if (placeDetails.isOkay) {
      final location = placeDetails.result.geometry!.location;
      final cityPosition = LatLng(location.lat, location.lng);

      setState(() {
        _userMarker = Marker(
          markerId: const MarkerId('cityLocation'),
          position: cityPosition,
          infoWindow: InfoWindow(title: prediction.description),
        );
      });

      mapController.animateCamera(CameraUpdate.newLatLngZoom(cityPosition, 14));
      // _searchController.clear();
      _predictions = [];
    } else {
      debugPrint("Error fetching place details: ${placeDetails.errorMessage}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Stack(
          children: [
            GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _initialPosition,
                zoom: 14,
              ),
              markers: _userMarker != null ? {_userMarker!} : {},
            ),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
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
                margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 80.h),
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