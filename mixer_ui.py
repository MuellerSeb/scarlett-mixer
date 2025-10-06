from __future__ import annotations

import asyncio
import contextlib
from dataclasses import asdict
from typing import Dict, Iterable, List, Optional

from nicegui import ui

from backend import Backend


class ChannelStrip:
    """Reusable vertical channel strip with level meter, fader, mute/solo and optional pan."""

    def __init__(self, backend: Backend, mix_name: str, index: int, title: str):
        self.backend = backend
        self.mix_name = mix_name
        self.index = index
        self.title = title
        self._syncing = False

        self.container = ui.column().classes(
            "items-center gap-2 p-2 bg-slate-900/40 rounded-lg w-28"
        )
        with self.container:
            ui.label(self.title).classes("text-sm font-semibold text-center")
            self.meter = ui.linear_progress(value=0.0).props(
                "rounded reverse color=green vertical"
            ).classes("h-32 w-4")
            self.volume_slider = ui.slider(min=0.0, max=1.0, step=0.01).props(
                "vertical color=primary"
            ).classes("h-40")
            self.volume_slider.on(
                "change",
                lambda e: asyncio.create_task(self._handle_volume_change(e)),
            )
            self.pan_section = ui.column().classes("items-center gap-1")
            with self.pan_section:
                ui.label("Pan").classes("text-xs uppercase tracking-wide")
                self.pan_knob = ui.knob(
                    min=-1.0,
                    max=1.0,
                    value=0.0,
                    step=0.01,
                ).props("size=80 color=secondary show-value")
                self.pan_knob.on(
                    "change",
                    lambda e: asyncio.create_task(self._handle_pan_change(e)),
                )
            self.pan_section.set_visibility(False)
            self.mute_checkbox = ui.checkbox("Mute")
            self.mute_checkbox.on(
                "change",
                lambda e: asyncio.create_task(self._handle_mute_change(e)),
            )
            self.solo_checkbox = ui.checkbox("Solo")
            self.solo_checkbox.on(
                "change",
                lambda e: asyncio.create_task(self._handle_solo_change(e)),
            )

    async def _handle_volume_change(self, event):
        if self._syncing:
            return
        await self.backend.set_channel_volume(self.mix_name, self.index, event.value)

    async def _handle_pan_change(self, event):
        if self._syncing:
            return
        await self.backend.set_channel_pan(self.mix_name, self.index, event.value)

    async def _handle_mute_change(self, event):
        if self._syncing:
            return
        await self.backend.set_channel_mute(self.mix_name, self.index, event.value)

    async def _handle_solo_change(self, event):
        if self._syncing:
            return
        await self.backend.set_channel_solo(self.mix_name, self.index, event.value)

    def update(self, payload: Dict, stereo_enabled: bool) -> None:
        self._syncing = True
        try:
            self.volume_slider.value = payload.get("volume", 0.0)
            self.meter.value = payload.get("level", 0.0)
            mute = bool(payload.get("mute", False))
            solo = bool(payload.get("solo", False))
            if self.mute_checkbox.value != mute:
                self.mute_checkbox.value = mute
            if self.solo_checkbox.value != solo:
                self.solo_checkbox.value = solo
            self.pan_section.set_visibility(stereo_enabled)
            if stereo_enabled:
                self.pan_knob.value = payload.get("pan", 0.0)
        finally:
            self._syncing = False


