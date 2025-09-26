import asyncio
import math
import time
from dataclasses import dataclass, asdict
from typing import Any, Callable, Coroutine, Dict, Optional, Set


@dataclass
class Mix:
    name: str
    joined: bool = True
    volume: float = 0.75
    pan: float = 0.0
    gain_l: float = 0.75
    gain_r: float = 0.75
    mute: bool = False
    level_l: float = 0.0
    level_r: float = 0.0


@dataclass
class AppState:
    mixes: Dict[str, Mix]


class EventBus:
    def __init__(self):
        self._subs: Set[Callable[[dict], Coroutine[Any, Any, None]]] = set()

    def subscribe(self, cb: Callable[[dict], Coroutine[Any, Any, None]]):
        self._subs.add(cb)

    def unsubscribe(self, cb: Callable[[dict], Coroutine[Any, Any, None]]):
        self._subs.discard(cb)

    async def publish(self, msg: dict):
        dead: Set[Callable[[dict], Coroutine[Any, Any, None]]] = set()
        for cb in list(self._subs):
            try:
                await cb(msg)
            except Exception:
                dead.add(cb)
        for cb in dead:
            self._subs.discard(cb)


class Backend:
    """Mixer state holder. Replace TODOs with ALSA/JACK/MIDI integration."""

    def __init__(self):
        self.state = AppState(
            mixes={
                "A": Mix("A"),
                "B": Mix("B", volume=0.6),
                "C": Mix("C", volume=0.5),
            }
        )
        self.bus = EventBus()
        self._stop = asyncio.Event()
        self._last_broadcast = 0.0

    # --- Helpers ---------------------------------------------------------
    def _apply_stereo_join(self, mix: Mix):
        theta = (mix.pan + 1) * math.pi / 4
        mix.gain_l = mix.volume * math.cos(theta)
        mix.gain_r = mix.volume * math.sin(theta)

    async def _broadcast_state(self):
        now = time.time()
        if now - self._last_broadcast < 0.03:
            return
        self._last_broadcast = now
        payload = {
            "type": "snapshot",
            "mixes": {name: asdict(m) for name, m in self.state.mixes.items()},
        }
        await self.bus.publish(payload)

    # --- Public mutators -------------------------------------------------
    async def set_join(self, mix: str, joined: bool):
        m = self.state.mixes[mix]
        m.joined = joined
        if joined:
            self._apply_stereo_join(m)
        await self._broadcast_state()

    async def set_volume(self, mix: str, value: float):
        m = self.state.mixes[mix]
        m.volume = max(0.0, min(1.0, value))
        if m.joined:
            self._apply_stereo_join(m)
        await self._broadcast_state()

    async def set_pan(self, mix: str, value: float):
        m = self.state.mixes[mix]
        m.pan = max(-1.0, min(1.0, value))
        if m.joined:
            self._apply_stereo_join(m)
        await self._broadcast_state()

    async def set_lr(self, mix: str, l: Optional[float] = None, r: Optional[float] = None):
        m = self.state.mixes[mix]
        if l is not None:
            m.gain_l = max(0.0, min(1.0, l))
        if r is not None:
            m.gain_r = max(0.0, min(1.0, r))
        await self._broadcast_state()

    # --- Fake meters task ------------------------------------------------
    async def meters_task(self):
        t = 0.0
        while not self._stop.is_set():
            t += 0.03
            for mix in self.state.mixes.values():
                base = 0.2 + 0.2 * (math.sin(t * 1.3) + 1) / 2
                wiggle = 0.1 * (math.sin(t * 7.1) + 1) / 2
                left_source = mix.gain_l
                right_source = mix.gain_r
                mix.level_l = max(0.0, min(1.0, left_source * (base + wiggle)))
                mix.level_r = max(0.0, min(1.0, right_source * (base + wiggle * 0.8)))
            await self._broadcast_state()
            await asyncio.sleep(0.03)

    async def run(self):
        await self._broadcast_state()
        await self._stop.wait()

    async def shutdown(self):
        self._stop.set()
