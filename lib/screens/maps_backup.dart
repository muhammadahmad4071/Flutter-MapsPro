// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:google_maps_webservice/places.dart';
// import 'package:flutter_polyline_points/flutter_polyline_points.dart';
// import 'package:http/http.dart' as http;
// import 'package:maps/util/app_colors.dart';

// class MapsHomeScreen extends StatefulWidget {
//   const MapsHomeScreen({super.key});

//   @override
//   State<MapsHomeScreen> createState() => _MapsHomeScreenState();
// }

// class _MapsHomeScreenState extends State<MapsHomeScreen> {
//   late GoogleMapController mapController;
//   LatLng _initialPosition =
//       LatLng(37.7749, -122.4194);
//   LatLng? _destinationPosition;
//   List<LatLng> _polylineCoordinates = [];
//   late PolylinePoints polylinePoints;
//   final places =
//       GoogleMapsPlaces(apiKey: 'AIzaSyBM6orh06wXY5XLR_Tdzk37oPAUK1wPIGI');

//   @override
//   void initState() {
//     super.initState();
//     polylinePoints = PolylinePoints();
//     // _getUserLocation().then((position) {
//     //   setState(() {
//     //     _initialPosition = LatLng(position.latitude, position.longitude);
//     //   });
//     // });
//   }

//   void _onMapCreated(GoogleMapController controller) {
//     mapController = controller;
//   }

//   Future<Position> _getUserLocation() async {
//     LocationPermission permission = await Geolocator.requestPermission();
//     if (permission == LocationPermission.denied ||
//         permission == LocationPermission.deniedForever) {
//       return Future.error('Location permission denied');
//     }
//     return await Geolocator.getCurrentPosition();
//   }

//   Future<List<Prediction>> _searchPlaces(String query) async {
//     PlacesAutocompleteResponse response = await places.autocomplete(query);
//     return response.predictions;
//   }

//   Future<void> _createPolylines(LatLng origin, LatLng destination) async {
//     PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
//       'AIzaSyBM6orh06wXY5XLR_Tdzk37oPAUK1wPIGI', // Google Maps API Key
//       PointLatLng(origin.latitude, origin.longitude),
//       PointLatLng(destination.latitude, destination.longitude),
//     );

//     if (result.errorMessage == null && result.points.isNotEmpty) {
//       _polylineCoordinates.clear();
//       for (var point in result.points) {
//         _polylineCoordinates.add(LatLng(point.latitude, point.longitude));
//       }
//       setState(() {});
//     } else {
//       print("Error fetching polylines: ${result.errorMessage}");
//     }
//   }

//   Future<void> _getDirections(LatLng origin, LatLng destination) async {
//     var url = Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
//       'origin': '${origin.latitude},${origin.longitude}',
//       'destination': '${destination.latitude},${destination.longitude}',
//       'key': 'AIzaSyBM6orh06wXY5XLR_Tdzk37oPAUK1wPIGI',
//     });

//     var response = await http.get(url);
//     var data = json.decode(response.body);
//     var duration = data['routes'][0]['legs'][0]['duration']['text'];
//     var distance = data['routes'][0]['legs'][0]['distance']['text'];
//     print("mapDistance $distance");
//     print("mapDistance $duration");

//     setState(() {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Distance: $distance, Duration: $duration')),
//       );
//     });
//   }

//   void _searchDestinationAndNavigate(String query) async {
//     var predictions = await _searchPlaces(query);
//       print("predictions $predictions");
//     if (predictions.isNotEmpty) {
//       var place = predictions.first;
//       var details = await places.getDetailsByPlaceId(place.placeId!);
//       var location = details.result.geometry!.location;
//       var destination = LatLng(location.lat, location.lng);

//       setState(() {
//         _destinationPosition = destination;
//       });

//       mapController.animateCamera(
//         CameraUpdate.newLatLngZoom(destination, 14),
//       );

//       await _createPolylines(_initialPosition, destination);
//       await _getDirections(_initialPosition, destination);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     double screenWidth = MediaQuery.of(context).size.width;
//     return SafeArea(
//       child: Scaffold(
//         // appBar: AppBar(
//         //   title: Text('Google Maps'),
//         //   actions: [
//         //     IconButton(
//         //       icon: Icon(Icons.search),
//         //       onPressed: () {
//         //         showSearch(
//         //           context: context,
//         //           delegate: DestinationSearchDelegate(
//         //             onSelected: (query) => _searchDestinationAndNavigate(query),
//         //           ),
//         //         );
//         //       },
//         //     ),
//         //   ],
//         // ),
//         body: Stack(
//           children: [
//             GoogleMap(
//               onMapCreated: _onMapCreated,
//               initialCameraPosition: CameraPosition(
//                 target: _initialPosition,
//                 zoom: 14,
//               ),
//               polylines: {
//                 Polyline(
//                   polylineId: PolylineId('route'),
//                   points: _polylineCoordinates,
//                   color: Colors.blue,
//                   width: 5,
//                 ),
//               },
//               markers: {
//                 if (_destinationPosition != null)
//                   Marker(
//                     markerId: MarkerId('destination'),
//                     position: _destinationPosition!,
//                   ),
//               },
//             ),

//             Container(
//               margin: EdgeInsets.symmetric(vertical: 24.h, horizontal: 20.w ),
//               decoration: BoxDecoration(
//                 color: AppColors.textField,
//                 borderRadius: BorderRadius.circular(50.sp),
//               ),
//               child: TextField(
//                 // enabled: !_isLoading,
//                 style: TextStyle(color: AppColors.primaryText),
//                 // controller: controller,
//                 cursorColor: AppColors.primary,
//                 decoration: InputDecoration(
//                     labelText: "Search",
//                     prefixIcon:
//                         Icon(Icons.search, color: AppColors.primaryGrey),
//                     border: InputBorder.none
//                     //  OutlineInputBorder(
//                     //         borderSide: BorderSide(style: BorderStyle.solid, width: 2),
//                     //         borderRadius: BorderRadius.all(Radius.circular(50))
//                     //       )
//                     ),
//                 keyboardType: TextInputType.streetAddress,
//               ),
//             )
//           ],
//         ),
//       ),
//     );
//   }
// }

// class DestinationSearchDelegate extends SearchDelegate {
//   final Function(String) onSelected;

//   DestinationSearchDelegate({required this.onSelected});

//   @override
//   List<Widget>? buildActions(BuildContext context) {
//     return [
//       IconButton(
//         icon: Icon(Icons.clear),
//         onPressed: () => query = '',
//       ),
//     ];
//   }

//   @override
//   Widget? buildLeading(BuildContext context) {
//     return IconButton(
//       icon: Icon(Icons.arrow_back),
//       onPressed: () => close(context, null),
//     );
//   }

//   @override
//   Widget buildResults(BuildContext context) {
//     onSelected(query);
//     close(context, null);
//     return Container();
//   }

//   @override
//   Widget buildSuggestions(BuildContext context) {
//     return ListTile(
//       title: Text('Enter destination: $query'),
//     );
//   }
// }
