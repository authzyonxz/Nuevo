from __future__ import annotations

import os
import threading

import uvicorn

from api import create_app
from bot import ROOT, STORE, build_application


def main() -> None:
    api = create_app(STORE)
    api_thread = threading.Thread(
        target=uvicorn.run,
        kwargs={
            "app": api,
            "host": os.getenv("API_HOST", "0.0.0.0"),
            "port": int(os.getenv("API_PORT", "8080")),
            "log_level": "info",
        },
        daemon=True,
    )
    api_thread.start()
    application = build_application()
    application.run_polling(allowed_updates=["message", "callback_query"])


if __name__ == "__main__":
    main()