class MasterStrip:
    """Master control for a mix with fader, optional pan, and mute/join controls."""

    def __init__(self, backend: Backend, mix_name: str):
        self.backend = backend
        self.mix_name = mix_name
        self._syncing = False

        self.container = ui.column().classes(
            "items-center gap-3 p-4 bg-slate-900/60 rounded-xl w-56"
        )
        with self.container:
            self.title_label = ui.label(f"Mix {mix_name}").classes(
                "text-lg font-semibold"
            )
            self.level_l = ui.linear_progress(value=0.0).props(
                "rounded color=green"
            ).classes("w-full h-2")
            self.level_r = ui.linear_progress(value=0.0).props(
                "rounded color=green"
            ).classes("w-full h-2")
            self.volume_slider = ui.slider(min=0.0, max=1.0, step=0.01).props(
                "vertical color=primary"
            ).classes("h-48")
            self.volume_slider.on(
                "change",
                lambda e: asyncio.create_task(self._handle_volume_change(e)),
            )
            self.pan_container = ui.column().classes("items-center gap-2")
            with self.pan_container:
                ui.label("Master Pan").classes("text-sm uppercase tracking-wide")
                self.pan_knob = ui.knob(
                    min=-1.0,
                    max=1.0,
                    value=0.0,
                    step=0.01,
                ).props("size=90 color=secondary show-value")
                self.pan_knob.on(
                    "change",
                    lambda e: asyncio.create_task(self._handle_pan_change(e)),
                )
            self.pan_container.set_visibility(False)
            self.join_switch = ui.switch("Link Gains")
            self.join_switch.on(
                "change", lambda e: asyncio.create_task(self._handle_join_change(e))
            )
            self.mute_checkbox = ui.checkbox("Mute Mix")
            self.mute_checkbox.on(
                "change",
                lambda e: asyncio.create_task(self._handle_mute_change(e)),
            )

    async def _handle_volume_change(self, event):
        if self._syncing:
            return
        await self.backend.set_volume(self.mix_name, event.value)

    async def _handle_pan_change(self, event):
        if self._syncing:
            return
        await self.backend.set_pan(self.mix_name, event.value)

    async def _handle_join_change(self, event):
        if self._syncing:
            return
        await self.backend.set_join(self.mix_name, event.value)

    async def _handle_mute_change(self, event):
        if self._syncing:
            return
        await self.backend.set_mix_mute(self.mix_name, event.value)

    def update(self, payload: Dict) -> None:
        stereo_active = bool(payload.get("stereo_pair"))
        self._syncing = True
        try:
            partner = payload.get("stereo_pair")
            if partner:
                self.title_label.text = f"Mix {self.mix_name} ↔ {partner}"
            else:
                self.title_label.text = f"Mix {self.mix_name}"
            self.volume_slider.value = payload.get("volume", 0.0)
            self.level_l.value = payload.get("level_l", 0.0)
            self.level_r.value = payload.get("level_r", 0.0)
            self.mute_checkbox.value = bool(payload.get("mute", False))
            if stereo_active:
                self.pan_container.set_visibility(True)
                self.pan_knob.value = payload.get("pan", 0.0)
                self.join_switch.set_visibility(True)
                self.join_switch.enable()
                self.join_switch.value = bool(payload.get("joined", False))
            else:
                self.pan_container.set_visibility(False)
                if self.join_switch.value:
                    self.join_switch.value = False
                self.join_switch.disable()
                self.join_switch.set_visibility(False)
        finally:
            self._syncing = False


class MixView:
    """Composite view showing master controls and repeated channel strips for a mix."""

    def __init__(self, backend: Backend, mix_name: str, channel_names: Iterable[str]):
        self.backend = backend
        self.mix_name = mix_name
        self.master = MasterStrip(backend, mix_name)
        self.channel_strips: List[ChannelStrip] = []

        self.container = ui.row().classes("gap-6 items-start w-full")
        with self.container:
            self.master.container
            self.scroll = ui.scroll_area().classes(
                "flex-1 h-[520px] bg-slate-900/30 rounded-xl"
            )
            with self.scroll:
                self.channel_row = ui.row().classes(
                    "gap-4 p-4 min-w-max"
                )
                with self.channel_row:
                    for index, title in enumerate(channel_names):
                        strip = ChannelStrip(backend, mix_name, index, title)
                        self.channel_strips.append(strip)

    def update(self, payload: Dict) -> None:
        channels = payload.get("channels", [])
        stereo_active = bool(payload.get("stereo_pair"))
        self.master.update(payload)
        for strip, ch_payload in zip(self.channel_strips, channels):
            strip.update(ch_payload, stereo_active)


