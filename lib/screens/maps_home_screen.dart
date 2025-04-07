import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:http/http.dart' as http;
import 'package:maps/screens/VoiceService.dart';
import 'package:maps/screens/no_internet.dart';
import 'package:maps/screens/signup_screen.dart';
import 'package:maps/util/app_colors.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
// import 'package:google_maps_webservice/directions.dart' as gmaps;
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;
// import 'package:location/location.dart' as loc;
import '../util/helper_functions.dart';

// import '../util/permission_services.dart';

class MapsHomeScreen extends StatefulWidget {
  const MapsHomeScreen({super.key});

  @override
  State<MapsHomeScreen> createState() => _MapsHomeScreenState();
}

class _MapsHomeScreenState extends State<MapsHomeScreen> {
  static const myApiKey = "AIzaSyBsVw09Zl_Xby65X7ed8Xs2ov8aAhaWiFk";
  final TextEditingController _searchController = TextEditingController();

  final GoogleMapsPlaces _places = GoogleMapsPlaces(apiKey: myApiKey);
  // final gmaps.GoogleMapsDirections _directions =
  //     gmaps.GoogleMapsDirections(apiKey: myApiKey);
  GoogleMapController? mapController;
  late LatLng _initialPosition;
  String finalDestinationName = "N/A";
  String finalDestinationDescription = "N/A";
  Marker? _startingMarker;
  BitmapDescriptor? userLocationMarker;
  // Marker? _destinationMarker;

  List<LatLng> _destinationPositions = []; // List of multiple destinations
  List<Marker> _destinationMarkers = []; // Markers for all destinations
  List<Map<String, dynamic>> _stopsInfo =
      []; // Store name, distance, time for each stop

  Set<maps.Polyline> _polylines = {};
  List<Prediction> _predictions = [];
  // late Prediction _prediction;
  String? distanceText;
  String? durationText;
  String? tollInfoText;

  String _selectedMode = "driving";
  String? countryCode;
  bool isLoading = true;
  bool showBottomSheet = false;
  bool hasLocationPermission = false;
  bool isInternetConnected = true;
  bool isJourneyStarted = false;
  bool isMoreStopsAdded = false;
  List<String> navigationInstructions = [];
  // List<String> voiceInstructionList = [];
  // bool isDestinationSelected = false;
  // String destinationText = "N/A";
  // Position? userCurrentPosition;
  // Connectivity
  final Connectivity _connectivity = Connectivity();
  List<ConnectivityResult> _connectionStatus = [ConnectivityResult.none];
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  // final loc.Location _location = loc.Location();
  // late StreamSubscription<loc.LocationData> _locationSubscription;

  late StreamSubscription<Position> _locationSubscription;

  List<LatLng> selectedRoutePoints = [];
  Timer? _permissionCheckTimer;
  bool _isRequestingPermission = false;
  User? _user;

  final VoiceService _voiceService = VoiceService();
  // int _currentInstructionIndex = 0;

  bool containTolls = false;

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
    _initializeApp();
    initConnectivity();
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
    // WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _permissionCheckTimer?.cancel();
    _connectivitySubscription.cancel(); // No need to check for null
    _locationSubscription.cancel(); // No need to check for null

    debugPrint("dispose() called, subscriptions canceled.");

    super.dispose();
  }

//   @override
// void didChangeAppLifecycleState(AppLifecycleState state) {
//   if (state == AppLifecycleState.resumed) {
//     _initializeApp(); // Recheck permissions when app comes back from background
//   }
// }

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

    debugPrint(
        'Connectivity changed: $_connectionStatus bool $isInternetConnected');
  }

  void _onMapCreated(GoogleMapController controller) {
    // mapController = controller;
    mapController = controller;

    // // Load the dark mode JSON from assets
    // String style = await rootBundle.loadString('assets/dark_mode.json');

    // // Apply the style to the map
    // mapController!.setMapStyle(style);
  }

  Future<void> _initializeApp() async {
    try {
      bool permissionGranted = await _checkLocationPermission();
      userLocationMarker = await getCustomIcon();
      if (permissionGranted) {
        await _initializeUserLocation();
      } else {
        setState(() => isLoading = false); // Stop loading if no permission
      }
      // _startPermissionCheck();  // Uncomment
      debugPrint("myDebug isLoading _initializeApp() $isLoading");
    } catch (e) {
      debugPrint("Error initializing App: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _initializeUserLocation() async {
    try {
      // Step 1: Check if location services are enabled
      bool isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        throw Exception("Location services are disabled. Please enable them.");
      }

      // Step 2: Request location permission
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception(
            "Location permission is denied. Please grant permission.");
      } else if (permission == LocationPermission.deniedForever) {
        throw Exception(
            "Location permission is denied forever. Please enable it in app settings.");
      }

      // Step 3: Configure location settings with high accuracy
      LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high, // High accuracy for better precision
        distanceFilter: 5, // Only update if user moves 5 meters
      );

      // Step 4: Get the current location using the updated settings
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );

      // Fetch the country code for user's current location
      countryCode = await getCountryCode(
        LatLng(position.latitude, position.longitude),
      );

      // Step 5: Update user location and the UI
      _updateUserLocation(
          position); // Pass Position object to update user location
      setState(() {
        hasLocationPermission = true;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error initializing user location: $e");

      // Handle error states
      setState(() {
        hasLocationPermission = false;
        isLoading = false; // Set loading to false on error as well
      });

      // Optionally, show a toast or dialog to inform users of the error.
      Fluttertoast.showToast(
        msg: e.toString(),
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  Future<bool> _checkLocationPermission() async {
    if (_isRequestingPermission) return false;
    _isRequestingPermission = true;

    try {
      // Step 1: Check current location permission status
      LocationPermission currentStatus = await Geolocator.checkPermission();

      if (currentStatus == LocationPermission.whileInUse ||
          currentStatus == LocationPermission.always) {
        return true; // Permission is already granted
      }

      // Step 2: Request permission if not granted
      LocationPermission newStatus = await Geolocator.requestPermission();

      if (newStatus == LocationPermission.whileInUse ||
          newStatus == LocationPermission.always) {
        // Step 3: Fetch location if permission granted
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        );

        if (position.longitude == null) {
          throw Exception("Failed to fetch location after permission grant.");
        }

        // Update position and state
        setState(() {
          _initialPosition = LatLng(position.latitude, position.longitude);
          hasLocationPermission = true;
        });

        return true;
      } else {
        // Handle permission denial
        setState(() {
          hasLocationPermission = false;
        });
        return false;
      }
    } catch (e) {
      debugPrint("Error checking location permission: $e");
      setState(() {
        hasLocationPermission = false;
      });
      return false;
    } finally {
      _isRequestingPermission = false;
    }
  }

  void _startPermissionCheck() {
    _permissionCheckTimer?.cancel(); // Cancel previous timer if exists
    _permissionCheckTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      bool permissionGranted = await _checkLocationPermission();
      if (permissionGranted != hasLocationPermission) {
        setState(() {
          hasLocationPermission = permissionGranted;
        });
      }
    });
  }

