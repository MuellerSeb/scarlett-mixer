from __future__ import annotations

from nicegui import app as nice_app, ui

from backend import Backend
from mixer_ui import MixerApplication


backend = Backend()
mixer_app = MixerApplication(backend)


@nice_app.on_startup
async def _startup() -> None:
    await mixer_app.start()


@nice_app.on_shutdown
async def _shutdown() -> None:
    await mixer_app.stop()


def main(host: str = "0.0.0.0", port: int = 8080, reload: bool = False) -> None:
    """Entry point for running the NiceGUI-based Scarlett Mixer."""
    ui.run(host=host, port=port, reload=reload, title="Scarlett Mixer")


if __name__ == "__main__":
    main()
