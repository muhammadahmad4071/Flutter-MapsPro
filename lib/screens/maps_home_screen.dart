import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_webservice/directions.dart' as gmaps;
import 'package:google_maps_webservice/places.dart';
import 'package:http/http.dart' as http;
import 'package:maps/screens/no_internet.dart';
import 'package:maps/util/app_colors.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;
import 'package:location/location.dart' as loc;

// import '../util/permission_services.dart';

class MapsHomeScreen extends StatefulWidget {
  const MapsHomeScreen({super.key});

  @override
  State<MapsHomeScreen> createState() => _MapsHomeScreenState();
}

class _MapsHomeScreenState extends State<MapsHomeScreen> {
  static const myApiKey = "AIzaSyBsVw09Zl_Xby65X7ed8Xs2ov8aAhaWiFk";
  TextEditingController _searchController = TextEditingController();

  final GoogleMapsPlaces _places = GoogleMapsPlaces(apiKey: myApiKey);
  final gmaps.GoogleMapsDirections _directions =
      gmaps.GoogleMapsDirections(apiKey: myApiKey);
  GoogleMapController? mapController;
  late LatLng _initialPosition;
  late LatLng _destinationPosition;
  Marker? _startingMarker;
  Marker? _destinationMarker;
  Set<maps.Polyline> _polylines = {};
  List<Prediction> _predictions = [];
  late Prediction _prediction;
  String? distanceText;
  String? durationText;
  String? tollInfoText;

