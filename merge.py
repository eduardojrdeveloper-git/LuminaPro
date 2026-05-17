import re

with open('LuminaPro/SpotiFLAC-Mobile-main/ios/Runner/AppDelegate.swift', 'r', encoding='utf-8') as f:
    spoti_code = f.read()

with open('LuminaPro/ios_template/Lumina_AppDelegate.swift', 'r', encoding='utf-8') as f:
    lumina_code = f.read()

# 1. Imports
spoti_code = spoti_code.replace('import Flutter\nimport UIKit', 'import Flutter\nimport UIKit\nimport AVFoundation\nimport MediaPlayer\nimport Accelerate')

# 2. Extract Lumina Variables
lum_vars_match = re.search(r'class AppDelegate: FlutterAppDelegate \{\s*(var engine = AVAudioEngine\(\).*?var seekOffsetMs: Int = 0\n)', lumina_code, re.DOTALL)
if lum_vars_match:
    lum_vars = lum_vars_match.group(1)
    spoti_code = spoti_code.replace('class AppDelegate: FlutterAppDelegate {\n', 'class AppDelegate: FlutterAppDelegate {\n' + lum_vars + '\n')

# 3. Extract Lumina Setup
lum_setup_match = re.search(r'let controller = window\?\.rootViewController as! FlutterViewController\s*(methodChannel = FlutterMethodChannel\(name: "com\.luminapro/audio".*?self\.updateAudioPathInfo\(\)\n\s*\})\n\s*methodChannel\?\.setMethodCallHandler', lumina_code, re.DOTALL)
if lum_setup_match:
    lum_setup = lum_setup_match.group(1)
    # Also extract the method channel handler block
    lum_handler_match = re.search(r'(methodChannel\?\.setMethodCallHandler.*?\}\)\n)', lumina_code, re.DOTALL)
    lum_handler = lum_handler_match.group(1) if lum_handler_match else ""
    
    # Inject into Spoti's didFinishLaunchingWithOptions right after controller
    spoti_code = spoti_code.replace('let controller = window?.rootViewController as! FlutterViewController\n', 'let controller = window?.rootViewController as! FlutterViewController\n\n' + lum_setup + '\n\n' + lum_handler + '\n')

# 4. Extract Lumina Functions
lum_funcs_match = re.search(r'(func setupAudioEngine\(\) \{.*)\n\}\n\nclass PositionStreamHandler', lumina_code, re.DOTALL)
if lum_funcs_match:
    lum_funcs = lum_funcs_match.group(1)
    # Inject at the end of AppDelegate class
    # Find the last closing brace of AppDelegate
    spoti_code = spoti_code.replace('\n}\n\nprivate final class ClosureStreamHandler', '\n\n' + lum_funcs + '\n}\n\nprivate final class ClosureStreamHandler')

# 5. Extract Lumina Handlers
lum_handlers_match = re.search(r'(class PositionStreamHandler: NSObject, FlutterStreamHandler \{.*)\Z', lumina_code, re.DOTALL)
if lum_handlers_match:
    lum_handlers = lum_handlers_match.group(1)
    spoti_code += '\n' + lum_handlers

with open('LuminaPro/ios_template/AppDelegate.swift', 'w', encoding='utf-8') as f:
    f.write(spoti_code)

print("Merged AppDelegate.swift successfully.")