bool hasReachedDestination(LatLng currentLocation, LatLng? destination, {double thresholdInMeters = 30.0}) {
  if (destination == null) return false;
  final double distance = Geolocator.distanceBetween(
    currentLocation.latitude,
    currentLocation.longitude,
    destination.latitude,
    destination.longitude,
  );

  debugPrint("myDebug Distance to ${destination.latitude}, ${destination.longitude}: $distance meters");
  return distance <= thresholdInMeters;
}


  void _onReachedDestination() {
    _locationSubscription.cancel();

    // Display a notification or dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Destination Reached"),
          content: Text("You have arrived at your destination."),
          actions: [
            TextButton(
              onPressed: () {
                _resetState();
                Navigator.of(context).pop();
              },
              child: Text("OK"),
            ),
          ],
        );
      },
    );
  }

// Function to check if route recalculation is needed
  bool shouldRecalculateRoute(LatLng currentPosition, LatLng? destination) {
    const double deviationThresholdInMiles = 0.0621371; // 0.1 km in miles
    double distanceToRouteInMiles =
        _calculateDistance(currentPosition, _initialPosition) * 0.621371;
    debugPrint(
        "myDebug Recalculating Distance Function ${distanceToRouteInMiles > deviationThresholdInMiles}");
    return distanceToRouteInMiles > deviationThresholdInMiles;
  }

  double _calculateDistance(LatLng start, LatLng end) {
    double distanceInMeters = Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
    return distanceInMeters / 1000; // Convert to kilometers
  }

  // Future<LatLng> getInitialPosition() async {
  //     final locationData = await _location.getLocation();
  //     _initialPosition = LatLng(locationData.latitude!, locationData.longitude!);
  // }

  double _calculateBearing(LatLng start, LatLng end) {
    final double lat1 = start.latitude * pi / 180.0;
    final double lon1 = start.longitude * pi / 180.0;
    final double lat2 = end.latitude * pi / 180.0;
    final double lon2 = end.longitude * pi / 180.0;

    final double dLon = lon2 - lon1;

    final double y = sin(dLon) * cos(lat2);
    final double x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);

    final double bearing = atan2(y, x) * 180.0 / pi;

    return (bearing + 360) % 360; // Ensure positive value
  }

