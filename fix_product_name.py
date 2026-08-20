import sys

path = 'ThreeOneOSFive.xcodeproj/project.pbxproj'
with open(path, 'r') as f:
    content = f.read()

# Renomear apenas o nome do produto final que vai dentro da IPA
content = content.replace('PRODUCT_NAME = "IPA FF";', 'PRODUCT_NAME = MenagerFF;')
content = content.replace('INFOPLIST_KEY_CFBundleDisplayName = "IPA FF";', 'INFOPLIST_KEY_CFBundleDisplayName = MenagerFF;')

with open(path, 'w') as f:
    f.write(content)
print("Product name fixed in pbxproj.")
