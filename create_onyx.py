import json
import struct
import hashlib
import sys
import os

def create_onyx(payload_path, output_name=None):
    if not os.path.exists(payload_path):
        print(f"Erro: Arquivo {payload_path} não encontrado.")
        return

    filename = os.path.basename(payload_path)
    with open(payload_path, "rb") as f:
        payload_data = f.read()

    # Calcular SHA256 do payload
    sha256 = hashlib.sha256(payload_data).hexdigest()
    
    # Criar metadados
    metadata = {
        "package_id": f"pkg_{hashlib.md5(filename.encode()).hexdigest()[:8]}",
        "payload_filename": filename,
        "allowed_games": ["com.dts.freefireth", "com.dts.freefiremax"],
        "payload_size": len(payload_data),
        "payload_sha256": sha256
    }
    
    json_data = json.dumps(metadata).encode('utf-8')
    json_len = len(json_data)
    
    # Pack: 4 bytes (Big Endian) length + JSON + Payload
    header = struct.pack(">I", json_len)
    
    if not output_name:
        output_name = filename + ".onyx"
        
    with open(output_name, "wb") as f:
        f.write(header)
        f.write(json_data)
        f.write(payload_data)
        
    print(f"Sucesso! Arquivo gerado: {output_name}")
    print(f"ID do Pacote: {metadata['package_id']}")
    print(f"Payload: {metadata['payload_filename']} ({metadata['payload_size']} bytes)")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: python3 create_onyx.py <caminho_do_asset>")
    else:
        create_onyx(sys.argv[1])