class StereoLinkPanel:
    """Control block for linking mixes into stereo pairs."""

    def __init__(self, backend: Backend):
        self.backend = backend
        self._syncing = False
        self.pairs = [("A", "B"), ("C", "D"), ("E", "F"), ("G", "H"), ("I", "J")]
        self.switches: Dict[tuple[str, str], ui.switch] = {}

        self.container = ui.card().classes("p-4 bg-slate-900/70 text-white w-full")
        with self.container:
            ui.label("Stereo Mix Linking").classes("text-lg font-semibold mb-2")
            self.description = ui.label(
                "Link adjacent mixes to form stereo pairs."
            ).classes("text-sm text-gray-300 mb-4")
            self.switch_row = ui.row().classes("gap-6 flex-wrap")
            with self.switch_row:
                for left, right in self.pairs:
                    switch = ui.switch(f"{left} / {right}")
                    switch.on(
                        "change",
                        lambda e, l=left, r=right: asyncio.create_task(
                            self._handle_toggle(l, r, e.value)
                        )
                    )
                    self.switches[(left, right)] = switch

    async def _handle_toggle(self, left: str, right: str, active: bool) -> None:
        if self._syncing:
            return
        if active:
            await self.backend.set_stereo_pair(left, right)
        else:
            await self.backend.set_stereo_pair(left, None)

    def update(self, mixes: Dict[str, Dict]) -> None:
        self._syncing = True
        try:
            for left, right in self.pairs:
                switch = self.switches[(left, right)]
                left_mix = mixes.get(left, {})
                right_mix = mixes.get(right, {})
                active = (
                    left_mix.get("stereo_pair") == right
                    and right_mix.get("stereo_pair") == left
                )
                switch.value = active
        finally:
            self._syncing = False


class MixerApplication:
    """High-level NiceGUI application wiring backend state to interactive components."""

    def __init__(self, backend: Backend):
        self.backend = backend
        self._queue: asyncio.Queue[Dict[str, Dict]] = asyncio.Queue()
        self._consumer_task: Optional[asyncio.Task] = None
        self._meter_task: Optional[asyncio.Task] = None
        self.stereo_panel: Optional[StereoLinkPanel] = None
        self.mix_views: Dict[str, MixView] = {}

        self.backend.bus.subscribe(self._on_bus_message)
        self._build_ui()

    def _build_ui(self) -> None:
        ui.page_title("Scarlett Mixer")
        with ui.header().classes("bg-slate-950 text-white"):
            ui.label("Scarlett Mixer").classes("text-xl font-semibold")
        with ui.column().classes("w-full max-w-[1600px] mx-auto gap-6 p-4 text-white"):
            self.stereo_panel = StereoLinkPanel(self.backend)
            mix_names = sorted(self.backend.state.mixes.keys())
            self.tabs = ui.tabs().classes("w-full")
            with self.tabs:
                for name in mix_names:
                    ui.tab(name)
            self.tab_panels = ui.tab_panels(self.tabs).classes("w-full")
            with self.tab_panels:
                for name in mix_names:
                    with ui.tab_panel(name):
                        channel_names = [
                            ch.name for ch in self.backend.state.mixes[name].channels
                        ]
                        view = MixView(self.backend, name, channel_names)
                        self.mix_views[name] = view
        self.tabs.value = mix_names[0] if mix_names else None

    async def _on_bus_message(self, msg: Dict) -> None:
        if msg.get("type") != "snapshot":
            return
        await self._queue.put(msg["mixes"])

    async def _consume_updates(self) -> None:
        try:
            while True:
                mixes = await self._queue.get()
                await self._apply_snapshot(mixes)
        except asyncio.CancelledError:
            pass

    async def _apply_snapshot(self, mixes: Dict[str, Dict]) -> None:
        if self.stereo_panel:
            self.stereo_panel.update(mixes)
        for name, view in self.mix_views.items():
            payload = mixes.get(name)
            if payload:
                view.update(payload)

    async def start(self) -> None:
        initial = {name: asdict(mix) for name, mix in self.backend.state.mixes.items()}
        await self._apply_snapshot(initial)
        self._consumer_task = asyncio.create_task(self._consume_updates())
        self._meter_task = asyncio.create_task(self.backend.meters_task())

    async def stop(self) -> None:
        if self._consumer_task:
            self._consumer_task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await self._consumer_task
            self._consumer_task = None
        await self.backend.shutdown()
        if self._meter_task:
            await self._meter_task
            self._meter_task = None
        self.backend.bus.unsubscribe(self._on_bus_message)


__all__ = [
    "ChannelStrip",
    "MasterStrip",
    "MixView",
    "StereoLinkPanel",
    "MixerApplication",
]
