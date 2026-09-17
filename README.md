<p align="center" style="padding-top:20px">
<img src="https://raw.githubusercontent.com/commetchat/.github/refs/heads/main/assets/banner.png">

<p align="center">
    <a href="https://commet.chat/donate"><img alt="Donate" src="https://img.shields.io/badge/donate-534cdd?style=for-the-badge"></a>
    <a href="https://commet.chat/install"><img alt="Download" src="https://img.shields.io/github/downloads/commetchat/commet/total?style=for-the-badge&color=534cdd"></a>
    <a href="https://matrix.to/#/#commet:matrix.org"><img alt="Matrix" src="https://img.shields.io/matrix/commet%3Amatrix.org?logo=matrix&style=for-the-badge&color=534cdd"></a>
    <a href="https://fosstodon.org/@commetchat"><img alt="Mastodon" src="https://img.shields.io/mastodon/follow/109894490854601533?domain=https%3A%2F%2Ffosstodon.org&style=for-the-badge&logo=mastodon&color=534cdd&logoColor=white"></a>
    <a href="https://bsky.app/profile/commet.chat"><img alt="Bluesky" src="https://img.shields.io/badge/follow-@commet.chat-whitesmoke?style=for-the-badge&logo=bluesky&logoColor=white&color=534cdd"></a>
</p>

> [!WARNING]
> ### Unofficial Performance-Optimized Fork
> This repository is a personal, unofficial fork of the official [Commet](https://github.com/commetchat/commet) Matrix client maintained by me.
>
> * **Why this fork exists:** I created this branch to immediately integrate and test performance optimizations, memory leak fixes, and UI responsiveness patches before they are officially merged into the upstream repository.
> * **Upstream Sync:** This fork will regularly merge official `commetchat/commet` changes so you stay up-to-date with mainstream protocol features.
> * **Automated Builds & App Signing:** Automated CI builds are regularly provided for **Android (APK)** and **Linux** in the Actions/Releases tab. These binaries are signed using my personal developer keystore. Therefore, if you already have the official Commet app installed on Android, you must uninstall it first before installing builds from this fork.
> 
> I will be slowly working my way through performance issues and writing up better documentation so please bear with me.

### Your space to connect
We are building a client for [Matrix](https://matrix.org) focused on providing a feature rich experience while maintaining a simple interface. The goal is to build a secure, privacy respecting app without compromising on the features you have come to expect from a modern chat client.


<p align="center" style="padding-top:20px">
<img src="https://raw.githubusercontent.com/commetchat/.github/main/assets/banner_demo.png">

# Features
- Supports **Windows**, **Linux**, and **Android** (MacOS and iOS planned in future)
- End to End Encryption
- Custom Emoji + Stickers
- GIF Search
- Threads
- Encrypted Room Search
- Multiple Accounts
- Spaces
- Emoji verification & cross signing
- Push Notifications
- URL Preview

# Translation
Help translate to your language on [Weblate](https://hosted.weblate.org/projects/commetchat/commet/)

<a href="https://hosted.weblate.org/engage/commetchat/">
<img src="https://hosted.weblate.org/widget/commetchat/commet/multi-auto.svg" alt="Translation status" />
</a>

# Development
To build, you require [Flutter](https://flutter.dev), currently v3.41.9 

This repo currently has a monorepo structure, containing two flutter projects: Commet and Tiamat. Commet is the main client, and Tiamat is a sort of wrapper around Material with some extra goodies, which is used to maintain a consistent style across the app. Tiamat may eventually be moved to its own repo, but for now it is maintained here for ease of development.
## Building

### 1. Install Flutter
* **Option A: Standard Flutter**
  [Install Flutter](https://docs.flutter.dev/get-started/install) manually and ensure you are on version `3.41.9`.

* **Option B: FVM (Flutter Version Management)**
  An `.fvmrc` file is included in the project root. If you use [FVM](https://fvm.app/), navigate to the project directory and run:
  ```bash
  fvm use
  ```
(Remember to prefix your build commands with fvm flutter ... when using FVM).

### 2. Install Libraries
Commet requires some additional libraries to be built 
```bash
sudo apt-get install -y cmake clang ninja-build rustup libgtk-3-dev libmpv-dev mpv ffmpeg libmimalloc-dev libwebkit2gtk-4.1-dev keybinder-3.0 libasound2-dev libheif-dev libexif-dev libwebp-dev
```

### 3. Fetch Dependencies
You will need to change directory in to the project, then fetch dependencies
```bash
cd commet
flutter pub get
```

### 4. Code Generation
We make use of procedural code generation in some parts of the project. As a rule, generated code will not be checked in to git, and will need to be generated before building.

To run code generation, run the script within the `commet` directory:
`dart run scripts/codegen.dart`

### 5. Building
When building, there are some additional command line arguments that must be used to configure the build.

**Required**
| **Argument** | **Valid Values**                                                          | **Description**                                                                                              |
|--------------|---------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------|
| PLATFORM    | 'desktop', 'mobile', 'linux', 'windows', 'macos', 'android', 'ios', 'web' | Defines which platform to build for                                                                          |
| BUILD_MODE   | 'release', 'debug'                                                        | When building with 'debug' flag, additional debug information will be shown                                  |

**Optional**
| **Argument** | **Valid Values**                                                          | **Description**                                                                                              |
|--------------|---------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------|
| GIT_HASH     | *                                                                         | Supply the current git hash when building to show in info screen                                             |
| VERSION_TAG  | *                                                                         | Supply the current build version, to display app version                                                     |
| BUILD_DETAIL | *                                                                         | Can provide additional detail about the current build, for example if it was being built for Flatpak or Snap |

**Example:**

```bash
cd commet
flutter run --dart-define BUILD_MODE=debug --dart-define PLATFORM=linux
```
