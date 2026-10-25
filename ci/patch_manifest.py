#!/usr/bin/env python3
"""Patch the CI-scaffolded AndroidManifest: disable Impeller (the engine
flag that hung QuizNova on this user's phone) and validate the XML afterwards.

Inserts the meta-data element INSIDE the <application> element — never before
the XML declaration (that exact mistake broke SecureNet run #15).
"""
import sys
import xml.etree.ElementTree as ET

PATH = "android/app/src/main/AndroidManifest.xml"
NS = "http://schemas.android.com/apk/res/android"
ET.register_namespace("android", NS)

tree = ET.parse(PATH)
root = tree.getroot()
app = root.find("application")
if app is None:
    sys.exit("no <application> element found")

key = "io.flutter.embedding.android.EnableImpeller"
for m in app.findall("meta-data"):
    if m.get(f"{{{NS}}}name") == key:
        print("Impeller meta-data already present")
        break
else:
    el = ET.SubElement(app, "meta-data")
    el.set(f"{{{NS}}}name", key)
    el.set(f"{{{NS}}}value", "false")
    print("added EnableImpeller=false")

tree.write(PATH, encoding="utf-8", xml_declaration=True)
# Re-parse as a validation guard: a corrupt manifest must fail here, not in Gradle.
ET.parse(PATH)
print("manifest OK")
