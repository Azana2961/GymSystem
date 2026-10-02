import os
import re

lib_dir = r'd:\GYMSYSTEM\lib'

def fix_imports():
    for root, dirs, files in os.walk(lib_dir):
        for file in files:
            if not file.endswith('.dart'): continue
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            def replacer(match):
                rel_path = match.group(1)
                abs_path = os.path.normpath(os.path.join(root, rel_path))
                rel_to_lib = os.path.relpath(abs_path, lib_dir)
                pkg_path = rel_to_lib.replace(os.sep, '/')
                return f"import 'package:gym_system/{pkg_path}';"
                
            new_content = re.sub(r"import\s+'((?:\.\./|core|features)[^']+)'\s*;", replacer, content)
            
            if new_content != content:
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(new_content)
                print(f'Fixed {filepath}')

fix_imports()
