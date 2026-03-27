# Real-game compatibility journal

Tracked notes for Steam Deck real-game OMFG runs.

Purpose:
- keep per-game/appid history of what was tried
- record the repo snapshot / commit involved
- preserve good and bad log snippets that informed decisions
- capture wrapper contents / launch assumptions that mattered
- avoid repeating dead-end experiments

## Games
- `960990` — [Beyond: Two Souls](./960990-beyond-two-souls.md)
- `1196590` — [Resident Evil Village](./1196590-resident-evil-village.md)

## Current shared wrapper shape
Deck-side wrapper path:
- `~/omfg.sh`

Known working core contents during the real-game compatibility investigation:

```bash
#!/usr/bin/env bash
set -euo pipefail
BASE=/home/deck/post-proc-fg-research
if [[ -n "${PRESSURE_VESSEL_FILESYSTEMS_RW:-}" ]]; then
  export PRESSURE_VESSEL_FILESYSTEMS_RW="${BASE}:${PRESSURE_VESSEL_FILESYSTEMS_RW}"
else
  export PRESSURE_VESSEL_FILESYSTEMS_RW="${BASE}"
fi
export VK_LAYER_PATH="${BASE}/deploy/vk-layer-rust"
export VK_INSTANCE_LAYERS="VK_LAYER_OMFG_rust"
export ENABLE_OMFG_RUST=1
export OMFG_LAYER_MODE="${OMFG_LAYER_MODE:-reproject-blend}"
export OMFG_REPROJECT_SEARCH_RADIUS="${OMFG_REPROJECT_SEARCH_RADIUS:-2}"
export OMFG_REPROJECT_PATCH_RADIUS="${OMFG_REPROJECT_PATCH_RADIUS:-1}"
export OMFG_REPROJECT_CONFIDENCE_SCALE="${OMFG_REPROJECT_CONFIDENCE_SCALE:-4.0}"
export OMFG_REPROJECT_DISOCCLUSION_CURRENT_BIAS="${OMFG_REPROJECT_DISOCCLUSION_CURRENT_BIAS:-0.75}"
export OMFG_LAYER_LOG_FILE="${BASE}/logs/re8-omfg.log"
mkdir -p "${BASE}/logs"
rm -f "${OMFG_LAYER_LOG_FILE}"
exec "$@"
```

## Important compatibility finding
Commit:
- `273d171` — `fix: gate timing injection for real game compatibility`

Meaning:
- OMFG no longer appends timing extensions/features during `vkCreateDevice` by default
- explicit timing validation still opts back in when needed
- this fixed the earlier real-game `vkCreateDevice returned -13` failures in Proton titles
