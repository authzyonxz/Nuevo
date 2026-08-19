import os

path = "ThreeOneOSFive.xcodeproj/project.pbxproj"
with open(path, "r") as f:
    content = f.read()

# Alterar o Bundle ID para o original que o exploit espera
content = content.replace('PRODUCT_BUNDLE_IDENTIFIER = "com.ruanwq.ipa";', 'PRODUCT_BUNDLE_IDENTIFIER = "com.apple.mobile.MobileHouseArrest";')
content = content.replace('PRODUCT_BUNDLE_IDENTIFIER = com.ruanwq.ipa;', 'PRODUCT_BUNDLE_IDENTIFIER = com.apple.mobile.MobileHouseArrest;')

with open(path, "w") as f:
    f.write(content)
print("Bundle ID alterado para com.apple.mobile.MobileHouseArrest")
