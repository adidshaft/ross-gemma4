# Device Install QA

This runbook covers local install and device-readiness notes for the Ross internal alpha.

## iOS

### Simulator

Build:

```bash
cd /Users/amanpandey/projects/ross/ios
xcodebuild -project Ross.xcodeproj -scheme Ross -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4.1' -derivedDataPath tmp/DerivedData build
```

Backend notes:

- simulator can use `http://127.0.0.1:<port>`
- if the backend is not on `8080`, save the override from `Settings > Advanced`

### Physical iPhone

Expected signing path:

1. open [`ios/Ross.xcodeproj`](/Users/amanpandey/projects/ross/ios/Ross.xcodeproj)
2. select the `Ross` target
3. choose your Apple development team
4. let Xcode resolve signing
5. connect a physical iPhone
6. choose the device and run

Backend notes:

- use your Mac's LAN IP, not `127.0.0.1`
- example: `http://192.168.x.x:8787`

Known blocker:

- physical-device install and provisioning are not yet completed in this phase

Do not commit:

- provisioning profiles
- certificates
- personal device identifiers

## Android

### Emulator

Build:

```bash
cd /Users/amanpandey/projects/ross/android
./gradlew :app:assembleDebug
```

Backend notes:

- default emulator host mapping is `http://10.0.2.2:8080`
- if the backend runs on `8787`, save `http://10.0.2.2:8787` from `Settings > Advanced`

### Physical Android device

Install path:

1. connect device with developer mode enabled
2. use Android Studio run or install the debug APK
3. point Ross to your host machine's LAN IP from `Settings > Advanced`

Backend notes:

- use `http://<your-mac-lan-ip>:8787`
- ensure phone and host are on the same network

Biometric notes:

- quick unlock proof should be done on a real device
- emulator biometric behavior is not enough for a final claim

## Current truth

It is fair to say:

- simulator and emulator install paths are available
- local backend addressing is documented

It is not yet fair to say:

- physical iPhone install is completed
- quick unlock is proven on hardware
