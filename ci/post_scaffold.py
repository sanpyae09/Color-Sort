#!/usr/bin/env python3
"""Patch the CI-generated Flutter android scaffold for QuizNova:
- applicationId -> com.pyaystudios.quiznova
- minSdk -> 24 (google_mobile_ads 9.x requirement)
- AdMob TEST application id meta-data in AndroidManifest.xml
"""
import re
import sys
from pathlib import Path

APP_ID = "com.pyaystudios.quiznova"
ADS_APP_ID = "ca-app-pub-3940256099942544~3347511713"  # Google official TEST app id

gradle_files = [Path("android/app/build.gradle"), Path("android/app/build.gradle.kts")]
gradle = next((p for p in gradle_files if p.exists()), None)
if gradle is None:
    sys.exit("android/app/build.gradle(.kts) not found")

is_kts = gradle.suffix == ".kts"
text = gradle.read_text()
if is_kts:
    text, n1 = re.subn(r'applicationId\s*=\s*"[^"]*"', f'applicationId = "{APP_ID}"', text, count=1)
    text, n2 = re.subn(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 24", text, count=1)
    if n2 == 0:
        text, n2 = re.subn(r"minSdk\s*=\s*\d+", "minSdk = 24", text, count=1)
else:
    text, n1 = re.subn(r'applicationId\s+"[^"]*"', f'applicationId "{APP_ID}"', text, count=1)
    text, n2 = re.subn(r"minSdkVersion\s+flutter\.minSdkVersion", "minSdkVersion 24", text, count=1)
    if n2 == 0:
        text, n2 = re.subn(r"minSdkVersion\s+\d+", "minSdkVersion 24", text, count=1)
gradle.write_text(text)
print(f"gradle patched: applicationId replacements={n1}, minSdk replacements={n2}")

manifest = Path("android/app/src/main/AndroidManifest.xml")
m = manifest.read_text()
if "com.google.android.gms.ads.APPLICATION_ID" not in m:
    meta = f'        <meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="{ADS_APP_ID}"/>\n    </application>'
    if "</application>" not in m:
        sys.exit("AndroidManifest.xml has no </application> tag")
    m = m.replace("</application>", meta, 1)
    manifest.write_text(m)
    print("manifest: AdMob test app id inserted")
else:
    print("manifest: ads meta-data already present")
