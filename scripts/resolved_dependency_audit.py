#!/usr/bin/env python3
"""Validate the versions resolved by `flutter pub get` before any build."""
from pathlib import Path
import re
import sys

lock = Path('pubspec.lock')
if not lock.is_file():
    raise SystemExit('DEPENDENCY AUDIT FAILED: pubspec.lock not found; run flutter pub get first')
text = lock.read_text(encoding='utf-8')


def version(name: str) -> str:
    m = re.search(
        rf'^  {re.escape(name)}:\n(?:.*\n)*?    version: "([^"]+)"',
        text,
        re.MULTILINE,
    )
    if not m:
        raise SystemExit(f'DEPENDENCY AUDIT FAILED: {name} missing from pubspec.lock')
    return m.group(1)

expected_exact = {
    'permission_handler': '12.0.3',
    'google_mlkit_translation': '0.15.1',
    'whisper_kit': '0.3.1',
    'path_provider': '2.1.5',
}
for package, expected in expected_exact.items():
    actual = version(package)
    if actual != expected:
        raise SystemExit(
            f'DEPENDENCY AUDIT FAILED: expected {package} {expected}, got {actual}'
        )
    print(f'{package}={actual}')

android_handler = version('permission_handler_android')
if not android_handler.startswith('13.'):
    raise SystemExit(
        'DEPENDENCY AUDIT FAILED: permission_handler_android must remain 13.x '
        f'for the API-36 build; got {android_handler}'
    )
print(f'permission_handler_android={android_handler}')
print('DEPENDENCY AUDIT PASS')
