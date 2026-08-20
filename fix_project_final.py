import sys

path = 'ThreeOneOSFive.xcodeproj/project.pbxproj'
with open(path, 'r') as f:
    content = f.read()

# Renomear Target e Produto
content = content.replace('PRODUCT_NAME = "IPA FF";', 'PRODUCT_NAME = MenagerFF;')
content = content.replace('INFOPLIST_KEY_CFBundleDisplayName = "IPA FF";', 'INFOPLIST_KEY_CFBundleDisplayName = MenagerFF;')
content = content.replace('PBXNativeTarget "3105"', 'PBXNativeTarget "MenagerFF"')
content = content.replace('path = "3105.app";', 'path = MenagerFF.app;')
content = content.replace('name = 3105;', 'name = MenagerFF;')

with open(path, 'w') as f:
    f.write(content)
print("Project pbxproj fixed with MenagerFF naming.")
