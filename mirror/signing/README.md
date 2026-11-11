# Signing and distribution

## Public legacy key — TEST ONLY

`mirror-dev.p12` and its password are public. Anyone can sign as previous releases. An APK
signed with it is cryptographically signed but **does not establish developer authenticity**.
Removing this file from the current checkout would not make the key secret: it is in Git history
and older releases. Never use this key for a store release. The CI output labelled
`PUBLIC-TEST-KEY` is for compatibility testing only, not a trusted production release.

## New private signing key

Create a new keystore **outside** the repository using Android Studio or the Android/Java
`keytool`; protect and back it up. Do not paste keys or passwords into chat, commit them, or
publish them in artifacts. Configure these environment variables securely on your own build
machine (or protected CI environment):

- `MIRROR_KEYSTORE_PATH`: absolute path to your private keystore;
- `MIRROR_KEYSTORE_PASSWORD`: keystore password;
- `MIRROR_KEY_ALIAS`: private key alias;
- `MIRROR_KEY_PASSWORD`: key password.

With all four set, run `gradle :mirror:assembleRelease`. Missing or partially configured
credentials fail the release build; the known public certificate is rejected even if copied
to another path. Verify the produced APK with Android SDK `apksigner verify --verbose
--print-certs` and compare the certificate SHA-256 to the fingerprint recorded independently
by the owner. Never trust a fingerprint solely because it appears next to a downloaded APK.
For Google Play, use Play App Signing, a protected upload key, and the required AAB process.

A fresh private key **cannot install as an update** over any existing package signed with the
old public key. Plan a new application ID and safe user-data migration, or a controlled
uninstall/reinstall with loss of local progress. Do not claim an app is securely upgraded
while retaining an exposed signing identity. Key rotation from an already compromised key
requires a separate threat analysis and Android-version compatibility plan.

For local regression tests only, the old signer can be explicitly enabled with
`gradle :mirror:assembleRelease -PallowInsecureDevSigning=true`. The debug variant has a
separate application ID. Never store a real key in the checkout: ignore rules are only a
precaution, and do not remove keys already committed or prevent forced additions.
