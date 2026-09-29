from __future__ import annotations

import json
import os
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from catalog import FUNCTIONS, FUNCTION_BY_ID, validate_function_id


class FunctionStore:
    def __init__(self, root: Path):
        self.root = root
        self.package_dir = root / "packages"
        self.manifest_path = root / "manifest.json"
        self.package_dir.mkdir(parents=True, exist_ok=True)
        self.data = self._load()

    def _load(self) -> dict[str, Any]:
        if self.manifest_path.exists():
            data = json.loads(self.manifest_path.read_text(encoding="utf-8"))
        else:
            data = {"version": 1, "updated_at": None, "functions": {}}
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
            os.replace(temporary, self.manifest_path)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)

    def get(self, function_id: str) -> dict[str, Any]:
        validate_function_id(function_id)
        return self.data["functions"][function_id]

    def all_public(self) -> list[dict[str, Any]]:
        result = []
        for item in FUNCTIONS:
            entry = dict(self.data["functions"][item.id])
            package_path = entry.get("package")
            entry["available"] = bool(package_path and (self.root / package_path).exists())
            result.append(entry)
        return result

    def set_status(self, function_id: str, status: str) -> dict[str, Any]:
        if status not in {"active", "maintenance"}:
            raise ValueError("Status inválido")
        entry = self.get(function_id)
        entry["status"] = status
        self._save()
        return entry

    def publish(self, function_id: str, package_bytes: bytes, password_protected: bool) -> dict[str, Any]:
        item = validate_function_id(function_id)
        filename = f"{function_id.replace('.', '_')}.3105"
        destination = self.package_dir / filename
        temporary = destination.with_suffix(".3105.tmp")
        temporary.write_bytes(package_bytes)
        os.replace(temporary, destination)
        entry = self.get(function_id)
        entry.update({
            "package": f"packages/{filename}",
            "password_protected": password_protected,
            "version": int(entry.get("version", 0)) + 1,
            "status": "active",
            "name": item.name,
            "group_id": item.group_id,
            "group_name": item.group_name,
        })
        self._save()
        return entry

    def delete_package(self, function_id: str) -> dict[str, Any]:
        entry = self.get(function_id)
        package_path = entry.get("package")
        if package_path:
            path = self.root / package_path
            if path.exists():
                path.unlink()
        entry.update({"package": None, "password_protected": False, "status": "maintenance"})
        self._save()
        return entry

    def package_path(self, function_id: str) -> Path | None:
        entry = self.get(function_id)
        package_path = entry.get("package")
        if not package_path:
            return None
        path = self.root / package_path
        return path if path.exists() else None
