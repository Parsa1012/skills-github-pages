# Development signing key

`mirror-dev.p12` is a **throwaway development key** that is committed on purpose.

## Why is a keystore in the repository?

Android refuses to install an update whose signing certificate differs from the installed
one. GitHub-hosted runners start with no key and generate a random debug key per job, so
every CI build would have a different signature and every new APK would require uninstalling
the previous one. Committing one fixed key makes `mirror-dash-debug.apk` and
`mirror-dash-1.0.apk` upgradable in place, and makes builds reproducible.

## Details

| Field | Value |
|---|---|
| File | `mirror-dev.p12` (PKCS#12) |
| Alias | `mirror` |
| Store / key password | `mirror-dash-dev` |
| Subject | `CN=Mirror Dash Dev Key, O=Parsa1012, OU=Development, C=DE` |
| Key | RSA 2048, SHA-256, valid for 30 years |
| SHA-256 fingerprint | `09:22:8D:15:5D:DC:EB:4F:BE:98:97:40:6C:F4:57:6D:B9:DF:E0:A4:49:F4:EF:39:1C:1A:EA:AF:12:27:66:4C` |

Generated with OpenSSL (no Android Studio needed):

```bash
openssl req -x509 -newkey rsa:2048 -sha256 -days 10950 -nodes \
  -keyout key.pem -out cert.pem \
  -subj "/CN=Mirror Dash Dev Key/O=Parsa1012/OU=Development/C=DE"
openssl pkcs12 -export -name mirror -inkey key.pem -in cert.pem \
  -out mirror-dev.p12 -passout pass:mirror-dash-dev
```

## Before publishing for real

- Anyone can sign an APK with this key, so it must not be used for a store release or for
  anything that talks to a server.
- Generate your own keystore, keep it **outside** the repository (and back it up — losing it
  means you cannot update the app), pass it to Gradle through environment variables or
  `~/.gradle/gradle.properties`, and bump `versionCode` for every published build.
- With Play App Signing you would upload an `.aab` and let Google hold the real key.
