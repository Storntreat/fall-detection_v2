// pubspec.yaml dependencies:
// flutter_blue_plus: ^1.14.0
// permission_handler: ^11.0.0
// url_launcher: ^6.2.0
// geolocator: ^10.1.0
// firebase_core: ^2.24.2
// firebase_database: ^10.4.0
// google_maps_flutter: ^2.5.0
// shared_preferences: ^2.2.0

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  runApp(const FallBeltApp());
}

class FallBeltApp extends StatelessWidget {
  const FallBeltApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FallBelt Community',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
      ),
      home: const RoleSelectionScreen(),
    );
  }
}

// ============= ROLE SELECTION SCREEN =============
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade400, Colors.blue.shade800],
          ),
         ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.favorite, size: 80, color: Colors.white),
                  const SizedBox(height: 20),
                  const Text(
                    'FallBelt Community',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Choose your role',
                    style: TextStyle(fontSize: 18, color: Colors.white70),
                  ),
                  const SizedBox(height: 60),
                  
                  // User Button
                  SizedBox(
                    width: double.infinity,
                    height: 120,
                     child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const UserScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 8,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.person, size: 48),
                          const SizedBox(height: 8),
                          const Text(
                            'I\'m a User',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Connect my FallBelt device',
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Volunteer Button
                  SizedBox(
                    width: double.infinity,
                    height: 120,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const VolunteerScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 8,
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.volunteer_activism, size: 48),
                          SizedBox(height: 8),
                          Text(
                            'I\'m a Volunteer',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          Text('Help people in my area', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============= USER SCREEN =============
class UserScreen extends StatefulWidget {
  const UserScreen({Key? key}) : super(key: key);

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> with WidgetsBindingObserver {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  bool _isConnected = false;
  bool _isScanning = false;
  bool _autoReconnect = true;
  String _emergencyNumber = '4168380498';
  
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _stateSubscription;

  final String serviceUUID = "12345678-90ab-cdef-fedc-ba0987654321";
  final String characteristicUUID = "aabbccdd-eeff-0011-2233-445566778899";
  
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestPermissions();
    _loadSavedDevice();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectionSubscription?.cancel();
    _stateSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Auto-reconnect when app comes to foreground
    if (state == AppLifecycleState.resumed && _autoReconnect && _device != null) {
      _reconnectToDevice();
    }
  }

Future<void> _requestPermissions() async {

    await [
      Permission.bluetooth,
      Permission.locationWhenInUse,
      Permission.phone,
    ].request();

}


  // SAVE DEVICE ID FOR AUTO-RECONNECT
  Future<void> _saveDeviceId(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_device_id', deviceId);
    print('Saved device ID: $deviceId');
  }

  // LOAD SAVED DEVICE AND AUTO-CONNECT
  Future<void> _loadSavedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString('saved_device_id');
    
    if (savedId != null) {
      print('Found saved device: $savedId');
      _showSnackBar('Reconnecting to saved device...');
      
      // Try to connect directly to saved device
      try {
        final device = BluetoothDevice.fromId(savedId);
        await _connectToDevice(device);
      } catch (e) {
        print('Failed to reconnect: $e');
        _showSnackBar('Reconnection failed. Please scan again.');
      }
    }
  }

  // RECONNECT TO SAVED DEVICE
  Future<void> _reconnectToDevice() async {
    if (_device != null && !_isConnected) {
      print('Attempting reconnection...');
      try {
        await _connectToDevice(_device!);
      } catch (e) {
        print('Reconnection failed: $e');
      }
    }
  }

  void _startScan() async {
    setState(() => _isScanning = true);

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

      FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          if (result.device.name == 'FallBelt') {
            print('Found FallBelt: ${result.device.id}');
            FlutterBluePlus.stopScan();
            _connectToDevice(result.device);
            break;
          }
        }
      });
    } catch (e) {
      _showSnackBar('Scan error: $e');
    }

    await Future.delayed(const Duration(seconds: 10));
    setState(() => _isScanning = false);
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
  try {
    // 1. Clean up old connection attempts
    await _connectionSubscription?.cancel();
    
    print("DEBUG: Attempting to connect to ${device.platformName}...");
    await device.connect(autoConnect: false); 
    
    setState(() {
      _device = device;
      _isConnected = true;
    });

    // 2. Save for future auto-connect
    await _saveDeviceId(device.id.toString());
    _showSnackBar('✓ Connected to FallBelt!');

    // 3. Monitor connection state
    _stateSubscription = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected && _autoReconnect) {
        print('Device disconnected, attempting reconnect...');
        setState(() => _isConnected = false);
        Future.delayed(const Duration(seconds: 2), () {
          if (_autoReconnect && mounted) {
            _reconnectToDevice();
          }
        });
      } else if (state == BluetoothConnectionState.connected) {
        setState(() => _isConnected = true);
      }
    });

    // 4. THE CRITICAL PART: Discovery & Subscription
    // Give iOS a moment to stabilize the GATT database
    await Future.delayed(const Duration(milliseconds: 500));
    
    print("DEBUG: Starting service discovery...");
    List<BluetoothService> services = await device.discoverServices();
    print("DEBUG: Found ${services.length} services.");

    for (BluetoothService service in services) {
      String foundServiceUuid = service.uuid.toString().toLowerCase();
      print("Checking Service: $foundServiceUuid");

      if (foundServiceUuid == serviceUUID.toLowerCase()) {
        print("✅ MATCHED SERVICE UUID!");

        for (BluetoothCharacteristic char in service.characteristics) {
          String foundCharUuid = char.uuid.toString().toLowerCase();
          print("  -- Checking Characteristic: $foundCharUuid");

          if (foundCharUuid == characteristicUUID.toLowerCase()) {
            _characteristic = char;
            print("✅ MATCHED CHARACTERISTIC! Subscribing...");

            // Enable Notifications
            bool success = await char.setNotifyValue(true);
            print("!! Notification sub success: $success !!");
            
            // Listen for live data
            char.onValueReceived.listen((value) {
              if (value.isNotEmpty) {
                print("🚨 DATA FROM BELT: ${value[0]} 🚨"); 
                _handleAlert(value[0]);
              }
            });
            
            return; // Exit function successfully
          }
        }
      }
    }
    
    print("❌ ERROR: Finished loop but never matched UUIDs. Check your variables!");

  } catch (e) {
    print('Connection error: $e');
    _showSnackBar('Connection failed: $e');
    setState(() => _isConnected = false);
  }
}

  void _disconnect() async {
    setState(() => _autoReconnect = false);
    
    if (_device != null) {
      await _device!.disconnect();
      setState(() {
        _device = null;
        _characteristic = null;
        _isConnected = false;
      });
      _showSnackBar('Disconnected');
    }
  }

  Future<void> _handleAlert(int value) async {
    print('Received alert: $value');

    if (value == 0) {
      // FALSE ALARM - Do nothing
      _showSnackBar('✓ False alarm - all good!');
      return;
    }

    if (value == 1) {
      // HELP NEEDED - Upload to Firebase
      _showSnackBar('⚠️ Help request sent to volunteers');
      await _uploadLocationToFirebase();
      return;
    }

    if (value == 2) {
      // EMERGENCY - Auto call
      _showEmergencyDialog();
      return;
    }
  }

  Future<void> _uploadLocationToFirebase() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      
      String userId = _device?.id.toString() ?? 'unknown';
      
      await _database.child('help_requests').push().set({
        'userId': userId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': ServerValue.timestamp,
        'status': 'active',
      });

      print('Location uploaded: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      print('Failed to upload location: $e');
      _showSnackBar('Failed to send location');
    }
  }

  void _showEmergencyDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => EmergencyCallDialog(
        emergencyNumber: _emergencyNumber,
        onCall: _makeEmergencyCall,
      ),
    );
  }

  Future<void> _makeEmergencyCall() async {
    final Uri phoneUri = Uri(scheme: 'tel', path: _emergencyNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Mode'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                size: 100,
                color: _isConnected ? Colors.green : Colors.grey,
              ),
              const SizedBox(height: 20),
              Text(
                _isConnected ? 'Connected to FallBelt' : 'Not Connected',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _isConnected ? Colors.green : Colors.grey,
                ),
              ),
              if (_isConnected)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text(
                    '✓ Auto-reconnect enabled',
                    style: TextStyle(fontSize: 14, color: Colors.green),
                  ),
                ),
              const SizedBox(height: 40),
              
              if (!_isConnected)
                ElevatedButton.icon(
                  onPressed: _isScanning ? null : _startScan,
                  icon: _isScanning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.bluetooth_searching),
                  label: Text(_isScanning ? 'Scanning...' : 'Connect to FallBelt'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                )
              else
                Column(
                  children: [
                    const Text(
                      '✓ Monitoring active',
                      style: TextStyle(fontSize: 16, color: Colors.green),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _disconnect,
                      icon: const Icon(Icons.bluetooth_disabled),
                      label: const Text('Disconnect'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                    ),
                  ],
                ),
              
              const SizedBox(height: 40),
              
              // Emergency number setting
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text('Emergency Contact Number'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: TextEditingController(text: _emergencyNumber),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: '4168380498',
                        ),
                        keyboardType: TextInputType.phone,
                        textAlign: TextAlign.center,
                        onChanged: (value) => _emergencyNumber = value,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============= VOLUNTEER SCREEN =============
class VolunteerScreen extends StatefulWidget {
  const VolunteerScreen({Key? key}) : super(key: key);

  @override
  State<VolunteerScreen> createState() => _VolunteerScreenState();
}

class _VolunteerScreenState extends State<VolunteerScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Timer? _refreshTimer;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    _startPeriodicRefresh();
  }

  void _startPeriodicRefresh() {
    // Refresh every 10 seconds (not live)
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _loadHelpRequests();
    });
    _loadHelpRequests(); // Load immediately
  }

  Future<void> _loadHelpRequests() async {
    try {
      final snapshot = await _database.child('help_requests').get();
      
      if (!snapshot.exists) {
        print('No help requests found');
        return;
      }

      Set<Marker> newMarkers = {};
      Map<dynamic, dynamic> requests = snapshot.value as Map<dynamic, dynamic>;

      requests.forEach((key, value) {
        if (value['status'] == 'active') {
          double lat = value['latitude'];
          double lng = value['longitude'];
          
          newMarkers.add(
            Marker(
              markerId: MarkerId(key),
              position: LatLng(lat, lng),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
              infoWindow: InfoWindow(
                title: 'Help Needed',
                snippet: 'Tap marker for details',
              ),
              onTap: () => _showHelpDialog(lat, lng, key),
            ),
          );
        }
      });

      if (mounted) {
        setState(() {
          _markers = newMarkers;
        });
      }

      print('Loaded ${newMarkers.length} help requests');
    } catch (e) {
      print('Error loading help requests: $e');
    }
  }

  void _showHelpDialog(double lat, double lng, String requestId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Help Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📍 Location:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Lat: ${lat.toStringAsFixed(6)}'),
            Text('Lng: ${lng.toStringAsFixed(6)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _openInMaps(lat, lng);
            },
            icon: const Icon(Icons.navigation),
            label: const Text('Navigate'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          ),
          ElevatedButton(
            onPressed: () {
              _markAsResolved(requestId);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Resolved'),
          ),
        ],
      ),
    );
  }

  Future<void> _markAsResolved(String requestId) async {
    await _database.child('help_requests/$requestId/status').set('resolved');
    _loadHelpRequests();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marked as resolved')),
      );
    }
  }

  Future<void> _openInMaps(double lat, double lng) async {
    // Opens in phone's default maps app
    final Uri mapsUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(mapsUri)) {
      await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Volunteer Mode'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHelpRequests,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(43.2609, -79.9192), // Hamilton, ON
          zoom: 12,
        ),
        markers: _markers,
        onMapCreated: (controller) {
          _mapController = controller;
        },
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loadHelpRequests,
        icon: const Icon(Icons.refresh),
        label: Text('${_markers.length} Active'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}

