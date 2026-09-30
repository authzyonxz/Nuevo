from __future__ import annotations

import json
import os
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from threading import RLock
from typing import Any

from catalog import FUNCTIONS, validate_function_id


class FunctionStore:
    """Persistent catalog store shared by the Telegram bot and FastAPI."""

    def __init__(self, root: Path):
        self.root = root.resolve()
        self.package_dir = (self.root / "packages").resolve()
        self.manifest_path = (self.root / "manifest.json").resolve()
        self._lock = RLock()
        self.root.mkdir(parents=True, exist_ok=True)
        self.package_dir.mkdir(parents=True, exist_ok=True)
        self.data = self._load()

    def _load(self) -> dict[str, Any]:
        if self.manifest_path.exists():
            try:
                data = json.loads(self.manifest_path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError) as exc:
                raise RuntimeError(f"Manifesto inválido: {self.manifest_path}") from exc
        else:
            data = {"version": 1, "updated_at": None, "functions": {}}
        if not isinstance(data, dict) or not isinstance(data.get("functions"), dict):
            raise RuntimeError("Manifesto inválido: campo functions ausente")
        for item in FUNCTIONS:
            entry = data["functions"].setdefault(item.id, {})
            entry.setdefault("id", item.id)
            entry.setdefault("group_id", item.group_id)
            entry.setdefault("group_name", item.group_name)
            entry.setdefault("name", item.name)
            entry.setdefault("status", "maintenance")
            entry.setdefault("version", 0)
            entry.setdefault("package", None)
            entry.setdefault("password_protected", False)
            entry.setdefault("package_format", "3105")
            entry.setdefault("target_bundle_id", None)
            entry.setdefault("target_filename", None)
        self._save(data)
        return data

    def _save(self, data: dict[str, Any] | None = None) -> None:
        if data is None:
            data = self.data
        data["updated_at"] = datetime.now(timezone.utc).isoformat()
        fd, temporary = tempfile.mkstemp(prefix="manifest-", suffix=".json", dir=self.root)
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as handle:
                json.dump(data, handle, ensure_ascii=False, indent=2)
                handle.write("\n")
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(temporary, self.manifest_path)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)

    def _package_path(self, package_value: str | None) -> Path | None:
        if not package_value:
            return None
        path = (self.root / package_value).resolve()
        try:
            path.relative_to(self.package_dir)
        except ValueError:
            return None
        return path

    def get(self, function_id: str) -> dict[str, Any]:
        validate_function_id(function_id)
        with self._lock:
            return self.data["functions"][function_id]

    def all_public(self) -> list[dict[str, Any]]:
        with self._lock:
            result = []
            for item in FUNCTIONS:
                entry = dict(self.data["functions"][item.id])
                entry["available"] = self._package_path(entry.get("package")) is not None and self._package_path(entry.get("package")).is_file()
                result.append(entry)
            return result

    def set_status(self, function_id: str, status: str) -> dict[str, Any]:
        if status not in {"active", "maintenance"}:
            raise ValueError("Status inválido")
        with self._lock:
            entry = self.get(function_id)
            entry["status"] = status
            self._save()
            return entry

    def publish(
        self,
        function_id: str,
        package_bytes: bytes,
        password_protected: bool = False,
        *,
        package_format: str = "raw",
        target_bundle_id: str | None = None,
        target_filename: str | None = None,
    ) -> dict[str, Any]:
        item = validate_function_id(function_id)
        if package_format not in {"raw", "3105"}:
            raise ValueError("Formato de pacote inválido")
        if not package_bytes:
            raise ValueError("O arquivo publicado está vazio")
        if package_format == "raw" and (not target_bundle_id or not target_filename):
            raise ValueError("Pacote raw exige Bundle ID e nome do arquivo")
        suffix = "3105" if package_format == "3105" else "raw"
        filename = f"{function_id.replace('.', '_')}.{suffix}"
        destination = self.package_dir / filename
        temporary = self.package_dir / f".{filename}.{os.getpid()}.tmp"
        with self._lock:
            entry = self.get(function_id)
            previous_path = self._package_path(entry.get("package"))
            temporary.write_bytes(package_bytes)
            os.replace(temporary, destination)
            entry.update({
                "package": f"packages/{filename}",
                "password_protected": password_protected,
                "package_format": package_format,
                "target_bundle_id": target_bundle_id,
                "target_filename": target_filename,
                "version": int(entry.get("version", 0)) + 1,
                "status": "active",
                "name": item.name,
                "group_id": item.group_id,
                "group_name": item.group_name,
            })
            self._save()
            if previous_path and previous_path != destination and previous_path.is_file():
                previous_path.unlink()
            return entry

    def delete_package(self, function_id: str) -> dict[str, Any]:
        with self._lock:
            entry = self.get(function_id)
            path = self._package_path(entry.get("package"))
            if path and path.is_file():
                path.unlink()
            entry.update({
                "package": None,
                "password_protected": False,
                "package_format": "raw",
                "target_bundle_id": None,
                "target_filename": None,
                "status": "maintenance",
            })
            self._save()
            return entry

    def package_path(self, function_id: str) -> Path | None:
        with self._lock:
            entry = self.get(function_id)
            path = self._package_path(entry.get("package"))
            return path if path and path.is_file() else None
