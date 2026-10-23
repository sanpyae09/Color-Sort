#!/usr/bin/env python3
"""Patch the CI-generated Flutter android scaffold for SecureNet:
- applicationId -> com.pyaystudios.securenet
- minSdk -> 24
- packaging.jniLibs.useLegacyPackaging = true  (openvpn_flutter 2.x REQUIRES it,
  otherwise the OpenVPN engine cannot extract its native libs and exits)
- JitPack repository guard (openvpn_flutter downloads its engine from JitPack)
- AndroidManifest: EnableImpeller=false (Mali/HiOS first-frame hang fix),
  INTERNET + ACCESS_NETWORK_STATE + POST_NOTIFICATIONS permissions
"""
import re
import sys
from pathlib import Path

APP_ID = "com.pyaystudios.securenet"

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
    if "useLegacyPackaging" not in text:
        anchor = re.search(r"(?m)^android\s*\{", text)
        if anchor:
            insert = (
                "\n    packaging {\n"
                "        jniLibs {\n"
                "            useLegacyPackaging = true\n"
                "        }\n"
                "    }"
            )
            text = text[: anchor.end()] + insert + text[anchor.end():]
            print("gradle: jniLibs useLegacyPackaging added (kts)")
        else:
            print("WARNING: no android { block found for packaging insert")
else:
    text, n1 = re.subn(r'applicationId\s+"[^"]*"', f'applicationId "{APP_ID}"', text, count=1)
    text, n2 = re.subn(r"minSdkVersion\s+flutter\.minSdkVersion", "minSdkVersion 24", text, count=1)
    if n2 == 0:
        text, n2 = re.subn(r"minSdkVersion\s+\d+", "minSdkVersion 24", text, count=1)
    if "useLegacyPackaging" not in text:
        anchor = re.search(r"(?m)^android\s*\{", text)
        if anchor:
            insert = (
                "\n    packaging {\n"
                "        jniLibs {\n"
                "            useLegacyPackaging true\n"
                "        }\n"
                "    }"
            )
            text = text[: anchor.end()] + insert + text[anchor.end():]
            print("gradle: jniLibs useLegacyPackaging added (groovy)")
        else:
            print("WARNING: no android { block found for packaging insert")
gradle.write_text(text)
print(f"gradle patched: applicationId replacements={n1}, minSdk replacements={n2}")

# JitPack guard: if settings.gradle(.kts) pins repositories with
# dependencyResolutionManagement, make sure https://jitpack.io is in there.
for sname in ("android/settings.gradle", "android/settings.gradle.kts"):
    sp = Path(sname)
    if not sp.exists():
        continue
    s = sp.read_text()
    if "jitpack" in s:
        print(f"{sname}: jitpack already present")
        continue
    if "dependencyResolutionManagement" in s:
        jit = '\n        maven { url = uri("https://jitpack.io") }'
        # insert right after the first "repositories {" that follows dependencyResolutionManagement
        idx = s.find("dependencyResolutionManagement")
        ridx = s.find("repositories", idx)
        if ridx != -1:
            brace = s.find("{", ridx)
            s = s[: brace + 1] + jit + s[brace + 1:]
            sp.write_text(s)
            print(f"{sname}: jitpack repo inserted into dependencyResolutionManagement")
        else:
            print(f"WARNING: {sname} has dependencyResolutionManagement but no repositories block found")
    else:
        print(f"{sname}: no dependencyResolutionManagement; plugin adds its own repo")

manifest = Path("android/app/src/main/AndroidManifest.xml")
m = manifest.read_text()

# Permissions (before <application ...>)
perms = ""
for perm in (
    "android.permission.INTERNET",
    "android.permission.ACCESS_NETWORK_STATE",
    "android.permission.POST_NOTIFICATIONS",
):
    if perm not in m:
        perms += f'    <uses-permission android:name="{perm}"/>\n'
if perms:
    # uses-permission elements belong INSIDE <manifest>, before <application>.
    # (Never prepend them to the file: anything before the <?xml?> declaration
    # makes the document invalid and flutter build fails parsing the manifest.)
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
else:
    print("manifest: meta-data already present")

# Final guard: the patched manifest MUST be well-formed XML — fail the CI step
# loudly here instead of letting flutter build die with a vague parse error.
import xml.etree.ElementTree as ET

try:
    ET.fromstring(m)
except ET.ParseError as e:
    sys.exit(f"AndroidManifest.xml is not valid XML after patching: {e}")
manifest.write_text(m)
print("manifest: XML validated")
