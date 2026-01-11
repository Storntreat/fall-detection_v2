import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

void main() => runApp(MaterialApp(
  debugShowCheckedModeBanner: false, 
  theme: ThemeData(primarySwatch: Colors.red),
  home: FallGuardApp()
));

class FallGuardApp extends StatefulWidget {
  @override
  _FallGuardAppState createState() => _FallGuardAppState();
}

class _FallGuardAppState extends State<FallGuardApp> {
  final ble = FlutterReactiveBle();
  String connectionStatus = "Disconnected";
  bool alertActive = false; // This controls the screen state

  // UUIDs from your partner's ESP32 code
  final String serviceId = "12345678-90ab-cdef-fedc-ba0987654321";
  final String charId = "aabbccdd-eeff-0011-2233-445566778899";

  void startLifeCycle() async {
    // Request permissions for iOS
    await [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.location].request();
    setState(() => connectionStatus = "Scanning...");
    
    ble.scanForDevices(withServices: []).listen((device) {
      if (device.name == "FallBelt") {
        ble.connectToDevice(id: device.id).listen((state) {
          setState(() => connectionStatus = state.connectionState.toString().split('.').last);
          if (state.connectionState == DeviceConnectionState.connected) {
            listenToArduino(device.id);
          }
        });
      }
    });
  }

  void listenToArduino(String deviceId) {
    final characteristic = QualifiedCharacteristic(
        serviceId: Uuid.parse(serviceId),
        characteristicId: Uuid.parse(charId),
        deviceId: deviceId);

    ble.subscribeToCharacteristic(characteristic).listen((data) {
      // If the ESP32 sends a '2' (Fall detected)
      if (data.isNotEmpty && data[0] == 2) {
        triggerFallAlert();
      }
    });
  }

  // Helper function to trigger the alert state
  void triggerFallAlert() {
    setState(() {
      alertActive = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // If a fall is detected (or simulated), show the Red Alert Screen
    if (alertActive) {
      return Scaffold(
        backgroundColor: Colors.red,
        body: Container(
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber_rounded, size: 150, color: Colors.white),
              SizedBox(height: 20),
              Text("FALL DETECTED!", 
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)),
              Text("Emergency contact notified", 
                style: TextStyle(fontSize: 18, color: Colors.white70)),
              SizedBox(height: 50),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.red,
                  padding: EdgeInsets.symmetric(horizontal: 50, vertical: 20)
                ),
                onPressed: () => setState(() => alertActive = false), 
                child: Text("I AM OKAY", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))
              )
            ],
          ),
        ),
      );
    }

    // Otherwise, show the normal dashboard
    return Scaffold(
      appBar: AppBar(title: Text("Fall Guard Dashboard")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.health_and_safety, size: 80, color: Colors.green),
            SizedBox(height: 20),
            Text("Belt Status: $connectionStatus", style: TextStyle(fontSize: 18)),
            SizedBox(height: 40),
            ElevatedButton(
              onPressed: startLifeCycle, 
              child: Text("CONNECT TO BELT")
            ),
            SizedBox(height: 20),
            // THIS IS THE WORKING SIMULATION BUTTON
            OutlinedButton(
              onPressed: triggerFallAlert, 
              child: Text("SIMULATE FALL (DEMO MODE)")
            )
          ],
        ),
      ),
    );
  }
}