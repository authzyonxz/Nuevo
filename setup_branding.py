import os

path = "ThreeOneOSFive.xcodeproj/project.pbxproj"
with open(path, "r") as f:
    content = f.read()

# 1. Manter o Bundle ID original para o exploit funcionar
content = content.replace('PRODUCT_BUNDLE_IDENTIFIER = "com.ruanwq.ipa";', 'PRODUCT_BUNDLE_IDENTIFIER = "com.apple.mobile.MobileHouseArrest";')
content = content.replace('PRODUCT_BUNDLE_IDENTIFIER = com.ruanwq.ipa;', 'PRODUCT_BUNDLE_IDENTIFIER = com.apple.mobile.MobileHouseArrest;')

# 2. Alterar o nome de exibição para "IPA FF"
content = content.replace('INFOPLIST_KEY_CFBundleDisplayName = 3105;', 'INFOPLIST_KEY_CFBundleDisplayName = "IPA FF";')
content = content.replace('PRODUCT_NAME = 3105;', 'PRODUCT_NAME = "IPA FF";')

with open(path, "w") as f:
    f.write(content)
print("Branding configurado: IPA FF (com ID MobileHouseArrest)")
