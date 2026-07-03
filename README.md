<div align="center">

# JarvisClipThat

<u>Lightweight Native Clipboard Manager for macOS</u>

## Overview

![Version](https://img.shields.io/badge/Version-1.0.0-purple)
![Platform](https://img.shields.io/badge/Platform-macOS%2011.0+-black?logo=apple)
![Language](https://img.shields.io/badge/Language-Swift%205.10-orange?logo=swift)
![Architecture](https://img.shields.io/badge/Architecture-Universal%20(Apple%20Silicon/Intel)-blue)

*Built with native macOS technologies:*

<img src="https://img.shields.io/badge/SwiftUI-000000.svg?style=flat&logo=Swift&logoColor=orange" alt="SwiftUI">
<img src="https://img.shields.io/badge/AppKit-505050.svg?style=flat&logo=Apple&logoColor=white" alt="AppKit">
<img src="https://img.shields.io/badge/CoreGraphics-3178C6.svg?style=flat&logo=Apple&logoColor=white" alt="CoreGraphics">

<br><br>

JarvisClipThat is a minimalistic clipboard app built for MacOS, introducing fully functionable copying history available locally on request. It is a part of the Shrimple Project and as the whole project it's open-source, free, simple and fully supported. It is available for any MacOS since Big Sur (11) and will also work on Intel-based Macs.

</div>

---

## Screenshots

<img width="304" height="450" alt="obraz" src="https://github.com/user-attachments/assets/be169417-9549-45f0-bd26-3767af7d977b" />
<img width="304" height="450" alt="obraz" src="https://github.com/user-attachments/assets/2d224398-dd89-4670-9686-5128e83c81af" />


---

## Key features

* **Minimalist Interface** – The app runs as a MenuUI Agent, staying out of your Dock and occupying only a small footprint on your menu bar.
* **Multimedia Capable** – Fully supports high-resolution images as well as text up to 20,000 characters.
* **Burner Mode** – Allows the user to switch between JarvisClipThat and standard MacOS clipboard mode.
* **Autostart** - The app is starting along with the system letting you forget about starting it manually eacah time.
* **Global Shortcut** – Call the clipboard history anywhere and anytime using the `Shift + Option + V` shortcut.

---

## Supported Platforms

| Platform | Architecture | Minimum OS Version | Status |
| :--- | :--- | :--- | :--- |
| **macOS** | Apple Silicon | macOS 11.0 (Big Sur) or newer | **Supported (Native)** |
| **macOS** | Intel Core | macOS 11.0 (Big Sur) or newer | **Supported (Native)** |
| **Windows / Linux**| - | - | Not Supported |

---

## Installation & First Launch

Reviewers and users **do not need to compile this project from source**. Follow these steps to get the app running in seconds:

1. Go to the [Releases Page](https://github.com/Predsu/JarvisClipThat/releases/latest) and download the `JarvisClipThat.dmg` file.
2. Double-click the downloaded `.dmg` file and drag **JarvisClipThat** into your **Applications** folder.
3. Open your Applications folder and launch the app.

### Overriding macOS Gatekeeper (Fixing the "Developer Cannot Be Verified" Error)

Because this app is an open-source project and is not distributed through the Mac App Store, macOS Gatekeeper might block the first launch with a warning. To safely bypass this:

1. Try to open the app normally. You'll get the warning about security.
2. Open System Settings → Privacy & Security.
3. Scroll to the bottom. You'll see a message that the app was blocked. Click Open Anyway.
4. Enter your password or use Touch ID.
5. Confirm Open.
6. The app will now launch successfully.

---

## Project Structure

The project is built using the standard native Swift application architecture, utilizing a lightweight configuration requiring no external setup files:

```sh
└── JarvisClipThat/
    ├── JarvisClipThatApp.swift   # Lifecycle, system menu bar items, and shortcuts
    └── ContentView.swift         # Clipboard storage manager logic and SwiftUI interface
```

Requirements for Development
* Operating System: macOS 11+ (Big Sur)
* IDE/Compiler: Xcode 16.0+

## Privacy & Security
JarvisClipThat is built with absolute privacy in mind. Out of the box, it requires zero configuration and adheres to the following rules:
* RAM-Only Storage – The copy history is kept strictly in the volatile memory (RAM) of your machine.
* Zero Disk Footprint – It does not save your texts or images to any database, hard drive, plist, or cache file. Closing the app or restarting your Mac wipes the history completely.
	•	No Cloud Overhead – The app runs fully locally and has no network tracking, ensuring no data ever leaves your computer.

## About AI Usage
I'm a beginner in Swift programming and native MacOS apps thus the AI has been used for explaining how certain things work, small repetitive code completions and code review. About 10% of the whole repository code is written directly by AI.
