// import 'package:location/location.dart';

// class MyAppState extends State<MyApp> {
//   final Location _location = Location();
//   late StreamSubscription<LocationData> _locationSubscription;
//   GoogleMapController? mapController;

//   LatLng? _initialPosition;
//   Marker? _startingMarker;
//   bool isLoading = true;
//   bool hasLocationPermission = false;

//   @override
//   void initState() {
//     super.initState();
//     _initializeApp();
//     initConnectivity();
//     _connectivitySubscription =
//         _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
//   }

//   @override
//   void dispose() {
//     _locationSubscription.cancel();
//     _connectivitySubscription.cancel();
//     super.dispose();
//   }

//   Future<void> _initializeApp() async {
//     bool permissionGranted = await _checkLocationPermission();
//     if (permissionGranted) {
//       await _initializeUserLocation();
//     } else {
//       setState(() => isLoading = false);
//     }
//   }

//   Future<bool> _checkLocationPermission() async {
//     PermissionStatus permissionStatus = await _location.requestPermission();
//     if (permissionStatus == PermissionStatus.granted) {
//       setState(() => hasLocationPermission = true);
//       return true;
//     } else {
//       setState(() {
//         hasLocationPermission = false;
//         isLoading = false;
//       });
//       return false;
//     }
//   }

//   Future<void> _initializeUserLocation() async {
//     try {
//       bool isServiceEnabled = await _location.serviceEnabled();
//       if (!isServiceEnabled) {
//         isServiceEnabled = await _location.requestService();
//         if (!isServiceEnabled) {
//           throw Exception("Location services are disabled.");
//         }
//       }

//       // Get the initial location
//       final locationData = await _location.getLocation();
//       _updateUserLocation(locationData);

//       // Listen for location updates
//       _locationSubscription =
//           _location.onLocationChanged.listen((LocationData newLocation) {
//         _updateUserLocation(newLocation);
//       });

//       setState(() => isLoading = false);
//     } catch (e) {
//       debugPrint("Error initializing user location: $e");
//       setState(() => isLoading = false);
//     }
//   }

//   void _updateUserLocation(LocationData locationData) {
//     final userLatLng = LatLng(locationData.latitude!, locationData.longitude!);
//     final BitmapDescriptor customIcon = BitmapDescriptor.defaultMarker; // Replace with getCustomIcon if needed

//     setState(() {
//       _initialPosition = userLatLng;
//       _startingMarker = Marker(
//         markerId: const MarkerId('userLocation'),
//         position: userLatLng,
//         icon: customIcon,
//         infoWindow: const InfoWindow(title: "Your Current Location"),
//       );
//     });

//     mapController?.animateCamera(CameraUpdate.newLatLng(userLatLng));
//   }

//   void _onMapCreated(GoogleMapController controller) {
//     mapController = controller;
//   }

//   Future<void> _moveToUserLocation() async {
//     if (!hasLocationPermission) {
//       debugPrint("Permission not granted. Cannot move to location.");
//       return;
//     }

//     final locationData = await _location.getLocation();
//     final userLatLng = LatLng(locationData.latitude!, locationData.longitude!);
//     mapController?.animateCamera(CameraUpdate.newLatLngZoom(userLatLng, 14));
//   }
// }
