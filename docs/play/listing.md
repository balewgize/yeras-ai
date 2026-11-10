# Play Store listing copy

## App name (max 30 characters)

```
YerasAI — Offline AI Chat
```

## Short description (max 80 characters)

```
Chat with open AI models entirely on your phone. Free, private, offline.
```

## Full description (max 4000 characters)

```
YerasAI runs open-source language models entirely on your phone.

No account. No cloud. No subscription. Your conversations never leave your device.

WHY YERASAI
• Fully offline — after you download a model, nothing is sent to a server
• Private by design — chat history is stored only on your phone
• Free core experience — no paywall, no credits, no ads
• Honest performance labels — see which models fit your device before downloading
• Real downloads — resumable, with accurate progress and clear errors

HOW IT WORKS
1. Open the model catalog and pick a model that fits your RAM.
2. Download it once over Wi-Fi. Downloads can be resumed if they stop.
3. Chat. Everything runs locally on your device's CPU or GPU.

FEATURES
• Streaming responses with a stop button
• Multiple saved conversations — rename, delete, and resume
• Light, dark, and system themes
• Temperature and context-length controls for power users
• Device report: RAM, storage, CPU, GPU, and acceleration support
• Works without a network connection once a model is installed

GOOD TO KNOW
• A 0.5B–3B model needs roughly 0.4–2 GB of storage and 4–8 GB of RAM.
• Larger models give better answers but generate slower.
• The first launch after install may take a little longer while the runtime loads.
• Models are downloaded directly from Hugging Face. Their licenses apply.

YerasAI is built for people who want a capable assistant without handing their
conversations to a cloud service.
```

## Category

Primary: **Productivity** (alternative: Tools)

## Tags

`AI`, `offline`, `chatbot`, `privacy`, `local AI`

## Contact details

- Email: `support@addislab.com` **(replace if different)**
- Website: optional
- Privacy policy: `https://<user>.github.io/<repo>/play/privacy-policy.html`

## Graphics checklist

| Asset | File | Status |
| --- | --- | --- |
| App icon 512×512 | `assets/branding/play_icon_512.png` | ready |
| Feature graphic 1024×500 | `assets/branding/feature_graphic.png` | ready |
| Phone screenshots (2–8) | — | capture from the release build |
| 7-inch tablet screenshots | optional | not provided |
| 10-inch tablet screenshots | optional | not provided |

Google Play accepts PNG or JPEG screenshots with 16:9 or 9:16 aspect ratio,
320–3840 px on each side. Use the dark theme or light theme consistently across
the set.

## Data safety answers

| Question | Answer |
| --- | --- |
| Does the app collect or share any required user data? | **No** |
| Is all user data encrypted in transit? | Yes (model downloads use HTTPS) |
| Can users request data deletion? | Yes — delete chats in-app; uninstalling removes all local data |
| Data collected by third-party SDKs? | None. No analytics, ads, crash reporting, or account SDK. |
| Approximate location / precise location | Not collected |
| Personal info, messages, files, contacts | Not collected. Chat text stays in local app storage. |
| App activity | Not collected |
| Device or other IDs | Not collected |

Notes to keep the declaration honest:

- The app has no backend. Model files are fetched directly from
  `huggingface.co`; downloading a file is not “collection” by the developer.
- Android backup is disabled (`android:allowBackup="false"`), so chat history is
  not uploaded to Google’s backup service.
- If you later add analytics, crash reporting, ads, or a cloud feature, update
  this declaration and the privacy policy before shipping.

## Content rating notes

Complete the IARC questionnaire truthfully. Likely answers:

- Violence, sexuality, profanity, drugs, gambling: none in the app itself.
- User-generated content: the app generates text locally; users cannot share it
  with other users and there is no social feed. Answer the questionnaire based
  on that.
- Shares location: no. Purchases: no. Ads: no. Data collection: no.

The resulting rating is typically **Everyone / PEGI 3**. If you add sharing or a
community feature later, re-take the questionnaire.

## AI-generated content declaration

Declare that the app contains generative AI. The policy expectation and the
current risk are described in `README.md` section 5.