// ============= EMERGENCY CALL DIALOG =============
class EmergencyCallDialog extends StatefulWidget {
  final String emergencyNumber;
  final VoidCallback onCall;

  const EmergencyCallDialog({
    Key? key,
    required this.emergencyNumber,
    required this.onCall,
  }) : super(key: key);

  @override
  State<EmergencyCallDialog> createState() => _EmergencyCallDialogState();
}

class _EmergencyCallDialogState extends State<EmergencyCallDialog> {
  int _countdown = 5;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() async {
    for (int i = _countdown; i > 0; i--) {
      if (_cancelled) return;
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || _cancelled) return;
      setState(() => _countdown = i - 1);
    }

    if (!_cancelled && mounted) {
      Navigator.pop(context);
      widget.onCall();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.red.shade900,
      title: const Text(
        '🚨 EMERGENCY',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 28),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'NO RESPONSE DETECTED!',
            style: TextStyle(color: Colors.white, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          Text(
            'Calling ${widget.emergencyNumber} in...',
            style: const TextStyle(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: Center(
              child: Text(
                '$_countdown',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 60,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() => _cancelled = true);
            Navigator.pop(context);
          },
          child: const Text(
            'CANCEL',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            setState(() => _cancelled = true);
            Navigator.pop(context);
            widget.onCall();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: Text(
            'CALL NOW',
            style: TextStyle(color: Colors.red.shade900, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}