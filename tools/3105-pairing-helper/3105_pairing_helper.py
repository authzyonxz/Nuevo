#!/usr/bin/env python3
"""3105 Pairing Helper.

Runs locally on Windows, macOS, or Linux. It uses pymobiledevice3 for the
USB/usbmux pairing and the documented CoreDevice file-write operation. No
pairing data is sent to a remote server.
"""
from __future__ import annotations

import argparse
import os
import plistlib
import re
import shutil
import subprocess
import sys
from pathlib import Path

APP_BUNDLE_ID = "com.apple.mobile.MobileHouseArrest"
REMOTE_PATH = "Documents/ALTPairingFile.mobiledevicepairing"
REQUIRED_KEYS = {"HostID", "HostCertificate", "HostPrivateKey"}


def run(command: list[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
    print("$", " ".join(command))
    return subprocess.run(command, text=True, check=check)


def find_cli() -> str:
    cli = shutil.which("pymobiledevice3")
    if not cli:
        raise SystemExit(
            "pymobiledevice3 não encontrado. Instale com: "
            "python -m pip install pymobiledevice3"
        )
    return cli


def find_pairing_candidates() -> list[Path]:
    home = Path.home()
    candidates = [
        Path.cwd() / "ALTPairingFile.mobiledevicepairing",
        Path.cwd() / "pairing.mobiledevicepairing",
        home / ".config" / "pymobiledevice3",
        home / ".config" / "libimobiledevice",
        home / "Library" / "Lockdown",
        Path(os.environ.get("APPDATA", "")) / "pymobiledevice3",
    ]
    found: list[Path] = []
    for candidate in candidates:
        if candidate.is_file():
            found.append(candidate)
        elif candidate.is_dir():
            found.extend(p for p in candidate.rglob("*") if p.is_file() and p.suffix in {".plist", ".mobiledevicepairing", ".mobilepair"})
    return list(dict.fromkeys(found))


def validate_pairing(path: Path) -> None:
    try:
        data = plistlib.loads(path.read_bytes())
    except Exception as exc:
        raise SystemExit(f"Pairing inválido ou ilegível: {exc}") from exc
    missing = REQUIRED_KEYS - set(data)
    if missing:
        raise SystemExit(f"Pairing não contém as chaves esperadas: {', '.join(sorted(missing))}")


def generate_pairing(cli: str) -> Path:
    print("Deixe o iPhone desbloqueado e aceite 'Confiar neste computador' se aparecer.")
    result = subprocess.run([cli, "lockdown", "pair"], text=True, capture_output=True)
    sys.stdout.write(result.stdout)
    sys.stderr.write(result.stderr)
    if result.returncode != 0:
        raise SystemExit(
            "O pareamento não foi concluído. Confira o cabo, o iPhone desbloqueado "
            "e tente novamente."
        )

    # Some versions print the generated record path; prefer it when available.
    output = result.stdout + "\n" + result.stderr
    for match in re.findall(r"[^\s\"']+\.(?:plist|mobiledevicepairing|mobilepair)", output):
        path = Path(match).expanduser()
        if path.is_file():
            return path

    candidates = find_pairing_candidates()
    if not candidates:
        raise SystemExit(
            "O pareamento foi aceito, mas a ferramenta não informou onde salvou o "
            "arquivo. Passe o caminho manualmente com --pairing-file."
        )
    return max(candidates, key=lambda path: path.stat().st_mtime)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pin", help="código exibido na aba CONFIG; usado como confirmação local")
    parser.add_argument("--pairing-file", type=Path, help="usar um pairing já criado em vez de gerar outro")
    parser.add_argument("--app-bundle-id", default=APP_BUNDLE_ID)
    parser.add_argument("--remote-path", default=REMOTE_PATH)
    args = parser.parse_args()

    cli = find_cli()
    run([cli, "usbmux", "list"])

    if args.pin is None:
        args.pin = input("Digite o código exibido em CONFIG no 3105: ").strip()
    if not re.fullmatch(r"\d{6}", args.pin):
        raise SystemExit("O código deve ter exatamente 6 dígitos.")
    print("Código aceito localmente. Ele confirma que o envio foi iniciado pelo usuário.")

    pairing = args.pairing_file.expanduser().resolve() if args.pairing_file else generate_pairing(cli)
    if not pairing.is_file():
        raise SystemExit(f"Arquivo não encontrado: {pairing}")
    validate_pairing(pairing)
    print(f"Pairing validado: {pairing}")

    # CoreDevice writes directly into the app's Documents container over the
    # trusted USB connection. The app discovers it on the next refresh.
    run([
        cli,
        "developer",
        "core-device",
        "write-file",
        "appDataContainer",
        args.remote_path,
        str(pairing),
        "--identifier",
        args.app_bundle_id,
    ])
    print("Pairing enviado para o 3105. Abra CONFIG e toque em 'Procurar pairing'.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
