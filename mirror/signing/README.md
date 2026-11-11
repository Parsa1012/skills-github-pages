# Release signing

The historical development key has been compromised. It must never be used to sign new releases. Removing it from the current tree does not erase the key from Git history or other copies.

A new PKCS#12 keystore must be generated and backed up securely outside the repository by the owner. Set the GitHub Actions secrets `MIRROR_KEYSTORE_BASE64`, `MIRROR_STORE_PASSWORD`, `MIRROR_KEY_ALIAS`, and `MIRROR_KEY_PASSWORD`; set the repository variable `MIRROR_CERT_SHA256` to the expected SHA-256 fingerprint of the new public certificate. Restrict who can edit workflows, branches, secrets, and actions, and use protected deployment environments where appropriate. Never paste private keys or passwords into chat or commit them. Back up the keystore and credentials separately and securely; losing them can prevent updates.

The manual workflow requires these values, rejects the known compromised certificate, signs v1/v2/v3, and verifies the APK before uploading an Actions artifact. Fingerprints identify a certificate but do not by themselves establish trust in a compromised build environment. This pipeline has not yet been tested with real credentials.

The published 1.8 APK used the old key. A newly signed APK with the same application ID will not normally install over it. Uninstalling can erase local scores and settings. Signature rotation/lineage has Android-version and distribution constraints and cannot restore trust in a compromised old signer. Decide on migration before issuing a new key or distributing a replacement.
