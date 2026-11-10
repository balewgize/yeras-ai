# YerasAI: Free Offline AI on Your Phone

Flutter app that runs open-source LLMs **fully on-device**. No cloud, no account. Private by design.

## Features

- On-device chat with streaming, stop button
- GGUF models with fit labels (Recommended / Slow / Won't fit)
- Resumable downloads with accurate progress and storage check
- RAM, storage, and accelerator info
- Refuses oversized models instead of crashing
- Saved chats with rename, delete, and resume
- Auto-trims old messages when context fills
- Theme, temperature / context settings, onboarding

## Screenshot
<p align="center">
  <img src="https://github.com/user-attachments/assets/14e07ba7-bbd1-4081-bdde-367b377bc119" width="45%" />
  &nbsp; &nbsp; &nbsp; &nbsp;
  <img src="https://github.com/user-attachments/assets/5547bfec-82bc-4b93-89f2-299813869053" width="45%" />
</p>


## Install on Android

Download `app-arm64-v8a-release.apk` from the
[latest release](https://github.com/balewgize/yeras-ai/releases/latest) and open
it on your phone. The first install needs "install unknown apps" allowed for
your browser or file manager.

- Android 7.0 or newer, 64-bit ARM device
- 4 GB RAM minimum; 6–8 GB is comfortable
- 0.4–2 GB of storage per model, downloaded on first use (Wi-Fi recommended)

To verify the download, run `sha256sum app-arm64-v8a-release.apk` and compare it
with the checksum in the release notes.

### What to expect

These are 1B–3B parameter models running on your phone's CPU or GPU — not a
frontier model on a server. They summarize, rewrite, translate, and answer short
questions reasonably well. They are weaker at multi-step reasoning, current
events, and code, and they can be confidently wrong. Check anything that matters.

## Tech stack

- **Flutter + Dart** (Material 3, minimal Claude/ChatGPT-style UI)
- **llamadart** (llama.cpp binding — Vulkan on Android, Metal on iOS)
- **Riverpod** for state, **SharedPreferences** + local files for persistence
- `path_provider`, `device_info_plus`, `flutter_markdown_plus`

## Getting started

```bash
flutter pub get
flutter run
```

Primary target: Android 8 GB RAM class device. iOS supported (deployment target ≥ 16.4).

Models download from Hugging Face (Bartowski GGUF quants) on first use — keep the app open while downloading.

## Project structure

```
lib/
  main.dart                    # app entry + onboarding gate
  theme/                       # light/dark/system theme
  models/                      # chat, conversation, catalog, download, inference
  providers/                   # Riverpod controllers (chat, downloads, settings)
  data/repositories/           # inference, downloads, catalog, device, history
  data/models_catalog.json     # curated model list
  screens/home/                # chat UI (split: input, list, drawer, picker, status)
  screens/                     # catalog, settings, device info, onboarding
  utils/ widgets/              # formatting, errors, shared UI
```

## License

MIT
