# Alis Studio Mobile

On-device, native image generation for **iPhone** — a SwiftUI app that runs
text-to-image diffusion models entirely on the device with
[MLX Swift](https://github.com/ml-explore/mlx-swift). No cloud, no accounts;
your images never leave the phone.

The mobile sibling of [Alis Studio](https://github.com/avlp12/alis-studio) (the
Mac desktop app), sharing its design language — clay accent, cream surfaces, the
pine mark, light + dark.

## What it runs (validated on iPhone 16 Pro Max, 8 GB)

| Model | Config | Peak resident | Stability | Quality |
|-------|--------|---------------|-----------|---------|
| **SDXL-Turbo** | 4-bit UNet · `sdxl-vae-fp16-fix` · 2–4 steps | ~4.25 GiB | stable | highest (photorealistic) |
| **SD-Turbo** | 4-bit UNet · fp16 VAE · 4 steps | ~3.4 GiB | stable | good, fastest |

Both fit comfortably under the 8 GB device's jetsam limit at 512². Key levers
(found via on-device measurement): the VAE decode activation is the memory peak,
so SDXL uses the fp16-stable VAE; the UNet is 4-bit; the MLX cache is cleared
between generations to avoid accumulation.

## Features

- Prompt → 512² image, fully on-device (MLX Metal)
- Model picker — SDXL-Turbo / SD-Turbo
- Adjustable steps; Stop (cancels mid-generation)
- Gallery — generations saved on device, reuse-prompt / delete
- Light + dark, matching Alis Studio

## Build

Requires Xcode 16+, an iOS 17+ device, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodegen generate          # creates AlisStudioMobile.xcodeproj from project.yml
open AlisStudioMobile.xcodeproj
```

Then set your signing Team and run on a physical device (MLX has no Metal in the
Simulator, so generation requires real hardware). First launch downloads the
model weights from Hugging Face.

CLI build/install (device id from `xcrun devicectl list devices`):

```sh
xcodegen generate
xcodebuild -scheme AlisStudioMobile -configuration Release \
  -destination 'platform=iOS,id=<DEVICE_ID>' \
  -allowProvisioningUpdates DEVELOPMENT_TEAM=<TEAM_ID> build
xcrun devicectl device install app --device <DEVICE_ID> <built .app>
```

## License

MIT — see [LICENSE](LICENSE). `Sources/StableDiffusion/` is adapted from Apple's
mlx-swift-examples (MIT).
