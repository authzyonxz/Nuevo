import os
import tempfile
from pathlib import Path

with tempfile.TemporaryDirectory() as directory:
    os.environ["PAYLOAD_STORAGE"] = str(Path(directory) / "payloads")
    os.environ["PAYLOAD_MANIFEST"] = str(Path(directory) / "manifest.json")
    os.environ["PAYLOAD_ADMIN_TOKEN"] = "test-token"
    from server import app

    routes = {rule.rule for rule in app.url_map.iter_rules()}
    assert "/admin/functions/<game>/<int:slot>" in routes
    assert "/admin/functions/<int:slot>" in routes
    client = app.test_client()
    assert client.get("/manifest.json").status_code == 200
    assert client.post("/admin/functions/invalid/1").status_code == 400
    assert client.post("/admin/functions/max/4").status_code == 400

print("payload-server routes OK")
