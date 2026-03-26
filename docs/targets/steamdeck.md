# Remote target: Steam Deck

## Access

Configured remote target:
- user: `deck`
- host: `192.168.0.241`

Credentials are **not** stored in-repo.
Use either:
- environment variable: `STEAMDECK_PASS`
- or a local gitignored file: `.env.steamdeck.local`

Helper files:
- `.env.steamdeck.local.example`
- `scripts/steamdeck-run.sh`
- `scripts/steamdeck-scp-to.sh`
- `scripts/steamdeck-scp-from.sh`

Example usage:

```bash
export STEAMDECK_PASS='...'
./scripts/steamdeck-run.sh 'uname -a'
./scripts/steamdeck-scp-to.sh ./local-file /home/deck/local-file
./scripts/steamdeck-scp-from.sh /home/deck/output.log ./artifacts/output.log
```

---

## Detected environment

Connection verified on 2026-03-26.

### OS
- `SteamOS 3.7.19`
- codename: `holo`
- variant: `steamdeck`

### Kernel
- `6.11.11-valve26-1-neptune-611-gb3afa9aa9ae7`

### Architecture
- `x86_64`

### Vulkan stack
From `vulkaninfo`:
- Vulkan instance version: `1.4.303`
- GPU: `AMD Custom GPU 0932 (RADV VANGOGH)`
- driver: `Mesa 24.3.0-devel (git-aef01ebd12)`
- Vulkan driver: `radv`

### Gamescope
- `gamescope version 3.16.14.5`

### Vulkan layers observed
- `VK_LAYER_FROG_gamescope_wsi_x86`
- `VK_LAYER_FROG_gamescope_wsi_x86_64`
- `VK_LAYER_MANGOHUD_overlay_x86`
- `VK_LAYER_MANGOHUD_overlay_x86_64`
- Steam overlay / fossilize layers
- RenderDoc capture layers

---

## Why this target matters

The Steam Deck is a very good early Linux target for this project because it gives us:
- a real native Linux Vulkan environment
- AMD / RADV behavior
- real `gamescope` availability
- realistic handheld / LSFG-adjacent use cases

It is especially useful for:
- pass-through Vulkan layer validation
- swapchain interception tests
- frame insertion smoke tests
- observing interaction with `gamescope`

It is less useful for:
- NVIDIA-specific acceleration paths
- proprietary driver behavior comparisons

---

## Recommended first tests on this target

1. Pass-through layer smoke test
   - `vkcube`
   - `vkgears`

2. Placeholder frame insertion test
   - duplicate-frame insertion
   - blend-frame insertion

3. Nested `gamescope` compatibility test
   - compare direct run vs nested `gamescope`

4. Proton sample title
   - verify layer still loads and presents correctly
