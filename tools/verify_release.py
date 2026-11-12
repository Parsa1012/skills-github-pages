#!/usr/bin/env python3
"""Fail closed on unexpected release APK manifest or signer (Android build tools required)."""
import hashlib
import os
import re
import subprocess
import sys
from zipfile import ZipFile

if len(sys.argv) != 4:
    raise SystemExit('usage: verify_release.py <aapt> <apksigner> <release.apk>')
aapt, signer, apk = sys.argv[1:]
def run(*args):
    return subprocess.run(args, check=True, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT).stdout

signatures = run(signer, 'verify', '--verbose', '--print-certs', apk)
print(signatures)
expected = os.environ.get('MIRROR_CERT_SHA256', '').replace(':', '').lower()
compromised = '09228d155ddceb4fbe9897406cf4576db9dfe0a449f4ef391c1aeaaf1227664c'
if not re.fullmatch(r'[0-9a-f]{64}', expected) or expected == compromised:
    raise SystemExit('missing, invalid, or compromised expected certificate fingerprint')
digests = re.findall(r'certificate SHA-256 digest:\s*([0-9a-fA-F:]+)', signatures)
if ('Verified using v1 scheme (JAR signing): true' not in signatures or
        'Verified using v2 scheme (APK Signature Scheme v2): true' not in signatures or
        'Verified using v3 scheme (APK Signature Scheme v3): true' not in signatures or
        'Number of signers: 1' not in signatures or
        len(digests) != 1 or digests[0].replace(':', '').lower() != expected):
    raise SystemExit('release signature/certificate policy failed')
xml = run(aapt, 'dump', 'xmltree', apk, 'AndroidManifest.xml')
badging = run(aapt, 'dump', 'badging', apk)
print(badging)
if len(re.findall(r'E: activity\b', xml)) != 1:
    raise SystemExit('unexpected activity count')
if re.search(r'E: (uses-permission(?:-sdk-\d+)?|service|receiver|provider)\b', xml):
    raise SystemExit('unexpected permission or background/exported component')
for attribute in ('allowBackup', 'usesCleartextTraffic'):
    if not re.search(r'A: android:' + attribute + r'\([^)]*\)=\(type 0x12\)0x0\b', xml):
        raise SystemExit('expected explicit false: ' + attribute)
if re.search(r'A: android:debuggable\([^)]*\)=\(type 0x12\)0x(?:ffffffff|1)\b', xml):
    raise SystemExit('release is debuggable')
for expected_field in ("package: name='io.github.parsa1012.mirrordash'", "sdkVersion:'21'", "targetSdkVersion:'36'"):
    if expected_field not in badging:
        raise SystemExit('missing manifest invariant: ' + expected_field)
with ZipFile(apk) as archive:
    names = archive.namelist()
    if any(n.endswith('.so') for n in names):
        raise SystemExit('unexpected native binary')
    audio = sum(1 for n in names if n.endswith('.mp3'))
    if audio != 5:
        raise SystemExit('expected five bundled mp3 resources')
with open(apk, 'rb') as file:
    print('APK SHA-256:', hashlib.file_digest(file, 'sha256').hexdigest())
print('Release policy checks passed (verification is not a malware guarantee).')
