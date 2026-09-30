# YerasAI — Free Offline AI on Your Phone

Flutter app that runs open-source LLMs **fully on-device**. No cloud, no account, no paywall. Private by design.

## Features

- On-device chat with streaming, stop button
- GGUF models with fit labels (Recommended / Slow / Won't fit)
- Resumable downloads with accurate progress and storage check
- RAM, storage, and accelerator info
- Refuses oversized models instead of crashing
- Saved chats with rename, delete, and resume
- Theme, temperature / context settings, onboarding

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
