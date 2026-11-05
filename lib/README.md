# TEFSM Water Finder

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.16+-02569B?logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS-green" alt="Platform">
  <img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License">
  <img src="https://img.shields.io/badge/Bluetooth-BLE-lightgrey" alt="BLE">
  <img src="https://img.shields.io/github/actions/workflow/status/YOUR_USERNAME/tefsm_water_finder/build.yml?branch=main" alt="Build">
</p>

**Flutter app** for DIY TEFSM (Time-domain Electromagnetic Frequency Selection Method) groundwater detectors based on ESP32.

Connects via Bluetooth Low Energy, downloads measurement CSV files from the device, and automatically generates a **colored Heatmap + Contour map**.

---

## Features

| Feature | Description |
|---------|-------------|
| **BLE Scan & Connect** | Discover and connect to ESP32 using `flutter_blue_plus` |
| **File Transfer** | `LIST` command → list CSVs · `GET filename.csv` → download until `END_FILE` |
| **CSV Parsing** | Long format: `Line, Site, Frequency, Voltage` |
| **2D Matrix** | Auto-detect unique Sites (X) and Frequencies (Y) |
| **Bilinear Interpolation** | Smooth gaps between measured points (factor 1–6×) |
| **Heatmap** | Blue = low voltage (water potential) → Red = high voltage (dry rock) |
| **Contour Lines** | Real isolines via Marching Squares algorithm (3–16 levels) |
| **Save PNG** | High-quality export (`pixelRatio: 3.0`) to device storage |
| **Color Legend** | Clear scale with min/max values |

---

## Project Structure

```
lib/
├── main.dart
├── models/
│   ├── measurement_point.dart
│   └── heatmap_data.dart
├── services/
│   ├── bluetooth_service.dart   # BLE connection + file protocol
│   └── csv_processor.dart       # Parsing + Bilinear Interpolation
├── screens/
│   ├── scan_screen.dart         # Device discovery
│   ├── files_screen.dart        # CSV list & download
│   └── map_screen.dart          # Heatmap / Contour view + save
└── widgets/
    └── heatmap_painter.dart     # CustomPainter (heatmap + contours)
```

---

## Getting Started

### Prerequisites
- Flutter 3.16+ (Dart 3.2+)
- Android Studio / VS Code
- Physical device recommended (Bluetooth required)

### Installation

```bash
git clone https://github.com/YOUR_USERNAME/tefsm_water_finder.git
cd tefsm_water_finder
flutter pub get
flutter run
```

### Dependencies

```yaml
flutter_blue_plus: ^1.32.12
path_provider: ^2.1.4
path: ^1.9.0
csv: ^6.0.0
permission_handler: ^11.3.1
google_fonts: ^6.2.1
```

---

## ESP32 Firmware Protocol

Your ESP32 must respond to these plain-text commands (ended by `\n`):

| Command | Expected Response |
|---------|-------------------|
| `LIST` | One filename per line, then `END_LIST` |
| `GET filename.csv` | Full file content, then `END_FILE` |

**Example LIST reply:**
```
survey_01.csv
line2_data.csv
END_LIST
```

### Default BLE UUIDs

Nordic UART Service (preferred):
- Service: `6E400001-B5A3-F393-E0A9-E50E24DCCA9E`
- RX (Write): `6E400002-B5A3-F393-E0A9-E50E24DCCA9E`
- TX (Notify): `6E400003-B5A3-F393-E0A9-E50E24DCCA9E`

Fallback: `0000FFE0-...` / `0000FFE1-...`

Edit UUIDs in `lib/services/bluetooth_service.dart` if your firmware differs.

---

## CSV Format

Long format (one measurement per row):

```csv
Line,Site,Frequency,Voltage
1,1,170,125.4
1,1,190,130.2
1,2,170,120.1
1,2,190,128.7
```

- **Site** → X-axis (measurement point)
- **Frequency** → Y-axis (depth proxy, inverted so low frequency is at bottom)
- **Voltage** → Color value

---

## Android Permissions

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30"/>
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

## iOS Permissions

Add to `ios/Runner/Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Need Bluetooth to connect to the groundwater detector</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>Need Bluetooth to connect to the groundwater detector</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Location is required for Bluetooth scanning on iOS</string>
```

---

## How the Contour Algorithm Works

Uses a simplified **Marching Squares** approach:

1. For each isolevel between min and max voltage
2. Examine every 2×2 cell of the matrix
3. Determine which edges the contour crosses by linear interpolation
4. Draw line segments and optional value labels

---

## Roadmap

- [x] BLE connection & file download
- [x] CSV → Heatmap
- [x] Bilinear interpolation
- [x] Contour lines (Marching Squares)
- [x] Save map as PNG
- [ ] Multi-line (multiple profiles) support
- [ ] Share image via system share sheet
- [ ] PDF report export
- [ ] Dark mode

---


---

## Continuous Integration (GitHub Actions)

Every push to `main` (and every Pull Request) automatically:

1. Sets up Flutter + Java
2. Generates Android platform files if missing
3. Builds **release APKs** (split per ABI: armeabi-v7a, arm64-v8a, x86_64)
4. Uploads the APKs as downloadable **Artifacts** (kept for 30 days)

### How to download the APK from Actions
1. Go to the **Actions** tab of the repository
2. Click the latest successful workflow run
3. Scroll to **Artifacts** → download `tefsm-water-finder-apks`

### Creating a formal Release
Push a version tag:

```bash
git tag v1.0.0
git push origin v1.0.0
```

This triggers an extra job that creates a GitHub Release and attaches the APKs.

## License

This project is licensed under the **MIT License** – see the [LICENSE](LICENSE) file for details.

---

## Contributing

Pull requests are welcome. For major changes, please open an issue first.

---

**Made for DIY TEFSM / ESP32 groundwater detectors.**
