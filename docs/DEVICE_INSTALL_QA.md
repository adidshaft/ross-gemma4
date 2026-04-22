# Device Install QA

This runbook covers simulator, emulator, and physical-device readiness for Ross.

## iOS simulator

Build:

```bash
cd /Users/amanpandey/projects/ross/ios
xcodebuild -project Ross.xcodeproj -scheme Ross -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4.1' -derivedDataPath tmp/DerivedData build
swift test --scratch-path tmp/swiftpm
```

Backend notes:

- iOS Simulator can use `http://127.0.0.1:<port>`
- if your backend is on `8787`, use `http://127.0.0.1:8787`
- the app also supports `Settings > Advanced > Save test server`

Current truth:

- simulator build is proven
- manual simulator QA is partially proven in this phase

## Physical iPhone

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

- physical-device install and provisioning were not completed in this phase

Do not commit:

- provisioning profiles
- certificates
- personal device identifiers

## Android emulator

Build:

```bash
cd /Users/amanpandey/projects/ross/android
./gradlew :app:assembleDebug
./gradlew :app:testDebugUnitTest
```

Backend notes:

- default emulator mapping is `http://10.0.2.2:8080`
- if your backend runs on `8787`, use `http://10.0.2.2:8787`
- the app also supports `Settings > Advanced > Save test server`

Current blocker:

- no Android emulator was attached during this session, so a fresh emulator walkthrough was not run

## Physical Android device

Install path:

1. connect the device with developer mode enabled
2. use Android Studio Run or install the debug APK
3. point Ross to your Mac's LAN IP from `Settings > Advanced`

Backend notes:

- use `http://<your-mac-lan-ip>:8787`
- keep the device and host on the same network

Biometric note:

- quick unlock should be validated on a real device before making any hardware claim

## Xcode test-action note

`xcodebuild test` is still limited by the shared `Ross` scheme:

- the scheme currently has no Xcode testables in `TestAction`
- there is no dedicated Xcode test target in the project file

For this phase, the safe validation path remains:

- `xcodebuild ... build`
- `swift test --scratch-path tmp/swiftpm`

## Current truth

It is fair to say:

- simulator and emulator build paths are documented
- local backend addressing is documented

It is not yet fair to say:

- physical iPhone install is completed
- Android emulator QA was freshly run in this session
- quick unlock is proven on hardware
