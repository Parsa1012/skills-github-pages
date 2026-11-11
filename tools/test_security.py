#!/usr/bin/env python3
"""Static regression checks, not a replacement for dynamic analysis or security review."""
import xml.etree.ElementTree as ET
from pathlib import Path

ns = '{http://schemas.android.com/apk/res/android}'
root = ET.parse('mirror/src/main/AndroidManifest.xml').getroot()
assert not root.findall('uses-permission'), 'game must not request Android permissions'
app = root.find('application')
assert app.get(ns+'allowBackup') == 'false'
assert app.get(ns+'fullBackupContent') == 'false'
assert app.get(ns+'usesCleartextTraffic') == 'false'
assert app.get(ns+'dataExtractionRules') == '@xml/data_extraction_rules'
assert len(app.findall('activity')) == 1
assert app.find('activity').get(ns+'exported') == 'true', 'launcher must remain launchable'
assert not any(app.findall(name) for name in ('service','receiver','provider'))
rules = ET.parse('mirror/src/main/res/xml/data_extraction_rules.xml').getroot()
for mode in ('cloud-backup','device-transfer'):
    exclusions = {(e.get('domain'), e.get('path')) for e in rules.find(mode).findall('exclude')}
    assert all((domain,'.') in exclusions for domain in ('root','file','database','sharedpref','external'))
files = Path('mirror/src/main/java').rglob('*.java')
for file in files:
    text = file.read_text()
    for token in ('java.net.', 'android.webkit.', 'DexClassLoader', 'Runtime.getRuntime()', 'ProcessBuilder', 'getExternalFilesDir('):
        assert token not in text, f'{file}: investigate {token}'
activity = Path('mirror/src/main/java/io/github/parsa1012/mirrordash/GameActivity.java').read_text()
assert 'music.setForeground(false)' in activity and 'gameView.stop()' in activity
print('Static manifest, backup, networking and lifecycle checks PASS (not a full dynamic audit)')
