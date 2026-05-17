import sys

with open('LuminaPro/.github/workflows/ios-build.yml', 'r', encoding='utf-8') as f:
    lines = f.readlines()

start_idx = -1
end_idx = -1
for i, line in enumerate(lines):
    if 'cat << \'SWIFT_EOF\'' in line:
        start_idx = i + 1
    elif 'SWIFT_EOF' in line and start_idx != -1:
        end_idx = i
        break

if start_idx != -1 and end_idx != -1:
    swift_lines = lines[start_idx:end_idx]
    cleaned = [line[10:] if line.startswith('          ') else line for line in swift_lines]
    with open('LuminaPro/ios_template/Lumina_AppDelegate.swift', 'w', encoding='utf-8') as out:
        out.writelines(cleaned)
    print('Extracted Lumina_AppDelegate.swift')
else:
    print('Could not find SWIFT_EOF block')
