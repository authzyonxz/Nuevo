import re
import sys

project_path = 'ThreeOneOSFive.xcodeproj/project.pbxproj'

with open(project_path, 'r') as f:
    content = f.read()

# New IDs
license_file_ref = '3105L001'
license_build_file = '3105L002'
login_file_ref = '3105L003'
login_build_file = '3105L004'

# 1. Add to PBXBuildFile section
build_file_entry = f'\t\t{license_build_file} /* LicenseService.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {license_file_ref}; }};\n'
build_file_entry += f'\t\t{login_build_file} /* LoginView.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {login_file_ref}; }};\n'

if '/* End PBXBuildFile section */' in content:
    content = content.replace('/* End PBXBuildFile section */', build_file_entry + '/* End PBXBuildFile section */')

# 2. Add to PBXFileReference section
file_ref_entry = f'\t\t{license_file_ref} /* LicenseService.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = LicenseService.swift; sourceTree = "<group>"; }};\n'
file_ref_entry += f'\t\t{login_file_ref} /* LoginView.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = LoginView.swift; sourceTree = "<group>"; }};\n'

if '/* End PBXFileReference section */' in content:
    content = content.replace('/* End PBXFileReference section */', file_ref_entry + '/* End PBXFileReference section */')

# 3. Add to Groups
# Helpers Group (3105A405)
helpers_group_pattern = r'(3105A405 /\* helpers \*/ = \{[^{]*isa = PBXGroup;[^{]*children = \()'
content = re.sub(helpers_group_pattern, rf'\1\n\t\t\t\t\t{license_file_ref} /* LicenseService.swift */,', content)

# Views Group (3105A404)
views_group_pattern = r'(3105A404 /\* views \*/ = \{[^{]*isa = PBXGroup;[^{]*children = \()'
content = re.sub(views_group_pattern, rf'\1\n\t\t\t\t\t{login_file_ref} /* LoginView.swift */,', content)

# 4. Add to PBXSourcesBuildPhase (3105A700)
sources_phase_pattern = r'(3105A700 /\* Sources \*/ = \{[^{]*isa = PBXSourcesBuildPhase;[^{]*files = \()'
content = re.sub(sources_phase_pattern, rf'\1\n\t\t\t\t\t{license_build_file} /* LicenseService.swift in Sources */,\n\t\t\t\t\t{login_build_file} /* LoginView.swift in Sources */,', content)

with open(project_path, 'w') as f:
    f.write(content)

print("Project updated successfully.")