  String _selectedMode = "driving";
  String? countryCode;
  bool isLoading = true;
  bool showBottomSheet = false;
  bool hasLocationPermission = false;
  bool isInternetConnected = true;
  // Position? userCurrentPosition;
  // Connectivity
  final Connectivity _connectivity = Connectivity();
  List<ConnectivityResult> _connectionStatus = [ConnectivityResult.none];
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  final loc.Location _location = loc.Location();
  late StreamSubscription<loc.LocationData> _locationSubscription;

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
    bool permissionGranted = await _checkLocationPermission();
    if (permissionGranted) {
      await _initializeUserLocation();
    } else {
      setState(() => isLoading = false); // Stop loading if no permission
    }
    debugPrint("myDebug isLoading _initializeApp() $isLoading");
  }

  Future<bool> _checkLocationPermission() async {
    // location
    loc.PermissionStatus permissionStatus = await _location.requestPermission();
    if (permissionStatus == loc.PermissionStatus.granted) {
      setState(() => hasLocationPermission = true);
      debugPrint("myDebugLoc isLoading _checkLocationPermission() $isLoading");
      return true;
    } else {
      setState(() {
        hasLocationPermission = false;
        // isLoading = false; // byme
      });
      return false;
    }
    //geolocator
    // LocationPermission permission = await Geolocator.requestPermission();

    // if (permission == LocationPermission.denied ||
    //     permission == LocationPermission.deniedForever) {
    //   setState(() {
    //     hasLocationPermission = false;
    //     isLoading = false;
    //     debugPrint("myDebug isLoading _checkLocationPermission() $isLoading");
    //   });
    //   return false;
    // } else {
    //   setState(() {
    //     hasLocationPermission = true;
    //   });
    //   return true;
    // }
  }

  Future<void> _initializeUserLocation() async {
    try {
      bool isServiceEnabled = await _location.serviceEnabled();
      if (!isServiceEnabled) {
        isServiceEnabled = await _location.requestService();
        if (!isServiceEnabled) {
          throw Exception("Location services are disabled.");
        }
      }
      final BitmapDescriptor customIcon = await getCustomIcon();

      // Get the initial location
      final locationData = await _location.getLocation();
      _updateUserLocation(locationData, customIcon);
      countryCode = await getCountryCode(LatLng(locationData.latitude!, locationData.longitude!));
      // Listen for location updates
      _locationSubscription =
          _location.onLocationChanged.listen((loc.LocationData newLocation) {
        _updateUserLocation(newLocation, customIcon);
      });
      // setState(() => isLoading = false); // byme
    } catch (e) {
      debugPrint("Error initializing user location: $e");
      setState(() => isLoading = false);
    }

    //geoLocator
    // setState(() {
    //   isLoading = true;
    //   // });
    //   final position = await Geolocator.getCurrentPosition();
    //   final BitmapDescriptor customIcon = await getCustomIcon();
    //   final userLatLng = LatLng(position.latitude, position.longitude);

    //   setState(() {
    //     _initialPosition = userLatLng;
    //     _startingMarker = Marker(
    //       icon: customIcon,
    //       markerId: const MarkerId('userLocation'),
    //       position: userLatLng,
    //       infoWindow: const InfoWindow(title: "Your Current Location"),
    //     );
    //     isLoading = false; // Stop loading
    //     debugPrint("myDebug isLoading _initializeUserLocation() $isLoading");
    //   });

    //   countryCode = await getCountryCode(userLatLng);
    //   mapController.animateCamera(CameraUpdate.newLatLng(userLatLng));
    // } catch (e) {
    //   debugPrint("myDebug Error retrieving location: $e");
    //   setState(() => isLoading = false);
    // }
  }

  void _updateUserLocation(
      loc.LocationData locationData, BitmapDescriptor _customIcon) {
    final userLatLng = LatLng(locationData.latitude!, locationData.longitude!);

    // GeoLocator
    setState(() {
      _initialPosition = userLatLng;
      _startingMarker = Marker(
        icon: _customIcon,
        markerId: const MarkerId('userLocation'),
        position: userLatLng,
        infoWindow: const InfoWindow(title: "Your Current Location"),
      );
      isLoading = false; // Stop loading
      debugPrint("myDebug isLoading _initializeUserLocation() $isLoading");
    });

    // location
    // setState(() {
    //   _initialPosition = userLatLng;
    //   _startingMarker = Marker(
    //     markerId: const MarkerId('userLocation'),
    //     position: userLatLng,
    //     icon: customIcon,
    //     infoWindow: const InfoWindow(title: "Your Current Location"),
    //   );
    // });

    mapController?.animateCamera(CameraUpdate.newLatLng(userLatLng));
  }

  Future<void> _moveToUserLocation() async {
    try {
      if (!hasLocationPermission) {
        debugPrint("myDebug Permission not granted. Cannot move to location.");
        return;
      }

//location
      final locationData = await _location.getLocation();
      final userLatLng =
          LatLng(locationData.latitude!, locationData.longitude!);
      mapController?.animateCamera(CameraUpdate.newLatLngZoom(userLatLng, 14));
      // geolocator
      // final position = await Geolocator.getCurrentPosition();
      // final userLatLng = LatLng(position.latitude, position.longitude);
      // mapController.animateCamera(CameraUpdate.newLatLngZoom(userLatLng, 14));
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

      mapController!
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
          'https://maps.googleapis.com/maps/api/directions/json?origin=${_initialPosition.latitude},${_initialPosition.longitude}&destination=${_destinationPosition.latitude},${_destinationPosition.longitude}&mode=$_selectedMode&alternatives=true&key=$myApiKey';
      // 'https://maps.googleapis.com/maps/api/directions/json?origin=New+York,NY&destination=Washington,DC&key=$myApiKey';
      debugPrint("Fetching directions: $directionsUrl");

      final response = await http.get(Uri.parse(directionsUrl));
      debugPrint("Fetching directions decoded response: $response");
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final legs = route['legs'][0];

          // final List<dynamic>? warnings = route['warnings'];
          // bool containsTolls = warnings?.any((warning) =>
          //         warning.toString().toLowerCase().contains('toll')) ??
          //     false;

          // SnackBar(
          //   content: Text('Information about tolls: $containsTolls'),
          //   backgroundColor: Colors.red, // Optional: Set a background color
          //   duration:
          //       Duration(seconds: 3), // Optional: Duration of the snackbar
          // );

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

  void _onRouteSelected(gmaps.Route selectedRoute, PolylineId polylineId) {
    debugPrint(
        "myDebugPoly _onRouteSelected ${selectedRoute} polylineID: $polylineId");
    final updatedPolylines = _polylines.map((polyline) {
      if (polyline.polylineId == polylineId) {
        return polyline.copyWith(colorParam: AppColors.primary, widthParam: 8);
      } else {
        return polyline.copyWith(colorParam: Colors.grey, widthParam: 5);
      }
    }).toSet();

    // Check if the route contains tolls
    final List<dynamic>? warnings = selectedRoute.warnings;
    bool containsTolls = warnings?.any(
            (warning) => warning.toString().toLowerCase().contains('toll')) ??
        false;

    setState(() {
      _polylines = updatedPolylines;
      final selectedRouteDetails =
          selectedRoute.legs[0]; // First leg of the route
      distanceText = selectedRouteDetails.distance.text; // Distance as a string
      durationText = selectedRouteDetails.duration.text; // Duration as a string
      tollInfoText = containsTolls ? "This Route Contain tools" : "Doesn't";
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

  String convertKmToMiles(String distanceText) {
    final kmToMilesFactor = 0.621371;

    // Extract the numeric value from the text
    final regex = RegExp(r"([\d.]+)"); // Match numbers including decimals
    final match = regex.firstMatch(distanceText);

    if (match != null) {
      final kmValue = double.parse(match.group(1)!); // Convert to double
      final milesValue = kmValue * kmToMilesFactor;

      // Return the formatted miles value with 'mi'
      return "${milesValue.toStringAsFixed(2)} mi";
    } else {
      // If no number is found, return the original text
      return distanceText;
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
                      GestureDetector(
                        onTap: () {
                          // Unfocus to dismiss the keyboard
                          FocusScope.of(context).unfocus();
                        },
                        child: GoogleMap(
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
                        right: 20.w,
                        child: CircleAvatar(
                          backgroundColor: Colors.white,
                          radius: 22.sp,
                          // foregroundColor: const Color.fromARGB(255, 206, 158, 0),
                          child: CircleAvatar(
                            backgroundColor: AppColors.secondary,
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
                            // await Geolocator.openAppSettings();
                            // await Geolocator.openLocationSettings();
                            // _checkLocationPermission();
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
                // color: Colors.black,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(25.r), // Top-left corner rounded
                    topRight: Radius.circular(25.r), // Top-right corner rounded
                  ),
                ),
                child: Padding(
                  padding:
                      EdgeInsets.only(left: 16.w, right: 16.w, bottom: 16.w),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 4.h, // Height of the divider
                        width: double
                            .infinity, // Full width or customize as needed
                        margin: EdgeInsets.symmetric(
                            horizontal: 150.w,
                            vertical: 16.h), // Adjust margin as needed
                        decoration: BoxDecoration(
                          color: AppColors.dividerGrey, // Divider color
                          borderRadius:
                              BorderRadius.circular(2.h), // Rounded edges
                        ),
                      ),
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
                      Divider(color: AppColors.textField),
                      // Row(
                      //   crossAxisAlignment: CrossAxisAlignment.center,
                      //   children: [
                      //     Icon(Icons.alt_route_outlined,
                      //         size: 22.sp, color: AppColors.dividerGrey),
                      //     SizedBox(width: 5.w),
                      //     Padding(
                      //       padding: EdgeInsets.only(top: 3.h),
                      //       child: Text(
                      //         tollInfoText ?? "N/A",
                      //         style: TextStyle(
                      //             fontSize: 14.sp,
                      //             color: AppColors.primaryGrey),
                      //         textAlign: TextAlign.center,
                      //       ),
                      //     ),
                      //   ],
                      // ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(Icons.access_time_filled,
                              size: 22.sp, color: AppColors.dividerGrey),
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
                              convertKmToMiles(distanceText.toString()),
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
                            borderRadius: BorderRadius.circular(10.sp),
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
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.all(Radius.circular(8.sp)),
              color: _selectedMode == mode
                  ? AppColors.secondary
                  : AppColors.textField,
              border: _selectedMode == mode
                  ? Border.all(
                      color: AppColors.primary,
                      width: 1.w,
                    )
                  : Border.all(
                      color: Colors.white,
                      width: 1.w,
                    ),
            ),
            padding: EdgeInsets.all(8.sp),
            child: Icon(icon, color: AppColors.primaryText),
          ),
          SizedBox(height: 5.h),
          // Text(
          //   label,
          //   style: TextStyle(
          //     fontSize: 12.sp,
          //     color: _selectedMode == mode
          //         ? AppColors.primaryText
          //         : AppColors.primaryGrey,
          //   ),
          // ),
        ],
      ),
    );
  }
}
