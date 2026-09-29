from __future__ import annotations

import os
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse

from catalog import validate_function_id
from store import FunctionStore


def create_app(store: FunctionStore) -> FastAPI:
    app = FastAPI(title="3105 Function Catalog", version="1.0.0")
    public_base_url = os.getenv("PUBLIC_BASE_URL", "").rstrip("/")

    @app.get("/health")
    def health() -> dict[str, str]:
        return {"status": "ok"}

    @app.get("/api/functions")
    def functions() -> dict:
        entries = []
        for entry in store.all_public():
            item = dict(entry)
            item["package_url"] = (
                f"{public_base_url}/packages/{entry['id'].replace('.', '_')}.3105"
                if item["available"] and public_base_url
                else None
            )
            entries.append(item)
        return {"version": 1, "functions": entries}

    @app.get("/api/functions/{function_id}")
    def function(function_id: str) -> dict:
        try:
            validate_function_id(function_id)
            entry = dict(store.get(function_id))
        except ValueError as exc:
            raise HTTPException(status_code=404, detail="Unknown function") from exc
        entry["available"] = store.package_path(function_id) is not None
        entry["package_url"] = (
            f"{public_base_url}/packages/{function_id.replace('.', '_')}.3105"
            if entry["available"] and public_base_url
            else None
        )
        return entry

    @app.get("/packages/{package_name}")
    def package(package_name: str):
        if not package_name.endswith(".3105"):
            raise HTTPException(status_code=404, detail="Package not found")
        package_path = f"packages/{package_name}"
        entry = next(
            (
                item
                for item in store.all_public()
                if item.get("package") == package_path
            ),
            None,
        )
        if entry is None:
            raise HTTPException(status_code=404, detail="Package not found")
        if entry.get("status") != "active":
            raise HTTPException(status_code=423, detail="Function under maintenance")
        path = store.package_path(entry["id"])
        if path is None:
            raise HTTPException(status_code=404, detail="Package not published")
        return FileResponse(path, media_type="application/octet-stream", filename=path.name)

    return app
