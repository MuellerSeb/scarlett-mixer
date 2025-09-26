# Scarlett Mixer Prototype

Modern Qt/QML desktop mixer with a built-in FastAPI WebSocket server for phone control.

## Install

```bash
python -m venv .venv && source .venv/bin/activate
pip install -U pip
pip install -e .
```

## Run

```bash
python app.py
```

* Desktop UI appears.
* Phone: connect to `http://<your-linux-ip>:8088/` (same LAN). You’ll see **Mix A** controls that stay in sync with the desktop UI.

## Next steps

* Wire **ALSA**: in `backend.set_*` routines, resolve the correct ALSA mixer controls and write.
* Add **MIDI (X-Touch Mini)**: read CC, map to `set_*` methods, send ring LED feedback.
* Replace **fake meters** with **JACK** peak/RMS, throttle to ~15–30 Hz for web.
* Add auth and per-mix scoping tokens for band mates.
