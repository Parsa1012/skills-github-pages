#!/usr/bin/env python3
"""Exercise fail-closed APK policy against mocked build tools, not a real signature."""
import os
import pathlib
import subprocess
import sys
import tempfile
import zipfile

with tempfile.TemporaryDirectory() as tmp:
    tmp = pathlib.Path(tmp)
    apk = tmp / 'fixture.apk'
    with zipfile.ZipFile(apk, 'w') as z:
        for i in range(5):
            z.writestr(f'res/{i}.mp3', b'test')
    aapt = tmp / 'aapt'
    signer = tmp / 'signer'
    base = '''E: manifest
  E: application
    E: activity
    A: android:allowBackup(0x01010280)=(type 0x12)0x0
    A: android:usesCleartextTraffic(0x010104ec)=(type 0x12)0x0
'''
    badging = "package: name='io.github.parsa1012.mirrordash'\nsdkVersion:'21'\ntargetSdkVersion:'36'\n"
    sig = '''Verified using v1 scheme (JAR signing): true
Verified using v2 scheme (APK Signature Scheme v2): true
Verified using v3 scheme (APK Signature Scheme v3): true
Number of signers: 1
Signer #1 certificate SHA-256 digest: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
'''
    def script(path, text):
        path.write_text('#!/bin/sh\n' + text)
        path.chmod(0o700)
    def run(xml, signature=sig):
        # Fixed strings are test fixtures under our control, not executable user input.
        script(aapt, "if [ \"$2\" = 'badging' ]; then cat <<'END'\n" + badging + "END\nelse cat <<'END'\n" + xml + "END\nfi\n")
        script(signer, "cat <<'END'\n" + signature + "END\n")
        return subprocess.run([sys.executable, 'tools/verify_release.py', str(aapt), str(signer), str(apk)], capture_output=True, env={**os.environ, 'MIRROR_CERT_SHA256': 'a' * 64}).returncode
    assert run(base) == 0
    assert run(base, sig.replace('a' * 64, '09228d155ddceb4fbe9897406cf4576db9dfe0a449f4ef391c1aeaaf1227664c')) != 0
    assert run(base + '  E: uses-permission\n') != 0
    assert run(base.replace('0x0\n', '0xffffffff\n', 1)) != 0
    assert run(base + '    A: android:debuggable(0x0101000f)=(type 0x12)0xffffffff\n') != 0
    assert run(base, sig.replace('v2 scheme (APK Signature Scheme v2): true', 'v2 scheme (APK Signature Scheme v2): false')) != 0
print('Release policy fixture tests passed')