// Function to update the user's location marker
  void _updateUserLocation(Position position) {
    final userLatLng = LatLng(position.latitude, position.longitude);
    double heading =
        position.heading ?? 0.0; // Geolocator provides heading if available

    // Handle polyline logic for nextPoint
    LatLng? nextPoint;
    if (_polylines.isNotEmpty && _polylines.first.points.length > 1) {
      nextPoint = _polylines.first.points[1];
    }

    // Calculate bearing based on the next point or fallback to heading
    final bearing = nextPoint != null
        ? _calculateBearing(userLatLng, nextPoint)
        : heading; // Fallback to device heading if no polyline point is available

    setState(() {
      _initialPosition = userLatLng;

      _startingMarker = Marker(
        markerId: const MarkerId('userLocation'),
        position: userLatLng,
        icon: userLocationMarker ?? BitmapDescriptor.defaultMarker,
        infoWindow: const InfoWindow(title: "Your Current Location"),
        rotation: 0,
        anchor: const Offset(0.5, 0.5), // Center the rotation point
      );
    });

    if (isJourneyStarted) {
      _animateCameraToUserPosition(userLatLng, bearing);
    }

    if (isJourneyStarted) {
      _fetchAndDrawRoutes(currentPosition: userLatLng);
    }
  }

  void _animateCameraToUserPosition(LatLng position, double bearing) {
    // uncomment to active animate camera
    final cameraUpdate = CameraUpdate.newCameraPosition(
      CameraPosition(
        target: position,
        zoom: 20.0,
        bearing: bearing, // Align camera with movement direction
        tilt: 50.0, // Optional: Adds a slight 3D effect for better navigation
      ),
    );

    mapController?.animateCamera(cameraUpdate);
  }

  Future<void> _moveToUserLocation() async {
    try {
      if (!hasLocationPermission) {
        debugPrint("Permission not granted. Cannot move to location.");
        return;
      }

      final locationData = await Geolocator.getCurrentPosition(
        desiredAccuracy:
            LocationAccuracy.high, // High accuracy for better precision
      );
      _updateUserLocation(locationData);
      final userLatLng = LatLng(locationData.latitude, locationData.longitude);

      // Move the camera to the user position (you can uncomment this if needed)
      mapController?.animateCamera(CameraUpdate.newLatLngZoom(userLatLng, 14));
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

    final response = countryCode != null
        ? await _places.autocomplete(
            query,
            components: [Component(Component.country, countryCode.toString())],
          )
        : await _places.autocomplete(
            query,
            // components: [Component(Component.country, countryCode.toString())],
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
          debugPrint("myDebug country ${countryComponent.shortName}");
          return countryComponent.shortName; // Return the ISO country code
        }
        // }
      }
      return null; // Return null if no country found
    } catch (e) {
      debugPrint('Error fetching country code: $e');
      return null;
    }
  }

  // String getCityTitle(Prediction prediction) {
  //   String description = prediction.description ?? '';
  //   return description.split(',')[0];
  // }

  Future<BitmapDescriptor> getCustomIcon() async {
    return await BitmapDescriptor.asset(
      ImageConfiguration(size: Size(24.w, 24.h)), // Specify desired size
      'assets/nav_arrow_icon.png',
    );
  }

  void _selectCity(Prediction prediction) async {
    FocusScope.of(context).unfocus();
    // await _checkLocationPermission();
    if (!hasLocationPermission) {
      return;
    }
    setState(() {
      _predictions.clear();
    });

    final placeDetails = await _places.getDetailsByPlaceId(prediction.placeId!);

    if (placeDetails.isOkay) {
      final location = placeDetails.result.geometry!.location;
      LatLng newDestination = LatLng(location.lat, location.lng);

      setState(() {
        finalDestinationName = prediction.structuredFormatting!.mainText;
        finalDestinationDescription = prediction.description ?? "N/A";
        _destinationPositions.add(newDestination);
        showBottomSheet = true;
      });

      mapController!
          .animateCamera(CameraUpdate.newLatLngZoom(newDestination, 14));

      await _fetchAndDrawRoutes();
    } else {
      debugPrint("Error fetching place details: ${placeDetails.errorMessage}");
    }
  }

  // SortedDestinations
  Future<void> _fetchAndDrawRoutes({LatLng? currentPosition}) async {
    try {
      final origin = currentPosition ?? _initialPosition;
      if (_destinationPositions.isEmpty) {
        throw Exception("Current or destination position is not set.");
      }
      _destinationPositions.sort((a, b) {
        double distanceA = _calculateDistance(origin, a);
        double distanceB = _calculateDistance(origin, b);
        return distanceA.compareTo(distanceB);
      });

      String waypoints = _destinationPositions
          .sublist(0, _destinationPositions.length - 1) // All except last
          .map((latLng) => '${latLng.latitude},${latLng.longitude}')
          .join('|');

      final finalDestination = _destinationPositions.last;

      final directionsUrl =
          'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${finalDestination.latitude},${finalDestination.longitude}&waypoints=$waypoints&mode=$_selectedMode&alternatives=true&key=$myApiKey';

      debugPrint("my Debug Fetching routes: $directionsUrl");
      final response = await http.get(Uri.parse(directionsUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['routes'] != null && data['routes'].isNotEmpty) {
          debugPrint('Fetched Routes response: ${data}');
          final route = data['routes'][0];
          final legs = route['legs'];

          double totalDistance = 0;
          double totalDuration = 0;

          for (var leg in legs) {
            totalDistance += leg['distance']['value'];
            totalDuration += leg['duration']['value'];

            List<String> instructionsList = [];
            bool legContainsToll = false;

            for (var step in leg['steps']) {
              String instruction =
                  step['html_instructions'].replaceAll(RegExp(r'<[^>]*>'), ' ');

              if (instruction.toLowerCase().contains("toll road")) {
                legContainsToll = true;
                containTolls = true;
              }
              instructionsList.add(instruction);
            }
            leg['instructions'] = instructionsList;
            leg['hasToll'] = legContainsToll;
          }

// Voice Navigation
          String distance =
              legs[0]['steps'][0]['distance']['text']; // e.g., "300 meters"
          String maneuver =
              legs[0]['steps'][0]['maneuver'] ?? ''; // e.g., "turn-left"
          String singleInstruction = legs[0]['instructions'][0];
          if (isJourneyStarted) {
            String voiceInstruction = HelperFunctions()
                .getVoiceInstruction(distance, maneuver, singleInstruction);
            debugPrint("vnins $voiceInstruction");
            _speakNextInstruction(voiceInstruction);
          }

          if (!mounted) return;
          setState(() {
            distanceText = "${(totalDistance / 1000).toStringAsFixed(1)} km";
            durationText = "${(totalDuration / 60).toStringAsFixed(0)} min";
            _polylines.clear();
          });

          await _drawPolylines(data['routes']);
          _updateStopsInfo(route, legs);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("No routes found.")),
          );
          debugPrint("No routes found.");
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

  Future<String?> _getPlaceIdFromLatLng(LatLng position) async {
    final url =
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$myApiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          return data['results'][0]['place_id']; // Extract place_id
        }
      }
    } catch (e) {
      debugPrint("Error fetching place_id: $e");
    }

    return null; // Return null if not found
  }

  Future<void> _updateStopsInfo(dynamic route, List<dynamic> legs) async {
    List<Map<String, dynamic>> stops = [];

    for (int i = 0; i < legs.length; i++) {
      // LatLng position = _destinationPositions[i];
      // String? placeId = await _getPlaceIdFromLatLng(position); // Fetch place_id
      // String placeName;

      // if (placeId != null && placeId.isNotEmpty) {
      //   placeName = await _getPlaceNameFromPlaceId(placeId);
      // } else {
      String placeName = await _getPlaceName(
          _destinationPositions[i]); // Fallback to reverse geocoding
      // }

      stops.add({
        'stopNo': "Stop ${i + 1}",
        'name': placeName,
        'distance': legs[i]['distance']['text'],
        'duration': legs[i]['duration']['text'],
        'location': _destinationPositions[i],
        'hasToll': legs[i]['hasToll'], // Fetch from leg data
        'instructions': legs[i]['instructions'], // Store instructions
      });
    }

    await _updateMarkers(stops);

    setState(() {
      _stopsInfo = stops;
      isMoreStopsAdded = checkStopsStatus();
      debugPrint("Updated stops info: $_stopsInfo");
    });
  }

  Future<void> _updateMarkers(List<Map<String, dynamic>> stops) async {
    // Update destination markers
    _destinationMarkers.clear();
    for (int i = 0; i < _destinationPositions.length; i++) {
      _destinationMarkers.add(
        Marker(
          markerId: MarkerId('destination_$i'),
          position: _destinationPositions[i],
          infoWindow: InfoWindow(
            title: stops[i]['name'],
          ),
        ),
      );
    }
  }

  bool checkStopsStatus() {
    return (_stopsInfo.length > 1) ? true : false;
  }

  Future<String> _getPlaceNameFromPlaceId(String placeId) async {
    final url =
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$myApiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          return data['result']
              ['name']; // This gives the actual name used in predictions
        }
      }
    } catch (e) {
      debugPrint("Error fetching place name: $e");
    }

    return "Unknown Location"; // Default if API fails
  }

  Future<String> _getPlaceName(LatLng position) async {
    final url =
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$myApiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          debugPrint("myDebug fetching stops name ${data['results'][0]}");
          debugPrint(
              "myDebug fetching stops name ${data['results'][0]['address_components']}");

          return data['results'][0]['formatted_address'];
        }
      }
    } catch (e) {
      debugPrint("Error fetching place name: $e");
    }

    return "Unknown Location"; // Default if API fails
  }

  Future<void> _drawPolylines(List<dynamic> routes) async {
    try {
      final PolylinePoints polylinePoints = PolylinePoints();
      final newPolylines = <Polyline>{};

      String defaultRouteId = routes.isNotEmpty ? routes.first['summary'] : '';

      for (var route in routes) {
        final points =
            polylinePoints.decodePolyline(route['overview_polyline']['points']);
        final polylineLatLng = points
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();

        newPolylines.add(Polyline(
          polylineId: PolylineId(route['summary']),
          points: polylineLatLng,
          color: route['summary'] == defaultRouteId
              ? AppColors.primary
              : Colors.grey,
          width: route['summary'] == defaultRouteId ? 8 : 5,
          consumeTapEvents: true,
          onTap: () {
            _onRouteSelected(route['summary'], routes);
          },
        ));
      }

      setState(() {
        _polylines = newPolylines;
      });

      // Automatically select the default route
      if (routes.isNotEmpty) {
        _onRouteSelected(defaultRouteId, routes);
      }
    } catch (e) {
      debugPrint('Error drawing polylines: $e');
    }
  }

  Future<void> _removeStop(Map<String, dynamic> stop) async {
    // await _checkLocationPermission();
    setState(() {
      _destinationPositions.remove(stop['location']);
      _destinationMarkers
          .removeWhere((marker) => marker.position == stop['location']);
      _stopsInfo.remove(stop);
    });

    _fetchAndDrawRoutes(); // Recalculate route after removal
  }

  void _onRouteSelected(String selectedRouteId, List<dynamic> routes) {
    setState(() {
      containTolls = false;

      // Update polyline appearance
      _polylines = _polylines.map((polyline) {
        return Polyline(
          polylineId: polyline.polylineId,
          points: polyline.points,
          color: polyline.polylineId.value == selectedRouteId
              ? AppColors.primary
              : Colors.grey,
          width: polyline.polylineId.value == selectedRouteId ? 8 : 5,
          consumeTapEvents: true,
          onTap: () {
            if (polyline.polylineId.value != selectedRouteId) {
              _onRouteSelected(polyline.polylineId.value, routes);
            }
          },
        );
      }).toSet();

      // Find the selected route details
      final selectedRouteData = routes.firstWhere(
          (route) => route['summary'] == selectedRouteId,
          orElse: () => null);

      if (selectedRouteData != null) {
        final legs = selectedRouteData['legs'];

        double totalDistance = 0;
        double totalDuration = 0;
        List<String> instructionsList = [];

        for (var leg in legs) {
          totalDistance += leg['distance']['value'];
          totalDuration += leg['duration']['value'];

          for (var step in leg['steps']) {
            String instruction =
                step['html_instructions'].replaceAll(RegExp(r'<[^>]*>'), ' ');
            instructionsList.add(instruction);

            if (instruction.toLowerCase().contains("toll road")) {
              containTolls = true;
            }
          }
        }

        distanceText = "${(totalDistance / 1000).toStringAsFixed(1)} km";
        durationText = "${(totalDuration / 60).toStringAsFixed(0)} min";
        navigationInstructions = instructionsList; // Store for UI display

        debugPrint("Route Toll Info: $containTolls");
        debugPrint(
            "VGN onRoute Navigation Instruction at Zero: ${navigationInstructions[0]}");
        debugPrint(
            "Turn-by-turn navigation: ${navigationInstructions.join(', ')}");
      } else {
        debugPrint("Selected route not found.");
      }
    });
  }

  String tempInstruction = "";
  void _speakNextInstruction(String instruction) async {
    if (instruction.contains(tempInstruction)) {
      tempInstruction = instruction; // Update before awaiting
      await _voiceService.speak(instruction);
    }
  }

  void _startLiveNavigation() {
    _moveToUserLocation(); // Move the camera to user's current location

    // Request location updates every 2 seconds with high accuracy and a minimum movement of 10 meters
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high, // High accuracy for better precision
        distanceFilter: 10, // Updates only when moving 10 meters
        // timeLimit: Duration(seconds: 2), // Request updates every 2 seconds
      ),
    ).listen((position) async {
      if (position.longitude == null) {
        return;
      }

      // Create a LatLng from the new position
      final currentLocation = LatLng(position.latitude, position.longitude);

      // Check if user reached any stop
      for (var stop in List.from(_stopsInfo)) {
        if (hasReachedDestination(currentLocation, stop['location'])) {
          debugPrint("myDebug User reached: ${stop['name']}");
          await _removeStop(stop);
          Fluttertoast.showToast(
            msg: "Reached ${stop['name']}",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: AppColors.primary,
            textColor: AppColors.primaryText,
          );
          break;
        }
      }

      // Check if the user has reached the last destination
      if (hasReachedDestination(currentLocation, getLastDestination())) {
        _onReachedDestination();
        return;
      }

      // Recalculate route if needed
      if (shouldRecalculateRoute(currentLocation, getLastDestination())) {
        debugPrint('Recalculating route...');
        await _fetchAndDrawRoutes(
            currentPosition: currentLocation); // Re-fetch the route
      }

      // Update the user location on the map
      _updateUserLocation(position);

      // Update polylines with the new user location
      setState(() {
        _polylines = _polylines.map((polyline) {
          if (polyline.polylineId.value == "shortestRoute") {
            return Polyline(
              polylineId: polyline.polylineId,
              points: [
                currentLocation,
                ...polyline.points.sublist(1)
              ], // Start from the current location
              color: AppColors.primary,
              width: 8,
            );
          }
          return polyline;
        }).toSet();
      });
    });
  }

  LatLng? getLastDestination() {
    if (_destinationPositions.isNotEmpty) {
      return _destinationPositions.last; // Returns the last destination
    }
    return null; // No destinations left
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

  Set<Marker> _getMarkers() {
    return {
      if (_startingMarker != null) _startingMarker!,
      ..._destinationMarkers,
    };
  }

// Check if user is logged in
  void _checkUserStatus() {
    setState(() {
      _user = FirebaseAuth.instance.currentUser;
    });
  }

  void _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();

      if (mounted) {
        setState(() {
          _user = null; // Update UI after logout
        });
      }

      // Cancel location subscription only if widget is still active
      if (mounted) {
        _locationSubscription.cancel();
      }

      debugPrint("User logged out, location subscription canceled.");

      // Navigate to login screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => SignUpScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      if (!isInternetConnected) {
        return NoInternetWidget();
      }

      return PopScope(
        canPop: false, // Prevent default back button behavior
        onPopInvoked: (bool didPop) async {
          if (didPop) return;
          // Show exit confirmation dialog
          final shouldExit = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Exit App'),
                content: const Text('Do you want to exit the application?'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Exit'),
                  ),
                ],
              );
            },
          );

          // Exit if user confirms
          if (shouldExit == true) {
            SystemNavigator.pop();
          }
        },
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: Colors.black,
          body: SafeArea(
            child: isLoading
                ? Container(
                    margin: EdgeInsets.only(bottom: 10.h),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(
                            28.r), // Adjust for desired roundness
                        topRight: Radius.circular(28.r),
                        bottomLeft: Radius.circular(28.r),
                        bottomRight: Radius.circular(28.r),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SpinKitFadingCircle(
                          color: AppColors.primary,
                          size: 50.0.sp,
                        ),
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
                          Container(
                            margin: EdgeInsets.only(bottom: 10.h),
                            height: MediaQuery.of(context).size.height,
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 255, 255, 255),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(
                                    28.r), // Adjust for desired roundness
                                topRight: Radius.circular(28.r),
                                bottomLeft: Radius.circular(28.r),
                                bottomRight: Radius.circular(28.r),
                              ),
                            ),
                            // margin: EdgeInsets.only(top: 34.h, bottom: 34.h),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 15.w,
                                ),
                                Image.asset(
                                  'assets/app_icon.png',
                                  width: 55.h,
                                  height: 60.h,
                                ),
                                SizedBox(
                                  width: 10.w,
                                ),
                                Padding(
                                  padding: EdgeInsets.only(top: 15.h),
                                  child: Text(
                                    "Value Maps",
                                    style: TextStyle(
                                        fontSize: 20.sp,
                                        color: AppColors.primaryText,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                                Spacer(),
                                _user != null
                                    ? Padding(
                                        padding: EdgeInsets.only(
                                            right: 15.w, top: 10.w),
                                        child: InkWell(
                                            onTap: () {
                                              _logout(context);
                                            },
                                            child: Image.asset(
                                              'assets/ic_logout.png',
                                              height: 34.h,
                                              width: 34.w,
                                            )),
                                      )
                                    : SizedBox()
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(top: 50.h, bottom: 34.h),
                            child: ClipRRect(
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(
                                    28.r), // Adjust for desired roundness
                                topRight: Radius.circular(28.r),
                              ),
                              child: Stack(
                                children: [
                                  GestureDetector(
                                    onTap: () async {
                                      //  await _checkLocationPermission();
                                      // Unfocus to dismiss the keyboard
                                      FocusScope.of(context).unfocus();
                                    },
                                    child: GoogleMap(
                                      onMapCreated: _onMapCreated,
                                      zoomControlsEnabled: false,
                                      myLocationButtonEnabled: false,
                                      myLocationEnabled: false,
                                      compassEnabled: false,
                                      mapType: MapType.normal,
                                      // style: 'assets/dark_mode.json' ,
                                      initialCameraPosition: CameraPosition(
                                        target: _initialPosition,
                                        zoom: 14,
                                      ),
                                      markers: _getMarkers(),
                                      polylines: _polylines,
                                      trafficEnabled: true,
                                    ),
                                  ),
                                  IntrinsicHeight(
                                    child: Container(
                                      margin: EdgeInsets.symmetric(
                                          vertical: 8.h, horizontal: 15.w),
                                      // color: Colors.amber,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // if (!isJourneyStarted)
                                          searchTextFieldCard(),
                                          // if (!isJourneyStarted)
                                          SizedBox(
                                            height: 8.h,
                                          ),
                                          // if (showBottomSheet)
                                          //   _startPositionCard(
                                          //       "From: ", "Your Location"),
                                          if (showBottomSheet)
                                            _stopPositionCard("Destination: "),
                                          SizedBox(
                                            height: 10.h,
                                          ),
                                          Align(
                                              alignment: Alignment
                                                  .centerRight, // Align to the right side
                                              child: GestureDetector(
                                                onTap: () async {
                                                  //    await _checkLocationPermission();
                                                  _moveToUserLocation();
                                                },
                                                child: Image.asset(
                                                  'assets/ic_current_location.png',
                                                  height: 45.h,
                                                ),
                                              ))
                                        ],
                                      ),
                                    ),
                                  ),
                                  _predictions.isNotEmpty
                                      ? Container(
                                          margin: EdgeInsets.symmetric(
                                              horizontal: 30.w, vertical: 65.h),
                                          decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.only(
                                                  bottomLeft:
                                                      Radius.circular(20.r),
                                                  bottomRight:
                                                      Radius.circular(20.r))),
                                          child: ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: _predictions.length,
                                            itemBuilder: (context, index) {
                                              final prediction =
                                                  _predictions[index];
                                              return ListTile(
                                                leading: Icon(
                                                  Icons.location_on,
                                                  color: AppColors.primary,
                                                ),
                                                title: Text(
                                                    prediction.description ??
                                                        ''),
                                                onTap: () async {
                                                  _searchController.text = '';
                                                  _selectCity(prediction);
                                                },
                                              );
                                            },
                                          ),
                                        )
                                      : SizedBox(),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0.h,
                            left: 0,
                            right: 0,
                            child: Column(
                              children: [
                                Stack(
                                  children: [
                                    showBottomSheet
                                        ? bottomSheetWidget()
                                        : Image.asset(
                                            'assets/mapbottom.png',
                                            width: MediaQuery.of(context)
                                                .size
                                                .width,
                                            fit: BoxFit.cover,
                                          ),
                                    Positioned(
                                      bottom: 0,
                                      child: Image.asset(
                                        'assets/mapbottom.png',
                                        width:
                                            MediaQuery.of(context).size.width,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  height: 35.h,
                                  margin: EdgeInsets.only(bottom: 10.h),
                                  // color: Colors.white,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.only(
                                      bottomLeft: Radius.circular(28.r),
                                      bottomRight: Radius.circular(28.r),
                                    ),
                                  ),
                                )
                              ],
                            ),
                          ),
                        ],
                      )
                    : locationPermissionWidget(),
          ),
        ),
      );
    } catch (e, stacktrace) {
      debugPrint("Build Error: $e\n$stacktrace");
      _initializeApp();
      return Center(child: Text("Something went wrong"));
    }
  }

  void _resetState() {
    setState(() {
      showBottomSheet = false;
      _polylines.clear();
      _searchController.text = '';
      tempInstruction = "";
      distanceText = ''; // Clear distance text
      durationText = ''; // Clear duration text
      tollInfoText = ''; // Clear toll info text
      _destinationPositions.clear(); // List of multiple destinations
      _destinationMarkers.clear(); // Markers for all destinations
      containTolls = false;
      _stopsInfo.clear();
      if (isJourneyStarted) {
        _locationSubscription.cancel();
      }
      isJourneyStarted = false;
      // Any other variables you want to reset
    });
    // _initializeUserLocation();
    _moveToUserLocation();
  }

  Widget locationPermissionWidget() {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28.r), // Adjust for desired roundness
          topRight: Radius.circular(28.r),
          bottomLeft: Radius.circular(28.r),
          bottomRight: Radius.circular(28.r),
        ),
      ),
      child: Center(
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
                _initializeApp();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 15.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50.sp),
                ),
              ),
              child: Text(
                'Grant Permissions',
                style: TextStyle(fontSize: 16.sp, color: AppColors.primaryText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isExpanded = false; // Track expansion state

  Widget bottomSheetWidget() {
    return AnimatedContainer(
      margin: EdgeInsets.symmetric(vertical: 30.h, horizontal: 15.w),
      duration: Duration(milliseconds: 500), // Smooth animation
      constraints: BoxConstraints(
        minHeight: 60.h, // Minimum height for collapsed state
        maxHeight: MediaQuery.of(context).size.height *
            0.6, // Maximum height for expansion
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(25.r),
            topRight: Radius.circular(25.r),
            bottomLeft: Radius.circular(25.r),
            bottomRight: Radius.circular(25.r)),
      ),
      child: Padding(
        padding:
            EdgeInsets.only(left: 16.w, right: 16.w, bottom: 16.h, top: 16.h),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Allow dynamic height
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Arrow Button for Expansion
            GestureDetector(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded; // Toggle state
                });
              },
              child: Container(
                color: Colors.white,
                child: Center(
                  child: Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    size: 30.sp,
                    color: AppColors.dividerGrey,
                  ),
                ),
              ),
            ),

            // Show Content Only When Expanded
            if (_isExpanded) ...[
              SizedBox(height: 10.h),

              // Transportation Mode Selection
              if (!isJourneyStarted)
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
                        icon: Icons.train, label: "Transit", mode: 'transit'),
                  ],
                ),

              Divider(color: AppColors.textField),

              // Stops Info
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded; // Toggle state
                  });
                },
                child: Container(
                    color: Colors.white,
                    child: checkStopsStatus()
                        ? showMultipleStops()
                        : showSingleStop()),
              ),

              SizedBox(height: 20),

              // Start Journey Button
              ElevatedButton(
                onPressed: () {
                  if (!isJourneyStarted) {
                    setState(() {
                      _isExpanded = false;
                      isJourneyStarted = true;
                    });
                    _startLiveNavigation();
                  } else {
                    _resetState();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isJourneyStarted
                      ? AppColors.primaryText
                      : AppColors.primary,
                  padding:
                      EdgeInsets.symmetric(horizontal: 40.w, vertical: 15.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.sp),
                  ),
                  minimumSize: Size(MediaQuery.of(context).size.width, 50.sp),
                ),
                child: Text(
                  isJourneyStarted ? 'Exit' : 'Start',
                  style: TextStyle(
                      fontSize: 16.sp,
                      color: isJourneyStarted
                          ? Colors.white
                          : AppColors.primaryText),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget multipleStopCardDesign(Map<String, dynamic> stop) {
    bool isLastStop = _stopsInfo.last == stop;
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40.w,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Icon(Icons.location_pin, color: Colors.red),
                // onPressed: () => _removeStop(stop),

                if (!isLastStop) ...[
                  Icon(
                    Icons.keyboard_double_arrow_down_rounded,
                    color: AppColors.primaryGrey,
                    size: 15.sp,
                  ),
                  Icon(
                    Icons.keyboard_double_arrow_down_rounded,
                    color: AppColors.primaryGrey,
                    size: 15.sp,
                  ),
                  Icon(
                    Icons.keyboard_double_arrow_down_rounded,
                    color: AppColors.primaryGrey,
                    size: 15.sp,
                  ),
                ],
                // Image.asset(
                //   'assets/destination_line.png',
                //   height: 70.h,
                // )
              ],
            ),
          ),
          Expanded(
            // color: Colors.red,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 25.h,
                  width: MediaQuery.of(context).size.width,
                  child: Row(
                    children: [
                      Text(
                        stop['stopNo'],
                        style: TextStyle(
                            fontSize: 16.sp,
                            color: AppColors.primaryText,
                            fontWeight: FontWeight.w500),
                        // textAlign: TextAlign.center,
                      ),
                      Spacer(),
                      isJourneyStarted
                          ? SizedBox()
                          : IconButton(
                              icon:
                                  Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () => _removeStop(stop),
                            ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 5.h,
                ),
                Text(
                  stop['name'],
                  style: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.primaryText,
                      fontWeight: FontWeight.w400),
                  // textAlign: TextAlign.center,
                ),
                SizedBox(
                  height: 5.h,
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.access_time_filled,
                        size: 22.sp, color: AppColors.primary),
                    SizedBox(width: 5.w),
                    Padding(
                      padding: EdgeInsets.only(top: 3.h),
                      child: Text(
                        stop['duration'],
                        style: TextStyle(
                            fontSize: 14.sp, color: AppColors.primaryGrey),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(
                      width: 10.w,
                    ),
                    Icon(Icons.location_pin, color: AppColors.primary),
                    SizedBox(width: 5.w),
                    Padding(
                      padding: EdgeInsets.only(top: 3.h),
                      child: Text(
                        // distanceText.toString(),
                        convertKmToMiles(stop['distance']),
                        style: TextStyle(
                            fontSize: 14.sp, color: AppColors.primaryGrey),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                stop['hasToll']
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(Icons.toll,
                              size: 22.sp, color: AppColors.primary),
                          SizedBox(width: 5.w),
                          Padding(
                            padding: EdgeInsets.only(top: 3.h),
                            child: Text(
                              "This Route contain tolls.",
                              style: TextStyle(
                                  fontSize: 14.sp,
                                  color: AppColors.primaryGrey),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      )
                    : SizedBox(),
                Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.only(right: 14.w),
                    // tilePadding: EdgeInsets.symmetric(horizontal: 16),

                    initiallyExpanded: isExpanded,
                    onExpansionChanged: (expanded) {
                      setState(() {
                        isExpanded = expanded;
                      });
                    },
                    title: Text(
                      "Steps",
                      style: TextStyle(
                          fontSize: 16.sp,
                          color: AppColors.primaryText,
                          fontWeight: FontWeight.w500),
                    ),
                    trailing: Icon(isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down),
                    children: [
                      Container(
                        // color: Colors.amber,
                        height: stop['instructions'].isNotEmpty ? 100 : 50,
                        child: stop['instructions'].isNotEmpty
                            ? ListView.builder(
                                itemCount: stop['instructions'].length,
                                itemBuilder: (context, index) {
                                  String singleInstruction =
                                      stop['instructions'][index];
                                  Icon leadingIcon =
                                      getLeadingIcon(singleInstruction);
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      backgroundColor: AppColors.secondary,
                                      child: leadingIcon,
                                    ),
                                    title: Text(
                                      singleInstruction, // Remove HTML tags
                                      style: TextStyle(
                                          fontSize: 14.sp,
                                          color: AppColors.primaryText),
                                    ),
                                  );
                                },
                              )
                            : Center(
                                child: Text(
                                    "No navigation instructions available")),
                      ),
                    ],
                  ),
                ),
                Divider(color: AppColors.textField),
              ],
            ),
          ),
          // isJourneyStarted
          //     ? SizedBox()
          //     : Align(
          //         alignment: Alignment.bottomCenter,
          //         child: IconButton(
          //           icon: Icon(Icons.remove_circle, color: Colors.red),
          //           onPressed: () => _removeStop(stop),
          //         ),
          //       ),
        ],
      ),
    );
  }

  /// Function to return the appropriate icon based on instruction
  Icon getLeadingIcon(String instruction) {
    if (instruction.toLowerCase().contains("turn  left")) {
      return Icon(Icons.turn_left, color: AppColors.primaryGrey);
    } else if (instruction.toLowerCase().contains("ramp") &&
        instruction.toLowerCase().contains("right")) {
      return Icon(Icons.ramp_right, color: AppColors.primaryGrey);
    } else if (instruction.toLowerCase().contains("ramp") &&
        instruction.toLowerCase().contains("left")) {
      return Icon(Icons.ramp_left, color: AppColors.primaryGrey);
    } else if (instruction.toLowerCase().contains("slight  left")) {
      return Icon(Icons.turn_slight_left, color: AppColors.primaryGrey);
    } else if (instruction.toLowerCase().contains("slight  right")) {
      return Icon(Icons.turn_slight_right, color: AppColors.primaryGrey);
    } else if (instruction.toLowerCase().contains("turn  right")) {
      return Icon(Icons.turn_right, color: AppColors.primaryGrey);
    } else if (instruction.toLowerCase().contains("straight")) {
      return Icon(Icons.straight, color: AppColors.primaryGrey);
    } else if (instruction.toLowerCase().contains("u-turn") &&
        instruction.toLowerCase().contains("left")) {
      return Icon(Icons.u_turn_left, color: AppColors.primaryGrey);
    } else if (instruction.toLowerCase().contains("u-turn") &&
        instruction.toLowerCase().contains("right")) {
      return Icon(Icons.u_turn_right, color: AppColors.primaryGrey);
    } else if (instruction.toLowerCase().contains("roundabout")) {
      return Icon(Icons.radio_button_unchecked_sharp,
          color: AppColors.primaryGrey);
    } else {
      return Icon(Icons.straight, color: AppColors.primaryGrey);
    }
  }

  bool isExpanded = false;
  Widget showSingleStop() {
    return IntrinsicHeight(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                color: const Color.fromARGB(255, 255, 255, 255),
                width: 260.w,
                child: Text(
                  (_stopsInfo.isNotEmpty)
                      ? _stopsInfo.last['name']
                      : finalDestinationName,
                  style: TextStyle(
                    fontSize: 18.sp,
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Spacer(),
              isJourneyStarted
                  ? SizedBox()
                  : Align(
                      alignment: Alignment.bottomCenter,
                      child: IconButton(
                        icon: Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () {
                          _resetState();
                        },
                        // onPressed: () => _removeStop(stop),
                      ),
                    ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.access_time_filled,
                  size: 22.sp, color: AppColors.primary),
              SizedBox(width: 5.w),
              Padding(
                padding: EdgeInsets.only(top: 3.h),
                child: Text(
                  durationText ?? "N/A",
                  style:
                      TextStyle(fontSize: 14.sp, color: AppColors.primaryGrey),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(
                width: 10.w,
              ),
              Icon(Icons.location_pin, color: AppColors.primary),
              SizedBox(width: 5.w),
              Padding(
                padding: EdgeInsets.only(top: 3.h),
                child: Text(
                  // distanceText.toString(),
                  convertKmToMiles(distanceText.toString()),
                  style:
                      TextStyle(fontSize: 14.sp, color: AppColors.primaryGrey),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          containTolls
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.toll, size: 22.sp, color: AppColors.primary),
                    SizedBox(width: 5.w),
                    Padding(
                      padding: EdgeInsets.only(top: 3.h),
                      child: Text(
                        "This Route contain tolls.",
                        style: TextStyle(
                            fontSize: 14.sp, color: AppColors.primaryGrey),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                )
              : SizedBox(),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              // tilePadding: EdgeInsets.symmetric(horizontal: 16),
              initiallyExpanded: isExpanded,
              onExpansionChanged: (expanded) {
                setState(() {
                  isExpanded = expanded;
                });
              },
              title: Text(
                "Steps",
                style: TextStyle(
                    fontSize: 16.sp,
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.w500),
              ),
              trailing: Icon(isExpanded
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down),
              children: [
                Container(
                  // color: Colors.amber,
                  height: navigationInstructions.isNotEmpty ? 100 : 50,
                  child: navigationInstructions.isNotEmpty
                      ? ListView.builder(
                          itemCount: navigationInstructions.length,
                          itemBuilder: (context, index) {
                            String singleInstruction =
                                navigationInstructions[index];
                            Icon leadingIcon =
                                getLeadingIcon(singleInstruction);
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.secondary,
                                child: leadingIcon,
                              ),
                              title: Text(
                                singleInstruction, // Remove HTML tags
                                style: TextStyle(
                                    fontSize: 14.sp,
                                    color: AppColors.primaryText),
                              ),
                            );
                          },
                        )
                      : Center(
                          child: Text("No navigation instructions available")),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget showMultipleStops() {
    return SizedBox(
      height: 130.h,
      child: SingleChildScrollView(
        child: Column(
          children: _stopsInfo.map((stop) {
            return multipleStopCardDesign(stop);
          }).toList(),
        ),
      ),
    );
  }

  Widget searchTextFieldCard() {
    return Container(
      // margin: const EdgeInsets.symmetric(
      //     vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(50),
      ),
      child: showBottomSheet
          ? TextField(
              controller: _searchController,
              onChanged: _searchCities,
              style: TextStyle(color: Colors.black),
              cursorColor: AppColors.primary,
              decoration: const InputDecoration(
                labelText: "Add Stop",
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                border: InputBorder.none,
              ),
              keyboardType: TextInputType.streetAddress,
            )
          : TextField(
              controller: _searchController,
              onChanged: _searchCities,
              style: TextStyle(color: Colors.black),
              cursorColor: AppColors.primary,
              decoration: const InputDecoration(
                labelText: "Search",
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                border: InputBorder.none,
              ),
              keyboardType: TextInputType.streetAddress,
            ),
    );
  }

  // Widget _startPositionCard(String title, String? _selectedDestination) {
  //   return Container(
  //     width: double.infinity,
  //     height: 45.h,
  //     // margin: EdgeInsets.symmetric(horizontal: 20.w),
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(50),
  //     ),
  //     child: Padding(
  //       padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 12.h),
  //       child: Row(
  //         children: [
  //           Image.asset(
  //             'assets/current_location_marker.png',
  //             height: 20.h,
  //           ),
  //           SizedBox(
  //             width: 5.w,
  //           ),
  //           Text(
  //             title,
  //             style: TextStyle(color: AppColors.dividerGrey, fontSize: 12.sp),
  //           ),
  //           Text(
  //             _selectedDestination.toString(),
  //             style: TextStyle(color: AppColors.primaryGrey, fontSize: 14.sp),
  //           )
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _stopPositionCard(String title) {
    return Container(
      width: double.infinity,
      height: 45.h,
      // margin: EdgeInsets.symmetric(horizontal: 20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 12.h),
        child: Row(
          children: [
            Icon(
              Icons.location_pin,
              color: Colors.red,
            ),
            SizedBox(
              width: 5.w,
            ),
            Text(
              title,
              style: TextStyle(color: AppColors.dividerGrey, fontSize: 12.sp),
            ),
            Expanded(
              child: (_stopsInfo.isNotEmpty)
                  ? Text(
                      _stopsInfo.last['name'],
                      maxLines: 1,
                      overflow: TextOverflow
                          .ellipsis, // Adds "..." when text overflows
                      style: TextStyle(
                        color: AppColors.primaryGrey,
                        fontSize: 14.sp,
                      ),
                    )
                  : Text(
                      finalDestinationName,
                      maxLines: 1,
                      overflow: TextOverflow
                          .ellipsis, // Adds "..." when text overflows
                      style: TextStyle(
                        color: AppColors.primaryGrey,
                        fontSize: 14.sp,
                      ),
                    ),
            )
          ],
        ),
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
