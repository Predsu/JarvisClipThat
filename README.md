<div align="center">

# JarvisClipThat

<u>Lightweight Native Clipboard Manager for MacOS</u>

## Overview

![Version](https://img.shields.io/badge/Version-1.0.0-purple)
![Platform](https://img.shields.io/badge/Platform-macOS%2011.0+-black?logo=apple)
![Language](https://img.shields.io/badge/Language-Swift%205.10-orange?logo=swift)
![Architecture](https://img.shields.io/badge/Architecture-Universal%20(Apple%20Sillicon/Intel)-blue)

*Built with the native macOS technologies:*

<img src="https://img.shields.io/badge/SwiftUI-000000.svg?style=flat&logo=Swift&logoColor=orange" alt="SwiftUI">
<img src="https://img.shields.io/badge/AppKit-505050.svg?style=flat&logo=Apple&logoColor=white" alt="AppKit">
<img src="https://img.shields.io/badge/CoreGraphics-3178C6.svg?style=flat&logo=Apple&logoColor=white" alt="CoreGraphics">

<br><br>

JarvisClipThat is minimalistic clipboard app built for MacOS, introducing fully functionable copying history available locally on request. It is a part of the Shrimple Project and as the whole project it's open-source, free, simple and fully supported. It is available for any MacOS since Big Sur (11) and will also work on Intel-based Macs.

</div>

---

## Key features

* **Minimalist interface** – App is running as MenuUI Agent staying out of Dock and taking only small amount of place on menu bar.
* **Multimedia capable** – App fully supports high-resolution images as well as texts up to 20000 chars.
* **Burner mode** – Lets the user switch between JarvisClipThat and standard MacOS clipboard mode.
* **Global shortcut** – You can call the clipboard anytime by using `Shift + Option + V` shortcut.

---

## Project structure

The project is built in standard Swift app architecture with one ContentView and App file as entry:

```sh
└── JarvisClipThat/
    ├── JarvisClipThatApp.swift   # Livecycle and menu bar
    └── ContentView.swift         # Clipboard manager and UI
```

## Environmental requirement
* Operating system: macOS 11+ (Big Sur)
* For development: Xcode 16.0+

*App is compatible with Apple Sillicon Macs as well as Intel Macs*

## Privacy and security
The app stores data exclusively in RAM, no data is sent outside:
* It does not send history through cloud (yet).
* It does not store history on hard drive or any temporary files.
* App allows to clear the history entirely by one button.
