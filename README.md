# Birthdates

A modern, native macOS birthday and milestone tracking application built with **SwiftUI** and **SwiftData**. Keep track of important dates, customize notifications, organize friends by categories, and never forget a birthday.

---

## ✨ Features

- **🎉 Smart Countdown & Milestones**: See upcoming birthdays at a glance, calculate turning ages, leap year birthdays, and zodiac signs.
- **🏷️ Custom Categories**: Group contacts into customizable categories (Family, Close Friends, Work, etc.) with custom colors and symbols.
- **🔔 Intelligent Notifications**:
  - Local macOS notifications with flexible lead times (day of, 1 day before, 3 days before, 1 week before).
  - Custom per-friend reminder messages and time preferences.
  - Rolling scheduling window designed to respect macOS notification queue limits.
- **🎁 Gift Ideas & Memories**: Log gift ideas and cherished memories directly on each friend's profile.
- **📅 Interactive Calendar & Timeline**: View birthdays across months in a clean macOS calendar layout.
- **🔒 Privacy-First**: 100% offline and private. All data is stored locally on your Mac using Apple's modern **SwiftData** framework.
- **🖥️ Native macOS Design**: Built with AppKit and SwiftUI for a lightweight, responsive, and seamless macOS experience.

---

## 🛠️ Requirements

- **macOS**: 14.0 or later (configured for latest macOS SDKs)
- **Xcode**: 15.0+ / Xcode 16+
- **Swift**: 5.9+

---

## 🚀 Building from Source

1. **Clone the repository**:
   ```bash
   git clone https://github.com/<your-username>/birthdates.git
   cd birthdates
   ```

2. **Open the project in Xcode**:
   ```bash
   open birthdates.xcodeproj
   ```

3. **Select your Development Team**:
   - In Xcode, select the **birthdates** target.
   - Go to **Signing & Capabilities**.
   - Select your personal Team under **Signing**.

4. **Build and Run**:
   - Press `Cmd + R` to build and run the app.

---

## 📦 Building via Command Line

To create a release build from the terminal:

```bash
xcodebuild \
  -project "birthdates.xcodeproj" \
  -scheme "birthdates" \
  -configuration Release \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build
```

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
