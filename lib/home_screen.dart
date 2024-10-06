import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

class Geofence {
  final String id;
  final String name;
  final LatLng location;
  final String foodName;

  Geofence({
    required this.id,
    required this.name,
    required this.location,
    required this.foodName,
  });
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleMapController? _mapController;
  Location _location = Location();
  LatLng _initialCameraPosition = const LatLng(0, 0);
  Set<Circle> _circles = {};
  Set<Marker> _markers = {};
  List<Geofence> geofences = [
    Geofence(
        id: '1',
        name: 'Geofence 1',
        location: LatLng(17.7244, 83.3079),
        foodName: 'Pizza'),
    Geofence(
        id: '2',
        name: 'Geofence 2',
        location: LatLng(17.7370, 83.3150),
        foodName: 'Burger'),
    // Add more geofences here
  ];
  LocationData? currentLocation;
  StreamSubscription<LocationData>? _locationSubscription;
  Set<String> _enteredGeofences = {};

  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _initializeTts();
    _initializeNotifications();
    getCurrentLocation();
    _addGeofenceCircles();
  }

  Future<void> _initializeNotifications() async {
    var initializationSettingsAndroid =
        const AndroidInitializationSettings('@mipmap/ic_launcher');
    var initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onSelectNotification: null, // Disable default onSelectNotification
    );
  }

  void getCurrentLocation() async {
    _location.getLocation().then((value) {
      currentLocation = value;
      addCurrentLocMarker(currentLocation!);
      _updateCameraPosition(
          currentLocation!.latitude, currentLocation!.longitude);
    });

    _locationSubscription = _location.onLocationChanged.listen((newLoc) {
      setState(() {
        currentLocation = newLoc;
        addCurrentLocMarker(newLoc);
        _updateCameraPosition(newLoc.latitude, newLoc.longitude);
      });

      for (Geofence geofence in geofences) {
        var distanceBetween = haversineDistance(
          LatLng(newLoc.latitude!, newLoc.longitude!),
          geofence.location,
        );

        if (distanceBetween < 200 && !_enteredGeofences.contains(geofence.id)) {
          _enteredGeofences.add(geofence.id);
          _showNotification(
            title: 'Entered ${geofence.name}',
            body: 'You have entered the geofence area.',
            zone: geofence.name,
            foodDetails: geofence.foodName,
          );
          _speakNotification(geofence.name, geofence.foodName);
        }
      }
    });
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  void _updateCameraPosition(double? latitude, double? longitude) {
    if (latitude != null && longitude != null && _mapController != null) {
      LatLng newPosition = LatLng(latitude, longitude);
      _mapController!.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: newPosition,
          zoom: 15,
        ),
      ));
    }
  }

  void _addGeofenceCircles() {
    setState(() {
      for (Geofence geofence in geofences) {
        _circles.add(Circle(
          circleId: CircleId(geofence.id),
          center: geofence.location,
          radius: 200,
          strokeWidth: 2,
          strokeColor: Colors.green,
          fillColor: Colors.green.withOpacity(0.15),
        ));
      }
    });
  }

  double haversineDistance(LatLng point1, LatLng point2) {
    double lat1 = point1.latitude;
    double lon1 = point1.longitude;
    double lat2 = point2.latitude;
    double lon2 = point2.longitude;

    var R = 6371e3;
    var phi1 = (lat1 * pi) / 180;
    var phi2 = (lat2 * pi) / 180;
    var deltaPhi = ((lat2 - lat1) * pi) / 180;
    var deltaLambda = ((lon2 - lon1) * pi) / 180;

    var a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    var c = 2 * atan2(sqrt(a), sqrt(1 - a));

    var d = R * c;
    return d;
  }

  void addCurrentLocMarker(LocationData locationData) {
    Marker currentLocaMarker = Marker(
      markerId: MarkerId('currentLocation'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      position: LatLng(locationData.latitude!, locationData.longitude!),
      infoWindow: InfoWindow(title: 'Current Location', snippet: 'my location'),
      onTap: () {
        print('current location tapped');
      },
    );

    setState(() {
      _markers.add(currentLocaMarker);
    });
  }

  Future<void> _initializeTts() async {
    await flutterTts.setLanguage('en-US');
    await flutterTts.setSpeechRate(1.0);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);
    await flutterTts.awaitSpeakCompletion(true);
  }

  Future<void> _speakNotification(String zone, String foodDetails) async {
    await flutterTts
        .speak('You have entered $zone. Food available: $foodDetails');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 42.0),
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _initialCameraPosition,
                zoom: 15,
              ),
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
                _updateCameraPosition(
                    currentLocation?.latitude, currentLocation?.longitude);
                _setMapStyle();
              },
              myLocationEnabled: true,
              mapType: MapType.normal,
              circles: _circles,
              markers: _markers,
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 86.0, vertical: 16.0),
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () {
                        // Navigate to your Search screen
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.directions),
                      onPressed: () {
                        // Navigate to your Trailing screen
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _setMapStyle() async {
    // Load the JSON map style for dark mode (optional)
    // String darkMapStyle = await DefaultAssetBundle.of(context).loadString('assets/dark_map_style.json');
    // _mapController.setMapStyle(darkMapStyle);
  }

  Future<void> _showNotification({
    required String title,
    required String body,
    required String zone,
    required String foodDetails,
  }) async {
    var androidPlatformChannelSpecifics = const AndroidNotificationDetails(
      'geofence_channel_id',
      'Geofence Channel',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );

    var platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload: 'geofence_payload',
    );
  }
}
