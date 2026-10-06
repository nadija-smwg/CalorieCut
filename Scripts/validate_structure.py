#!/usr/bin/env python3
"""Dependency-free checks for the checked-in project, resources, and scheme."""
from pathlib import Path
import json
import plistlib
import re
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
project = root / 'CalorieCut.xcodeproj/project.pbxproj'
text = project.read_text()
errors = []
source_files = sorted(root.rglob('*.swift'))
source_files = [p for p in source_files if '.build' not in p.parts and p.name != 'Package.swift']
for path in source_files:
    target = path.relative_to(root).parts[0]
    relative = str(path.relative_to(root / target))
    if f'path = "{relative}";' not in text:
        errors.append(f'Missing project source reference: {path}')
for match in re.finditer(r'isa = PBXBuildFile; fileRef = ([A-F0-9]{24});', text):
    if not re.search(r'^\s*' + match.group(1) + r' = \{isa = PBXFileReference;', text, re.M):
        errors.append(f'Invalid build file reference: {match.group(1)}')
for path in root.rglob('*.plist'):
    plistlib.loads(path.read_bytes())
plistlib.loads((root / 'CalorieCut/Resources/PrivacyInfo.xcprivacy').read_bytes())
for path in (root / 'CalorieCut/Resources/Assets.xcassets').rglob('Contents.json'):
    data = json.loads(path.read_text())
    for image in data.get('images', []):
        if not (path.parent / image['filename']).is_file():
            errors.append(f'Missing asset: {image["filename"]}')
scheme = ET.parse(root / 'CalorieCut.xcodeproj/xcshareddata/xcschemes/CalorieCut.xcscheme')
for ref in scheme.findall('.//BuildableReference'):
    identifier = ref.attrib['BlueprintIdentifier']
    if not re.search(r'^\s*' + identifier + r' = \{isa = PBXNativeTarget;', text, re.M):
        errors.append(f'Invalid scheme target: {identifier}')
app_sources = list((root / 'CalorieCut').rglob('*.swift'))
for path in app_sources:
    content = path.read_text()
    if re.search(r'\b(TODO|FIXME|fatalError|try!)\b', content):
        errors.append(f'Unfinished/unsafe core placeholder: {path}')
    if any(token in content for token in ('URLSession', 'import Firebase', 'import Supabase', 'CloudKitDatabase.automatic')):
        errors.append(f'Unexpected network/database dependency: {path}')
print(f'Checked {len(source_files)} Swift sources, project references, scheme, plists, and assets.')
if errors:
    print('\n'.join(errors))
    raise SystemExit(1)
print('Structural checks passed. These checks do not replace an Xcode build.')
