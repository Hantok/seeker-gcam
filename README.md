# GCam for Solana Seeker (BSG MGC 9.4.103 V41, patched)

Every recent BSG GCam build (8.9 → 9.7) crashes on the Seeker's **front camera** and the **0.7× ultrawide**.
This is BSG MGC 9.4.103 V41 with four small smali patches that fix it. Nothing else in the APK is touched
(native libs, assets and resources are byte-identical to BSG's release).

## What works

| Lens | Photo | Pipeline |
|---|---|---|
| Main 1× | 12 MP (4000×3000) | RAW16 HDR+ |
| Ultrawide 0.7× | 12.6 MP (4096×3072) | YUV HDR+ |
| Tele 2× | 12.2 MP (4032×3024) | YUV HDR+ |
| Front | 8 MP (3264×2448) | YUV HDR+ |

Night Sight and Portrait (front and rear), video 4K / 1080p on the rear, 1080p on the front.
GCam can be the double-press-power camera.

Tested on Seeker, Android 16 (BP2A.261008.100.A3).

## Why stock BSG crashes

The Seeker's front and ultrawide sensors have no RAW capability, so the camera HAL omits
`android.control.postRawSensitivityBoostRange` for them. Two places assume that key always exists:

- BSG's `com.a.loadConfinesExposureISO()` (runs on every camera open) → `NullPointerException`
- Google's metadata getter (`ndv.o()`, manual-ISO range) → `CameraMetadata missing value for key`

Separately, BSG's "unsupported device" check in `hcm.onCreate` reads an injected field before it is
injected, so GCam crashes whenever it is opened through the camera intent (double-press power,
lock-screen camera shortcut, "open camera" from other apps).

## Patches (`patches/`)

| Patch | Change |
|---|---|
| `01-com.a-loadConfinesExposureISO` | null-safe: missing boost range → 1.0 (no boost) |
| `02-tp-synthesize-postRawBoostRange` | lowest-level characteristics getter returns `Range[100,100]` (the spec's "no boost" value) when the key is absent |
| `03-NoiseModels0-integrity-gate` | BSG's tamper check (SHA-1 of `META-INF/BSG.RSA`) → its own success path; required because the APK is re-signed |
| `04-hcm-inject-before-check` | run the (idempotent) injector before BSG's device check |

## Install

1. Uninstall any existing BSG/GCam with package `org.codeaurora.snapcam` (the signature differs; an update will fail).
2. Install `MGC_9.4.103_V41_seeker-patched.apk` and grant Camera, Microphone and Photos/Videos.
3. Copy `seeker-config.xml` to `Download/MGC_CONFIG/9.4.103/` on the phone, then in GCam:
   Settings → Configs → Load → `seeker-config.xml`. It sets full resolution on every lens
   (Camera photo resolution = "RAW format resolution", front YUV input 3264×2448).
4. Optional: 4K video in the video quick-settings panel.
5. Optional: Android Settings → "Double press power button" → Camera, then pick this GCam → Always.

On BSG's first-launch popup tap **Done** — "Close forever (ads)" opens an ad website.

## Build it yourself

```
./rebuild.sh /path/to/MGC_9.4.103_V41_snap.apk
```

Needs Java 17+ and Android build-tools (`zipalign`, `apksigner`); signs with your `~/.android/debug.keystore`.
The dex files it produces are byte-identical to the released APK, so you can verify the release yourself.

## Credits

BSG for MGC. This repo only fixes Seeker-specific crashes. Unofficial; use at your own risk.
