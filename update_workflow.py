import sys

with open('LuminaPro/.github/workflows/ios-build.yml', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
skip = False
for line in lines:
    if 'cat << \'SWIFT_EOF\'' in line:
        skip = True
        new_lines.append('          cp ios_template/AppDelegate.swift ios/Runner/AppDelegate.swift\n')
        continue
    if skip and 'SWIFT_EOF' in line:
        skip = False
        continue
    if not skip:
        new_lines.append(line)

with open('LuminaPro/.github/workflows/ios-build.yml', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print("Updated ios-build.yml")
