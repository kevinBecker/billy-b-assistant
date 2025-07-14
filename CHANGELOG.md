# Changelog

All notable changes to this project will be documented in this file.

---

## [1.0.0] — 2025-05-25
### Initial Version
**Core Functionality**
- Real-time, full-duplex voice assistant powered by OpenAI GPT-4o.
- Assistant input/output using `sounddevice` with a push-button session trigger.
- Streaming response handling with chunked playback and lip-syncing via RMS analysis.
- Motor control using Raspberry Pi GPIO:
    - PWM-based mouth movement synchronized to speech.
    - Head and tail motion via H-bridge motor drivers.

**Personality System**
- Configurable personality traits via `persona.ini` with real-time runtime updates using function calling.
- Trait categories include: `humor`, `sarcasm`, `honesty`, `confidence`, `verbosity`, `curiosity`, and more.
- Backstory and behavioral instructions stored in `persona.ini` with structured `[PERSONALITY]`, `[BACKSTORY]`, and `[META]` sections.

**Hardware & Setup**
- 3D-printable backplate to mount USB microphone and speaker in the Billy Bass enclosure.
- GPIO safe boot state configuration to prevent motor activation during Pi startup.
- Systemd integration (`billy.service`) for background operation and autostart at boot.

**Audio System**
- Configurable voice model (`VOICE`) via `.env` file.
- Adjustable silence threshold and mic timeout for voice session logic.

**MQTT Integration (Optional)**
- Basic MQTT connectivity for status reporting, safe shutdown raspberry pi command and future integration with Home Assistant.

**Song Mode**
- Folder-based song playback system supporting:
    - `full.wav` for audio
    - `vocals.wav` and `drums.wav` for animated flapping (mouth and tail)
    - `metadata.txt` to control animation timing and motion profiles
- Function-calling support to trigger songs via conversation with Billy.


## [1.1.0] — 2025-06-??
### Feature Release: Home Assistant API Integration, Web UI, 

#### Core Enhancements
- Improved session flow with follow-up intent detection and looping behavior.
- Integrated `ruff` for linting and formatting, with pre-commit hook support.

#### Web UI (`/webconfig`)
- Web-based configuration for:
    - OpenAI API key, MQTT configuration, Home Assistant settings.
    - Microphone/speaker information and silence timeout settings.
    - Home Assistant  URL, token, and language.
    - Personality Traits and Backstory
- Microphone gain control slider (0–16) using `amixer`.
- Live microphone level meter with RMS graph for threshold tuning.
- System log viewer powered by `journalctl`.
- Service control panel to start/stop/restart `billy.service`.
- Dark mode UI with Tailwind CSS and Material Icons.
