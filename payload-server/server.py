from __future__ import annotations

import hashlib
import json
import os
import plistlib
import tempfile
from pathlib import Path
from typing import Any

from flask import Flask, jsonify, request, send_from_directory

ROOT = Path(__file__).resolve().parent
STORAGE = ROOT / "payloads"
MANIFEST = ROOT / "manifest.json"
TOKEN = os.environ.get("PAYLOAD_ADMIN_TOKEN", "")
SUPPORTED_OS = [
    {"minimum": "17.0", "maximum": "17.7.x", "builds": None},
    {"minimum": "18.0", "maximum": "18.7.1", "builds": None},
    {"minimum": "26.0", "maximum": "26.6.1", "builds": None},
    {"minimum": "27.0", "maximum": "27.0", "builds": [
        "24A5355q", "24A5370h", "24A5380h", "24A5390f"
    ]},
]
MAGIC = b"3105PATCH\x00"

app = Flask(__name__)
STORAGE.mkdir(parents=True, exist_ok=True)


def read_manifest() -> dict[str, Any]:
    if MANIFEST.exists():
        return json.loads(MANIFEST.read_text(encoding="utf-8"))
    return {
        "schemaVersion": 1,
        "identifier": "custom-3105-payloads",
        "name": "3105 Payloads",
        "description": "Payloads por funções para o app 3105.",
        "icon": None,
        "packages": [],
    }


def write_manifest(manifest: dict[str, Any]) -> None:
    temporary = MANIFEST.with_suffix(".tmp")
    temporary.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    temporary.replace(MANIFEST)


def authorized() -> bool:
    return bool(TOKEN) and request.headers.get("X-Admin-Token", "") == TOKEN


def validate_package(path: Path) -> dict[str, Any]:
    data = path.read_bytes()
    if not data.startswith(MAGIC) or len(data) < len(MAGIC) + 100:
        raise ValueError("arquivo não é um pacote .3105 válido")
    envelope = plistlib.loads(data[len(MAGIC):])
    schema = int(envelope.get("schemaVersion", 0))
    package_id = str(envelope.get("packageID", ""))
    if schema not in (1, 2, 3) or not package_id:
        raise ValueError("envelope .3105 inválido")
    return {
        "packageID": package_id,
        "size": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
    }


def package_for_slot(manifest: dict[str, Any], slot: int) -> dict[str, Any] | None:
    key = f"function-{slot}"
    return next((p for p in manifest["packages"] if p.get("category") == key), None)


@app.get("/manifest.json")
def manifest() -> Any:
    return jsonify(read_manifest())


@app.get("/payloads/<path:filename>")
def payload(filename: str) -> Any:
    return send_from_directory(STORAGE, filename, as_attachment=True)


@app.post("/admin/functions/<int:slot>")
def upload(slot: int) -> Any:
    if slot not in range(1, 6):
        return jsonify(error="função deve estar entre 1 e 5"), 400
    if not authorized():
        return jsonify(error="não autorizado"), 401
    uploaded = request.files.get("package")
    if uploaded is None or not uploaded.filename.lower().endswith(".3105"):
        return jsonify(error="envie um arquivo .3105 no campo package"), 400

    with tempfile.NamedTemporaryFile(dir=STORAGE, suffix=".3105", delete=False) as handle:
        temporary = Path(handle.name)
    try:
        uploaded.save(temporary)
        metadata = validate_package(temporary)
        target_name = f"function-{slot}.3105"
        target = STORAGE / target_name
        temporary.replace(target)
    except (OSError, ValueError, plistlib.InvalidFileException) as error:
        temporary.unlink(missing_ok=True)
        return jsonify(error=str(error)), 400

    manifest_data = read_manifest()
    old = package_for_slot(manifest_data, slot)
    if old:
        manifest_data["packages"].remove(old)
    form = request.form
    manifest_data["packages"].append({
        "identifier": f"function-{slot}",
        "kind": "patch",
        "name": form.get("name", f"Função {slot}"),
        "author": form.get("author", "Administrador"),
        "version": form.get("version", "1.0.0"),
        "summary": form.get("summary", f"Payload da FUNÇÃO - {slot}"),
        "description": form.get("description"),
        "category": f"function-{slot}",
        "tags": [f"function-{slot}"],
        "publishedAt": form.get("publishedAt"),
        "icon": None,
        "banner": None,
        "screenshots": [],
        "download": f"payloads/{target_name}",
        "sha256": metadata["sha256"],
        "size": metadata["size"],
        "supportedOS": SUPPORTED_OS,
        "changelog": form.get("changelog"),
        "featured": slot == 1,
        "isPrivate": False,
        "password": None,
    })
    manifest_data["packages"].sort(key=lambda package: package["identifier"])
    write_manifest(manifest_data)
    return jsonify(ok=True, function=slot, package=metadata)


@app.delete("/admin/functions/<int:slot>")
def delete(slot: int) -> Any:
    if slot not in range(1, 6):
        return jsonify(error="função deve estar entre 1 e 5"), 400
    if not authorized():
        return jsonify(error="não autorizado"), 401
    manifest_data = read_manifest()
    old = package_for_slot(manifest_data, slot)
    if old:
        manifest_data["packages"].remove(old)
    (STORAGE / f"function-{slot}.3105").unlink(missing_ok=True)
    write_manifest(manifest_data)
    return jsonify(ok=True, function=slot, removed=old is not None)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "8080")))
