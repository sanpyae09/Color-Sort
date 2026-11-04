#!/usr/bin/env python3
"""Patch the CI-generated Flutter android scaffold for NUVESSA:
- applicationId -> com.pyaystudios.nuvessa
- minSdk -> 24
- AndroidManifest: EnableImpeller=false (Mali/HiOS first-frame hang fix,
  proven on QuizNova/SecureNet), plus permissions for screen-off
  media playback: INTERNET, ACCESS_NETWORK_STATE, POST_NOTIFICATIONS,
  RECORD_AUDIO (speaking practice), FOREGROUND_SERVICE and
  FOREGROUND_SERVICE_MEDIA_PLAYBACK (lock-screen media session).
Permissions are inserted INSIDE <manifest>, never before <?xml?>.
"""
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

APP_ID = "com.pyaystudios.nuvessa"

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
print(f"gradle patched: applicationId={n1}, minSdk={n2}")

manifest = Path("android/app/src/main/AndroidManifest.xml")
m = manifest.read_text()
perms = ""
for perm in (
    "android.permission.INTERNET",
    "android.permission.ACCESS_NETWORK_STATE",
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.RECORD_AUDIO",
    "android.permission.FOREGROUND_SERVICE",
    "android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK",
    "android.permission.WAKE_LOCK",
):
    if perm not in m:
        perms += f'    <uses-permission android:name="{perm}"/>\n'
if perms:
    mm = re.search(r"<manifest\b[^>]*>", m)
    if not mm:
        sys.exit("AndroidManifest.xml has no <manifest> tag")
    m = m[: mm.end()] + "\n" + perms + m[mm.end():]
    print("manifest: permissions inserted")
additions = ""
if "io.flutter.embedding.android.EnableImpeller" not in m:
    additions += '        <meta-data android:name="io.flutter.embedding.android.EnableImpeller" android:value="false"/>\n'
if additions:
    if "</application>" not in m:
        sys.exit("AndroidManifest.xml has no </application> tag")
    m = m.replace("</application>", additions + "    </application>", 1)
    print("manifest: meta-data inserted")
try:
    ET.fromstring(m)
except ET.ParseError as e:
    sys.exit(f"AndroidManifest.xml is not valid XML after patching: {e}")
manifest.write_text(m)
print("manifest: XML validated")
