import os
import re
import shutil

pattern = re.compile(r'[A-Za-z0-9]+\s*=\s*Includes\.Include\(\s*"([^"]*)"\s*\)')
ending_pattern = re.compile(r'return\s+([A-Za-z0-9]+)')

included_filenames = set()

for root, dirs, files in os.walk("."):
    for filename in files:
        if filename.endswith(".lua"):
            full_path = os.path.join(root, filename)
            if ".vscode" in full_path:
                continue
            try:
                with open(full_path, "r", encoding="utf-8") as f:
                    text = f.read()
            except UnicodeDecodeError:
                with open(full_path, "r", errors="ignore") as f:
                    text = f.read()

            matches = pattern.finditer(text)
            for match in matches:
                file_name = match.group(1)
                included_filenames.add(file_name)

def replace_last_occurrence(text, old, new):
    pos = text.rfind(old)
    if pos != -1:
        return text[:pos] + new + text[pos + len(old):]
    return text

for root, dirs, files in os.walk("."):
    for filename in files:
        for target_filename in included_filenames:
            if filename == target_filename:
                lib_name = target_filename[:-4]
                full_path = os.path.abspath(os.path.join(root, filename))
                if ".vscode" in full_path:
                    continue
                print(f"Generating file for{lib_name}")
                dest_path = ".vscode/lua/gorebox/libraries"
                patched_lib = ""
                with open(full_path, "r", errors="ignore") as f:
                    text = f.read().lstrip()
                    ending = text.rstrip().split("\n")[-1]
                    if ending_pattern.match(ending) == None:
                        continue
                    text = replace_last_occurrence(text, ending, "")
                    text = f"---@class {lib_name}\n{text}"
                    text = text.replace("local ", "", count=1)
                    patched_lib = text
                    
                os.makedirs(dest_path, exist_ok=True)
                copied = shutil.copy(full_path, dest_path)
                copied_renamed = copied.replace(".lua", ".d.lua")
                if os.path.exists(copied_renamed):
                    os.remove(copied_renamed)
                os.rename(copied, copied_renamed)

                with open(f"{dest_path}/{lib_name}.d.lua", "w", errors="ignore") as f:
                    f.write(patched_lib)

print("✅ Libraries Lua global definitions generated successfully!")
