import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_webservice/directions.dart' as gmaps;
import 'package:google_maps_webservice/places.dart';
import 'package:http/http.dart' as http;
import 'package:maps/screens/no_internet.dart';
import 'package:maps/util/app_colors.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;

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
  late LatLng _destinationPosition;
  Marker? _startingMarker;
  Marker? _destinationMarker;
  TextEditingController _searchController = TextEditingController();
  final GoogleMapsPlaces _places = GoogleMapsPlaces(apiKey: myApiKey);
  final gmaps.GoogleMapsDirections _directions =
      gmaps.GoogleMapsDirections(apiKey: myApiKey);
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
  String _selectedMode = "driving";

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
    FocusScope.of(context).unfocus();
    setState(() {
      _predictions.clear();
    });

    final placeDetails = await _places.getDetailsByPlaceId(prediction.placeId!);

    if (placeDetails.isOkay) {
      final location = placeDetails.result.geometry!.location;
      _destinationPosition = LatLng(location.lat, location.lng);

      setState(() {
        _prediction = prediction;
        _destinationMarker = Marker(
          markerId: const MarkerId('cityLocation'),
          position: _destinationPosition,
          infoWindow: InfoWindow(title: prediction.description),
        );
        showBottomSheet = true;
      });

      mapController
          .animateCamera(CameraUpdate.newLatLngZoom(_destinationPosition, 14));

      // Fetch and draw routes after destination is selected
      await _fetchAndDrawRoutes();
    } else {
      debugPrint("Error fetching place details: ${placeDetails.errorMessage}");
    }

    // Dismiss the keyboard when a city is selected
  }

// Fetch and draw routes based on the current travel mode
  Future<void> _fetchAndDrawRoutes() async {
    // _polylines.clear();
    try {
      if (_initialPosition == null || _destinationPosition == null) {
        throw Exception("Initial or destination position is not set.");
      }

      final directionsUrl =
          'https://maps.googleapis.com/maps/api/directions/json?origin=${_initialPosition.latitude},${_initialPosition.longitude}&destination=${_destinationPosition.latitude},${_destinationPosition.longitude}&mode=$_selectedMode&alternatives=true&key=AIzaSyBsVw09Zl_Xby65X7ed8Xs2ov8aAhaWiFk';
      debugPrint("Fetching directions: $directionsUrl");

      final response = await http.get(Uri.parse(directionsUrl));
      debugPrint("Fetching directions decoded response: $response");
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final legs = route['legs'][0];

          setState(() {
            distanceText = legs['distance']['text'];
            durationText = legs['duration']['text'];
          });

          // Draw routes
          await getRoutesAndDrawPolylines();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No routes found for the selected mode.'),
              backgroundColor: Colors.red, // Optional: Set a background color
              duration:
                  Duration(seconds: 3), // Optional: Duration of the snackbar
            ),
          );
          // throw Exception('No routes found for the selected mode.');
        }
      } else {
        throw Exception('Failed to load directions: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching directions: $e');
      setState(() {
        distanceText = 'N/A';
        durationText = 'N/A';
      });
    }
  }

