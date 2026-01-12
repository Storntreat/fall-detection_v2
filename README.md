# fall_detection_v2

A Flutter app created mainly for IOS for DeltaHacks 12.
It connects to a ESP32 via BLE, which detects falls through an integrated accelerometer.
The ESP32 gives the user the option to cancel the fall-signal by pressing a button on the board, contact a pre-determined emergency contact by long holding it, or letting it time out and automatically calling emergency services in the case that the fall renders the user unconscious or unable to move.
The ESP32 then sends the signal to the Flutter app on the users phone, which sends the information to Firebase or calls emergency services, allowing volunteers on the same app to recieve the first users location and help them.

## Getting Started

Unfortunately, the app is not avaliable on the app store, and is still limited locally to developer mode.
