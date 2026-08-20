import sys

path = 'ThreeOneOSFive.xcodeproj/project.pbxproj'
with open(path, 'r') as f:
    content = f.read()

# 1. Renomear o nome do Target de 'MenagerFF' para '3105' (para manter o esquema original funcionando)
# ou garantir que o esquema aponte para o target correto.
# O erro diz que não tem esquema '3105'. O esquema geralmente tem o mesmo nome do target.

# Vamos forçar o nome do target e do produto para MenagerFF em todos os lugares.
content = content.replace('name = MenagerFF;', 'name = MenagerFF;') # Já está assim
content = content.replace('productName = 3105;', 'productName = MenagerFF;')
content = content.replace('path = MenagerFF.app;', 'path = MenagerFF.app;') # Já está assim

# O problema é que o Xcode Shared Data (esquema) não existe no repo.
# O xcodebuild cria um esquema padrão com o nome do TARGET se não houver um.
# Se o target se chama 'MenagerFF', o esquema deve ser 'MenagerFF'.

with open(path, 'w') as f:
    f.write(content)
print("Naming fixed in pbxproj.")
