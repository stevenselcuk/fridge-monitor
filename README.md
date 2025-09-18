# Fridge Alert: Smart Refrigerator Door Monitor

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-iOS-lightgrey.svg)]()
[![Hardware](https://img.shields.io/badge/hardware-M5StickC%20Plus-orange.svg)]()

Never wonder if the fridge door was left open again! A smart, simple monitor using an M5StickC Plus and a dedicated iOS app to track every time your refrigerator is opened.

// TODO: A video would be good but 🍗

## About The Project

We've all been there: you come back to the kitchen to find the refrigerator door slightly ajar, wasting energy and spoiling food. Or maybe you're just curious about your family's snacking habits.

**Fridge Alert** is a DIY solution that turns a tiny, powerful M5StickC Plus microcontroller into a smart sensor for your fridge. It detects every time the door is opened and sends the data in real-time to a sleek and simple iOS application. With background notifications, you'll be alerted even when the app isn't active.

The core of this project is its smart detection method. Instead of relying on unreliable angle or position measurements, it uses **jerk detection** (the rate of change of acceleration) to accurately identify the sudden movement of the door opening or closing.

### Features

*   **Accurate Jerk Detection:** Robustly detects door movement, ignoring minor vibrations.
*   **Real-time Counter:** The iOS app instantly updates the door open count for the day.
*   **Historical Log:** Browse a timestamped list of every opening event.
*   **Push Notifications:** Get an alert on your iPhone whenever the door is opened while the app is in the background.
*   **Low Power:** The M5StickC is efficient and can run for extended periods on its battery.
*   **Device Battery Monitoring:** Keep an eye on the M5's battery level directly from the app.
*   **Wireless Communication:** Uses Bluetooth Low Energy (BLE) for a stable and power-efficient connection.

### Technology Stack

*   **Hardware:** M5StickC Plus
*   **Firmware:** C++ / Arduino Framework
*   **iOS App:** Swift / SwiftUI / CoreBluetooth

---

## Getting Started

To get your own Fridge Alert system up and running, you'll need to flash the firmware to the M5StickC and build the iOS app.

### Prerequisites

*   **Hardware:**
    *   An [M5StickC Plus](https://shop.m5stack.com/products/m5stickc-plus-esp32-pico-mini-iot-development-kit)
    *   A USB-C cable
*   **Software:**
    *   [Arduino IDE](https://www.arduino.cc/en/software)
    *   [Xcode](https://developer.apple.com/xcode/) (for the iOS app)
    *   An iPhone to run the app.
    *   An Apple Developer account to install the app on your physical device.

### Part 1: M5StickC Firmware Installation

1.  **Setup Arduino IDE for ESP32:**
    *   Open Arduino IDE. Go to `File` > `Preferences`.
    *   In "Additional Boards Manager URLs", add: `https://m5stack.oss-cn-shenzhen.aliyuncs.com/resource/arduino/package_m5stack_index.json`
    *   Go to `Tools` > `Board` > `Boards Manager`.
    *   Search for "M5Stack" and install it.

2.  **Install Required Libraries:**
    *   Go to `Tools` > `Manage Libraries`.
    *   Search for and install the **`M5Unified`** library.

3.  **Flash the Firmware:**
    *   Clone this repository and open the `fridge-m5.ino` file in the Arduino IDE.
    *   Connect your M5StickC Plus to your computer.
    *   Select the correct board: `Tools` > `Board` > `M5Stack Arduino` > `M5StickCPlus`.
    *   Select the correct port: `Tools` > `Port` > (Choose the port for your device).
    *   Click the **Upload** button (the arrow icon).

### Part 2: iOS Application Build

1.  **Open the Project:**
    *   Navigate to the `/ios-app` directory in this repository.
    *   Open the `FridgeApp.xcodeproj` file with Xcode.

2.  **Configure Signing:**
    *   In the project navigator, select the "FridgeApp" project.
    *   Go to the "Signing & Capabilities" tab.
    *   Select your developer account from the "Team" dropdown.

3.  **Build and Run:**
    *   Connect your iPhone to your Mac.
    *   Select your iPhone from the device list at the top of the Xcode window.
    *   Press the **Run** button (the play icon). The app will be built and installed on your device.

---

## How to Use

1.  **Attach the Device:** The M5StickC Plus has a magnetic back (or you can use double-sided tape). Attach it to the side or top of your refrigerator door, preferably in a vertical orientation.
2.  **Launch the App:** Open the Fridge Alert app on your iPhone.
3.  **Connect:** The app will automatically start scanning for the M5 device. Once found, it will connect. The status on the main screen will change to "Connected & Monitoring".
4.  **Monitor:** That's it! Every time you open the fridge door, you'll see the counter on the app's home screen increase.
5.  **Check History:** Navigate to the "History" tab to see a detailed log of when the door was opened.
6.  **Reset Counter:** Use the "Reset Counter on Device" button in the "Settings" tab to reset the count back to zero on both the M5 and the app.

## How It Works: Jerk Detection

The firmware doesn't simply measure the angle of the door. Instead, it calculates **jerk**, which is the rate of change of acceleration.

1.  The M5's built-in IMU (Inertial Measurement Unit) constantly reads acceleration data.
2.  The code compares the current acceleration reading to the previous one.
3.  A large, sudden difference between these readings signifies high jerk—the exact kind of motion that occurs when a stationary door is suddenly pulled open.
4.  If the calculated jerk exceeds a predefined `jerkThreshold`, the device registers it as a door-opening event and increments the counter.
5.  A cooldown period prevents a single event (like a quick open-and-close) from being counted multiple times.

This method is highly effective and avoids the calibration issues associated with angle-based or gyroscope-based solutions.

## License

Distributed under the MIT License. See `LICENSE` for more information.