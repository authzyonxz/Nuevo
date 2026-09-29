from __future__ import annotations

import hashlib
import plistlib
import secrets
import uuid
from datetime import datetime, timezone
from pathlib import Path

from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes

MAGIC = b"3105PATCH\0"
SCHEMA_VERSION = 3
KDF_ITERATIONS = 250_000
MAX_PASSWORD_BYTES = 1_024
MAX_PATH_BYTES = 4_096


def _now() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _validate_bundle_id(bundle_id: str) -> str:
    value = bundle_id.strip()
    parts = value.split(".")
    if not value or len(value.encode()) > 255 or len(parts) < 2:
        raise ValueError("Bundle ID inválido")
    if any(not part or part[0] == "-" or part[-1] == "-" for part in parts):
        raise ValueError("Bundle ID inválido")
    if any(not all(ch.isalnum() or ch == "-" for ch in part) for part in parts):
        raise ValueError("Bundle ID inválido")
    return value


def _validate_relative_path(relative_path: str) -> str:
    value = relative_path.strip()
    parts = value.split("/")
    if (
        not value
        or len(value.encode()) > MAX_PATH_BYTES
        or value.startswith("/")
        or "\\" in value
        or "//" in value
        or any(part in ("", ".", "..") for part in parts)
    ):
        raise ValueError("Caminho relativo inválido")
    return value


def _aad(kind: str, package_id: str) -> bytes:
    return f"3105PATCH/v{SCHEMA_VERSION}/{kind}/{package_id}".encode()


def _derive_key(password: str, salt: bytes) -> bytes:
    if not password or len(password.encode()) > MAX_PASSWORD_BYTES:
        raise ValueError("Senha inválida")
    kdf = PBKDF2HMAC(algorithm=hashes.SHA256(), length=32, salt=salt, iterations=KDF_ITERATIONS)
    return kdf.derive(password.encode())


def build_package(
    *,
    function_id: str,
    function_name: str,
    author: str,
    bundle_id: str,
    relative_path: str,
    replacement_filename: str,
    replacement_data: bytes,
    password: str | None = None,
) -> bytes:
    bundle_id = _validate_bundle_id(bundle_id)
    relative_path = _validate_relative_path(relative_path)
    if not replacement_filename or "/" in replacement_filename or "\\" in replacement_filename:
        raise ValueError("Nome do arquivo inválido")
    if not author or len(author.encode()) > 160:
        raise ValueError("Autor inválido")

    package_id = str(uuid.uuid4()).upper()
    rule_id = str(uuid.uuid4()).upper()
    timestamp = _now()
    project = {
        "id": package_id,
        "name": function_name,
        "author": author,
        "isPrivate": False,
        "createdAt": timestamp,
        "updatedAt": timestamp,
        "bundleIdentifiers": [bundle_id],
        "directories": [],
        "rules": [{
            "id": rule_id,
            "bundleID": bundle_id,
            "relativePath": relative_path,
            "replacementFilename": replacement_filename,
            "replacementData": replacement_data,
        }],
    }
    payload = {
        "project": project,
        "replacementDigests": {rule_id: hashlib.sha256(replacement_data).digest()},
    }
    payload_data = plistlib.dumps(payload, fmt=plistlib.FMT_BINARY, sort_keys=False)
    content_key = secrets.token_bytes(32)
    payload_nonce = secrets.token_bytes(12)
    payload_ciphertext = AESGCM(content_key).encrypt(
        payload_nonce, payload_data, _aad("payload", package_id)
    )
    # CryptoKit AES.GCM.SealedBox.combined is nonce + ciphertext + tag.
    payload_combined = payload_nonce + payload_ciphertext

    protected = bool(password)
    salt = iterations = wrapped_key = public_key = None
    key_aad_version = None
    if protected:
        salt = secrets.token_bytes(16)
        wrapping_key = _derive_key(password or "", salt)
        key_aad_version = SCHEMA_VERSION
        key_nonce = secrets.token_bytes(12)
        wrapped_ciphertext = AESGCM(wrapping_key).encrypt(
            key_nonce, content_key, _aad("key", package_id)
        )
        wrapped_key = key_nonce + wrapped_ciphertext
        public_key = None
    else:
        public_key = content_key

    envelope = {
        "schemaVersion": SCHEMA_VERSION,
        "keyAADVersion": key_aad_version,
        "packageID": package_id,
        "isPasswordProtected": protected,
        "kdfSalt": salt,
        "kdfIterations": KDF_ITERATIONS if protected else None,
        "wrappedContentKey": wrapped_key,
        "publicContentKey": public_key,
        "keyFingerprint": hashlib.sha256(content_key).digest(),
        "encryptedPayload": payload_combined,
    }
    return MAGIC + plistlib.dumps(envelope, fmt=plistlib.FMT_BINARY, sort_keys=False)


def write_package(path: Path, **kwargs) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(build_package(**kwargs))
