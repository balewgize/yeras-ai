# Google Play release — YerasAI

Package ID: **`com.addislab.yerasai`** (permanent)
Version: **1.0.0 (versionCode 1)**
Min SDK: **24** (Android 7.0) · Target SDK: **36** · 64-bit only (`arm64-v8a`, `x86_64`)

---

## 1. Signing key (do this first)

The upload key was generated at:

```
android/app/upload-keystore.jks
```

Alias: `upload`. Passwords and path live in `android/key.properties` (both files are
gitignored). **Back up `upload-keystore.jks` and `key.properties` to a password
manager or encrypted drive.** Losing the upload key means you cannot publish
updates without going through Play support.

When you create the app in Play Console, keep **Play App Signing** enabled
(the default). Google then holds the app-signing key; the local keystore is only
used to sign uploads.

If you ever need to rebuild these files elsewhere, copy them into place — do not
regenerate a new key for an app that is already published.

## 2. Build the release bundle

```bash
flutter pub get
flutter build appbundle --release --target-platform android-arm64,android-x64
```

Output:

```
build/app/outputs/bundle/release/app-release.aab
```

Two notes:

- `--target-platform android-arm64,android-x64` matters. llama.cpp ships 64-bit
  runtimes only; omitting it produces 32-bit ARM artifacts that would install on
  devices that cannot run a model. A `packaging.jniLibs` rule also strips stray
  32-bit plugin libraries.
- The optional LiteRT runtime is disabled in `pubspec.yaml`
  (`hooks.user_defines.llamadart.llamadart_native_runtimes: llama_cpp`). This
  removes ~130 MB of unused native libraries. Only re-enable it if you add
  `.litertlm` models.

Verify the upload signature before uploading:

```bash
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab | tail -3
```

For a quick device check, build a split APK and install the arm64 one:

```bash
flutter build apk --release --split-per-abi --target-platform android-arm64,android-x64
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## 3. Play Console checklist

1. **Create app** → name `YerasAI`, language English, app (not game), free.
2. **App content**
   - Privacy policy URL: publish `docs/play/privacy-policy.html` (see below).
   - Ads: **No ads**.
   - App access: **All functionality is available without restrictions** (no login).
   - Content rating: complete the IARC questionnaire.
   - Target audience: 13+ (or 18+ if you want to be conservative about generated text).
   - Data safety: **No data collected, no data shared** — see the answers in `play-store-listing.md`.
   - Government apps: No. Financial features: No. Health: No.
   - **Generative AI declaration**: yes, the app generates AI content. See the
     policy risk in section 5.
3. **Store listing**: copy from `play-store-listing.md`; upload
   `assets/branding/play_icon_512.png` and
   `assets/branding/feature_graphic.png`.
4. **Screenshots** (still needed): at least 2 phone screenshots, 16:9 or 9:16,
   between 320 and 3840 px. Capture the real app (chat, model catalog, device
   info, settings). Do not show a model that is not in the catalog.
5. **Release**: upload the AAB to Internal testing first. Install through the
   Play link on the A36 and run the checklist below. Promote to Closed → Open →
   Production once it passes.
6. **Countries**: choose your launch regions. Model downloads go to
   `huggingface.co`; make sure that is acceptable in the regions you ship to.

## 4. Device smoke test (release build)

- [ ] Fresh install shows onboarding; “Get started” reaches the chat screen.
- [ ] Model catalog shows honest fit labels for the device.
- [ ] Download a small model, lock the screen, return: state is resumable (N of X MB), not zero.
- [ ] Chat streams tokens; Stop works.
- [ ] Airplane mode: a real error message appears with a working retry.
- [ ] Delete a single conversation; other conversations remain.
- [ ] Force-stop and relaunch: history and the active chat survive.
- [ ] Theme: light / dark / system all render, no hardcoded colors.
- [ ] App icon: legacy, adaptive (circle/squircle masks), and themed (Android 13) icons.

## 5. Known Play policy risk — read before production

Google Play’s **AI-Generated Content** policy expects apps that generate AI
content to prevent prohibited output and give users a way to report/flag
offensive content. This app runs open models locally with no moderation or
reporting UI. That is a potential review rejection.

Options, in order of effort:

1. Add an in-app “Report output” action and store reports locally (cheap, but
   there is no server to review them — Play may still accept it as a control).
2. Add a lightweight output filter / system prompt guard and document it.
3. Ship to Internal/Closed testing first and see whether the declaration is
   accepted before investing in moderation infrastructure.

Do not claim in the listing that output is filtered or safe if it is not.

## 6. Privacy policy hosting

`docs/play/privacy-policy.html` is a self-contained page. Quickest public URL:

1. Push this repo to GitHub.
2. Settings → Pages → Deploy from branch → `/docs` (or move the file to the
   repository root and use `/root`).
3. Use `https://<user>.github.io/<repo>/play/privacy-policy.html` as the Play
   Console privacy policy URL.

Replace `support@addislab.com` in the policy and listing if you use a different
support address.

## 7. Versioning for future releases

Bump both values in `pubspec.yaml` before every upload:

```yaml
version: 1.0.1+2
```

`1.0.1` is the user-visible version, `2` is `versionCode` and must increase by at
least 1 for every AAB.
