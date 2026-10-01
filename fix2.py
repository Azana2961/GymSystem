import os
import re

lib_dir = r'd:\GYMSYSTEM\lib'

for root, dirs, files in os.walk(lib_dir):
    for file in files:
        if not file.endswith('.dart'): continue
        filepath = os.path.join(root, file)
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        content = re.sub(r"package:gym_system/.*?core/theme/colors.dart", r"package:gym_system/core/theme/colors.dart", content)
        content = re.sub(r"package:gym_system/.*?core/theme/app_theme.dart", r"package:gym_system/core/theme/app_theme.dart", content)
        content = re.sub(r"package:gym_system/.*?core/constants/dummy_data.dart", r"package:gym_system/core/constants/dummy_data.dart", content)
        content = re.sub(r"package:gym_system/.*?models/member_model.dart", r"package:gym_system/features/members/models/member_model.dart", content)
        content = re.sub(r"package:gym_system/.*?models/trainer_model.dart", r"package:gym_system/features/trainers/models/trainer_model.dart", content)
        content = re.sub(r"package:gym_system/.*?models/attendance_model.dart", r"package:gym_system/features/dashboard/models/attendance_model.dart", content)
        
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)

test_file = r'd:\GYMSYSTEM\test\widget_test.dart'
if os.path.exists(test_file):
    with open(test_file, 'r', encoding='utf-8') as f:
        content = f.read()
    content = content.replace('MyApp()', 'GymSystemApp()')
    with open(test_file, 'w', encoding='utf-8') as f:
        f.write(content)
