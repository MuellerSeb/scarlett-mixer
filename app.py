import asyncio
import signal

from PySide6.QtCore import QObject, Slot
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
import qasync
import uvicorn

from backend import Backend
from server import build_api


async def _run_uvicorn(app, host: str = "0.0.0.0", port: int = 8088):
    config = uvicorn.Config(app=app, host=host, port=port, log_level="warning")
    server = uvicorn.Server(config)
    await server.serve()


class MixBridge(QObject):
    def __init__(self, backend: Backend):
        super().__init__()
        self._backend = backend

    @Slot(str, bool)
    def setJoin(self, mix: str, joined: bool):
        asyncio.create_task(self._backend.set_join(mix, joined))

    @Slot(str, float)
    def setVolume(self, mix: str, value: float):
        asyncio.create_task(self._backend.set_volume(mix, value))

    @Slot(str, float)
    def setPan(self, mix: str, value: float):
        asyncio.create_task(self._backend.set_pan(mix, value))

    @Slot(str, float, float)
    def setLR(self, mix: str, left: float, right: float):
        l = None if left < 0 else left
        r = None if right < 0 else right
        asyncio.create_task(self._backend.set_lr(mix, l, r))


async def _amain():
    qt_app = QGuiApplication([])
    engine = QQmlApplicationEngine()

    backend = Backend()
    api = build_api(backend)

    bridge = MixBridge(backend)
    engine.rootContext().setContextProperty("bridge", bridge)
    engine.load("ui/Main.qml")
    if not engine.rootObjects():
        raise RuntimeError("Failed to load QML UI")

    asyncio.create_task(backend.meters_task())
    asyncio.create_task(_run_uvicorn(api))

    loop = asyncio.get_running_loop()
    stop = asyncio.Event()

    for sig in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(sig, stop.set)

    await stop.wait()
    await backend.shutdown()


def main_entry():
    qasync.run(_amain())


if __name__ == "__main__":
    main_entry()
