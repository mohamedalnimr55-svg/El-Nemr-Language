#!/usr/bin/env python3
from pathlib import Path
import json, plistlib, sys, xml.etree.ElementTree as ET
import yaml

root = Path(__file__).resolve().parents[1]
errors=[]

def check(name, fn):
    try: fn()
    except Exception as exc: errors.append(f'{name}: {exc}')

# Structured files.
for path in sorted((root/'.github/workflows').glob('*.yml')):
    check(str(path.relative_to(root)), lambda p=path: yaml.safe_load(p.read_text()))
for path in [root/'android/app/src/main/AndroidManifest.xml', *sorted((root/'android/app/src/main/res/xml').glob('*.xml'))]:
    check(str(path.relative_to(root)), lambda p=path: ET.parse(p))
check('ios/Runner/Info.plist', lambda: plistlib.loads((root/'ios/Runner/Info.plist').read_bytes()))
for path in sorted((root/'lib/l10n').glob('*.arb')):
    check(str(path.relative_to(root)), lambda p=path: json.loads(p.read_text()))

# Lightweight delimiter scanner for Dart/Kotlin. It ignores comments and
# quoted strings, so braces in regexes/UI copy do not create false failures.
def balanced(path: Path):
    text=path.read_text(errors='replace')
    pairs={')':'(',']':'[','}':'{'}; stack=[]
    i=0; quote=None; triple=False; raw_string=False; line_comment=False; block_comment=0
    while i < len(text):
        c=text[i]; n=text[i:i+2]
        if line_comment:
            if c=='\n': line_comment=False
            i+=1; continue
        if block_comment:
            if n=='/*': block_comment+=1; i+=2; continue
            if n=='*/': block_comment-=1; i+=2; continue
            i+=1; continue
        if quote:
            if triple:
                if text[i:i+3]==quote*3: quote=None; triple=False; raw_string=False; i+=3; continue
                if not raw_string and c=='\\': i+=2; continue
                i+=1; continue
            if not raw_string and c=='\\': i+=2; continue
            if c==quote: quote=None; raw_string=False
            i+=1; continue
        if n=='//': line_comment=True; i+=2; continue
        if n=='/*': block_comment=1; i+=2; continue
        if c in "'\"":
            raw_string = i > 0 and text[i-1] in ('r', 'R') and (i < 2 or not (text[i-2].isalnum() or text[i-2] == '_'))
            if text[i:i+3]==c*3: quote=c; triple=True; i+=3
            else: quote=c; i+=1
            continue
        if c in '([{': stack.append((c,i))
        elif c in ')]}':
            if not stack or stack[-1][0] != pairs[c]: raise ValueError(f'unmatched {c} at byte {i}')
            stack.pop()
        i+=1
    if quote: raise ValueError('unterminated string')
    if block_comment: raise ValueError('unterminated block comment')
    if stack: raise ValueError(f'unclosed delimiter {stack[-1][0]} at byte {stack[-1][1]}')

for base, ext in [(root/'lib','*.dart'),(root/'test','*.dart'),(root/'android/app/src/main/kotlin','*.kt')]:
    for path in sorted(base.rglob(ext)):
        check(str(path.relative_to(root)), lambda p=path: balanced(p))

if errors:
    print('STATIC VALIDATION FAILED')
    print('\n'.join(f'- {e}' for e in errors))
    sys.exit(1)
print('STATIC VALIDATION PASS')
