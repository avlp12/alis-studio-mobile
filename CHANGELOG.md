# Changelog

## v0.1.1

- Block unsupported hardware: devices with less than 8 GB of RAM now show an
  "unsupported device" screen instead of generating (the model would otherwise
  jetsam-kill the app). Enforced at runtime via `ProcessInfo.physicalMemory`.
- README: add real on-device screenshots (generate + gallery) and a thorough
  minimum-requirements section (RAM, iOS, storage, network, real-device-only).
- First-run "keep the screen on" hint in the download UI.

## v0.1.0 — initial separate release

First standalone release of Alis Studio Mobile, split out of the throwaway
measurement spike into its own repository.

- Native SwiftUI iOS app (iOS 17+), Alis Studio design language (clay accent,
  cream surfaces, pine mark, light + dark).
- On-device text-to-image via MLX Swift at 512².
- Models: SDXL-Turbo (4-bit UNet + `sdxl-vae-fp16-fix`) and SD-Turbo
  (4-bit UNet + fp16 VAE); runtime model picker.
- Adjustable steps, Stop (mid-generation cancel), on-device Gallery
  (save / reuse-prompt / delete).
- Memory tuning validated on iPhone 16 Pro Max (8 GB): VAE-decode is the peak;
  fp16-stable VAE + 4-bit UNet + per-generation cache clear keep SDXL stable at
  ~4.25 GiB and SD-Turbo at ~3.4 GiB.
- `Sources/StableDiffusion/` vendored from Apple's mlx-swift-examples with
  additions: SD-Turbo preset, external fp16-fix VAE loading, configurable UNet
  bits, lazy MLX initialization.
- Project generated with XcodeGen (`project.yml`).
