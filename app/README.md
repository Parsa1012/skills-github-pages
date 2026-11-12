# Demo APK

A minimal Android app with **no third-party dependencies** (framework only), used to verify that
we can produce an installable `.apk` from this repository.

## What the app does

- Shows a large tap counter, a **Tap me** button and a **Reset** button.
- Prints a few device facts (Android version, API level, manufacturer/model, app version).
- Written in plain Java with a programmatic UI, so there are no XML layouts or AndroidX libraries.

## Where the APK comes from

`.github/workflows/build-apk.yml` builds the app on GitHub's runners
(`ubuntu-24.04`, JDK 17, Gradle 8.7, AGP 8.5.2, compileSdk 34, minSdk 21) and then:

1. uploads the APK as the `demo-app-debug-apk` workflow artifact, and
2. commits it to the branch as [`dist/demo-app-debug.apk`](../dist/demo-app-debug.apk)
   (`[skip ci]`, so it does not loop).

A debug APK is signed with the standard Android debug key, so it installs on most devices
as long as "install unknown apps" is allowed.

## Install

```bash
adb install -r dist/demo-app-debug.apk
```

Or copy the file to the phone and open it from the file manager.

## Rebuild locally

Requires JDK 17 and the Android SDK (platform 34, build-tools 34.0.0):

```bash
gradle assembleDebug
# output: app/build/outputs/apk/debug/app-debug.apk
```
