from pathlib import Path
from typing import Optional

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel


def build_api(backend, static_dir: Optional[Path] = None) -> FastAPI:
    app = FastAPI()

    class SetGain(BaseModel):
        mix: str
        value: float

    class SetPan(BaseModel):
        mix: str
        value: float

    class SetJoin(BaseModel):
        mix: str
        joined: bool

    assets = static_dir or Path(__file__).resolve().parent / "web"
    app.mount("/", StaticFiles(directory=str(assets), html=True), name="web")

    @app.websocket("/ws")
    async def ws_endpoint(ws: WebSocket):
        await ws.accept()

        async def push(msg: dict):
            try:
                await ws.send_json(msg)
            except Exception:
                pass

        backend.bus.subscribe(push)
        try:
            await push(
                {
                    "type": "snapshot",
                    "mixes": {k: vars(v) for k, v in backend.state.mixes.items()},
                }
            )
            while True:
                msg = await ws.receive_json()
                op = msg.get("op")
                data = msg.get("data") or {}
                if op == "set_gain":
                    payload = SetGain(**data)
                    await backend.set_volume(payload.mix, payload.value)
                elif op == "set_pan":
                    payload = SetPan(**data)
                    await backend.set_pan(payload.mix, payload.value)
                elif op == "set_join":
                    payload = SetJoin(**data)
                    await backend.set_join(payload.mix, payload.joined)
                elif op == "set_lr":
                    mix = data.get("mix")
                    l = data.get("l")
                    r = data.get("r")
                    await backend.set_lr(mix, l, r)
        except WebSocketDisconnect:
            pass
        finally:
            backend.bus.unsubscribe(push)

    return app