// Fetch and draw polylines for routes
  // Update your function to use the correct Route type
  Future<void> getRoutesAndDrawPolylines() async {
    try {
      final _travelMode = getTravelMode(_selectedMode);

      debugPrint('Fetching routes for mode: $_selectedMode');
      setState(() {
        _polylines.clear(); // Clear previous polylines before fetching new ones
      });

      final directionsResponse = await _directions.directions(
        gmaps.Location(
          lat: _initialPosition.latitude,
          lng: _initialPosition.longitude,
        ),
        gmaps.Location(
          lat: _destinationPosition.latitude,
          lng: _destinationPosition.longitude,
        ),
        travelMode: _travelMode,
        alternatives: true,
      );

      if (directionsResponse.isOkay) {
        final PolylinePoints polylinePoints = PolylinePoints();
        double shortestDistance = double.infinity;
        gmaps.Route? shortestRoute;

        final newPolylines = <maps.Polyline>{};

        for (gmaps.Route route in directionsResponse.routes) {
          final encodedPolyline = route.overviewPolyline.points;
          final decodedPoints = polylinePoints.decodePolyline(encodedPolyline);
          final polylineLatLng = decodedPoints
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();

          final routeDistance = route.legs[0].distance.value;

          // Find the shortest route
          if (routeDistance < shortestDistance) {
            shortestDistance = routeDistance.toDouble();
            shortestRoute = route;
            debugPrint("myDebugPoly routeDistance: $routeDistance");
            debugPrint(
                "myDebugPoly shortestRoute: ${shortestRoute.legs[0].distance.value}");
          }

          // Create a unique polyline for each route
          final polylineId = PolylineId(route.summary);
          newPolylines.add(maps.Polyline(
            polylineId: polylineId,
            points: polylineLatLng,
            color: Colors.grey,
            width: 5,
            consumeTapEvents: true,
            onTap: () {
              debugPrint("myDebugPoly _onRouteSelected tapped");
              _onRouteSelected(route, polylineId);
            },
          ));
        }

        // Highlight the shortest route
        if (shortestRoute != null) {
          final shortestPolylineId = PolylineId(shortestRoute.summary);
          newPolylines.add(
            newPolylines
                .firstWhere(
                    (polyline) => polyline.polylineId == shortestPolylineId)
                .copyWith(colorParam: AppColors.primary, widthParam: 8),
          );
          debugPrint(
              "myDebugPoly shortestRoute yellow polylineCreated: $shortestPolylineId");
        }

        // Update state with new polylines
        setState(() {
          _polylines = newPolylines;
        });
        debugPrint(
            "myDebugPoly number of polylines in list ${_polylines.length}");
      } else {
        debugPrint(
            'Error fetching directions: ${directionsResponse.errorMessage}');
      }
    } catch (e) {
      debugPrint('Error fetching routes: $e');
    }
  }

// Use gmaps.Route in the onRouteSelected function
  void _onRouteSelected(gmaps.Route selectedRoute, PolylineId polylineId) {
    // Highlight the selected route
    debugPrint(
        "myDebugPoly _onRouteSelected ${selectedRoute} polylineID: $polylineId");
    final updatedPolylines = _polylines.map((polyline) {
      if (polyline.polylineId == polylineId) {
        return polyline.copyWith(colorParam: AppColors.primary, widthParam: 8);
      } else {
        return polyline.copyWith(colorParam: Colors.grey, widthParam: 5);
      }
    }).toSet();

    setState(() {
      _polylines = updatedPolylines;
      final selectedRouteDetails =
          selectedRoute.legs[0]; // First leg of the route
      distanceText = selectedRouteDetails.distance.text; // Distance as a string
      durationText = selectedRouteDetails.duration.text; // Duration as a string
    });

    debugPrint('Route selected: ${selectedRoute.summary}');
  }

  gmaps.TravelMode getTravelMode(String mode) {
    switch (mode.toLowerCase()) {
      case 'driving':
        return gmaps.TravelMode.driving;
      case 'walking':
        return gmaps.TravelMode.walking;
      case 'bicycling':
        return gmaps.TravelMode.bicycling;
      case 'transit':
        return gmaps.TravelMode.transit;
      default:
        return gmaps.TravelMode.driving;
    }
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
                ? Stack(
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
                                onTap: () {
                                  _searchController.text = prediction
                                          .structuredFormatting?.mainText ??
                                      _searchController.text;
                                  _selectCity(prediction);
                                },
                              );
                            },
                          ),
                        ),
                    ],
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
                color: Colors.white,
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
                      SizedBox(height: 20.h),
                      // Transportation mode selection
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _transportationOption(
                              icon: Icons.directions_car,
                              label: "Car",
                              mode: 'driving'),
                          _transportationOption(
                              icon: Icons.directions_walk,
                              label: "Walking",
                              mode: 'walking'),
                          _transportationOption(
                              icon: Icons.directions_bike,
                              label: "Bike",
                              mode: 'bicycling'),
                          _transportationOption(
                              icon: Icons.train,
                              label: "Transit",
                              mode: 'transit'),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            : SizedBox(),
      ),
    );
  }

  Widget _transportationOption(
      {required IconData icon, required String label, required String mode}) {
    return GestureDetector(
      onTap: () async {
        setState(() {
          _selectedMode = mode;
          _polylines.clear();
          // Update directions based on the selected mode
        });
        await _fetchAndDrawRoutes();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _selectedMode == mode
                  ? AppColors.primary
                  : AppColors.dividerGrey,
            ),
            padding: EdgeInsets.all(8.sp),
            child: Icon(icon, color: Colors.white),
          ),
          SizedBox(height: 5.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: _selectedMode == mode
                  ? AppColors.primaryText
                  : AppColors.primaryGrey,
            ),
          ),
        ],
      ),
    );
  }
}
