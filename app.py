import asyncio
import signal
import sys
from dataclasses import asdict
from pathlib import Path

from PySide6.QtCore import QObject, Signal, Slot
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
    mixSnapshot = Signal(str, dict)

    def __init__(self, backend: Backend):
        super().__init__()
        self._backend = backend
        self._backend.bus.subscribe(self._handle_bus)

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

    @Slot(str, float)
    def setLeft(self, mix: str, value: float):
        asyncio.create_task(self._backend.set_lr(mix, value, None))

    @Slot(str, float)
    def setRight(self, mix: str, value: float):
        asyncio.create_task(self._backend.set_lr(mix, None, value))

    @Slot(str, bool)
    def setMixMute(self, mix: str, muted: bool):
        asyncio.create_task(self._backend.set_mix_mute(mix, muted))

    @Slot(str, str)
    def setStereoPair(self, mix: str, partner: str):
        target = partner if partner else None
        asyncio.create_task(self._backend.set_stereo_pair(mix, target))

    @Slot(str, int, float)
    def setChannelVolume(self, mix: str, channel_index: int, value: float):
        asyncio.create_task(self._backend.set_channel_volume(mix, channel_index, value))

    @Slot(str, int, bool)
    def setChannelMute(self, mix: str, channel_index: int, muted: bool):
        asyncio.create_task(self._backend.set_channel_mute(mix, channel_index, muted))

    @Slot(str, int, bool)
    def setChannelSolo(self, mix: str, channel_index: int, solo: bool):
        asyncio.create_task(self._backend.set_channel_solo(mix, channel_index, solo))

    @Slot(str, int, float)
    def setChannelPan(self, mix: str, channel_index: int, value: float):
        asyncio.create_task(self._backend.set_channel_pan(mix, channel_index, value))

    async def _handle_bus(self, msg: dict):
        if msg.get("type") != "snapshot":
            return
        for name, payload in msg["mixes"].items():
            self.mixSnapshot.emit(name, payload)

    def push_initial_snapshot(self):
        for name, mix in self._backend.state.mixes.items():
            self.mixSnapshot.emit(name, asdict(mix))


async def _amain(base_dir: Path):
    engine = QQmlApplicationEngine()

    backend = Backend()
    api = build_api(backend, base_dir / "web")

    bridge = MixBridge(backend)
    engine.rootContext().setContextProperty("bridge", bridge)
    engine.load(str(base_dir / "ui" / "Main.qml"))
    if not engine.rootObjects():
        raise RuntimeError("Failed to load QML UI")

    bridge.push_initial_snapshot()

    meter_task = asyncio.create_task(backend.meters_task())
    server_task = asyncio.create_task(_run_uvicorn(api))

    loop = asyncio.get_running_loop()
    stop = asyncio.Event()

    for sig in (signal.SIGINT, signal.SIGTERM):
        try:
            loop.add_signal_handler(sig, stop.set)
        except NotImplementedError:
            # Signal handlers are not available on some platforms (e.g. Windows)
            pass

    await stop.wait()
    await backend.shutdown()

    for task in (meter_task, server_task):
        task.cancel()

    await asyncio.gather(meter_task, server_task, return_exceptions=True)


def main_entry():
    base_dir = Path(__file__).resolve().parent
    qt_app = QGuiApplication(sys.argv)
    loop = qasync.QEventLoop(qt_app)
    asyncio.set_event_loop(loop)
    try:
        loop.run_until_complete(_amain(base_dir))
    finally:
        loop.close()
        qt_app.quit()


if __name__ == "__main__":
    main_entry()
