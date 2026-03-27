# 960990 — Beyond: Two Souls

## Identity
- AppID: `960990`
- Executable seen in logs: `BeyondTwoSouls_Steam.exe`
- Engine seen in logs:
  - `DXVK`

## Status
Status: **partially improved, but still not good enough**.

What is fixed:
- the old hard startup/device-creation failure is gone after commit `273d171`

What is still wrong:
- with active OMFG generated-frame modes, the game appears to sit on a black/frozen screen and does not make sustained forward progress

## Original failure signature
Before the timing-injection fix, the key failure was:

```text
app=BeyondTwoSouls_Steam.exe; engine=DXVK
vkCreateDevice returned -13
```

That matched the same family of startup failure seen in RE Village before the fix.

## What improved after the fix
After commit `273d171`, the game now gets past the old startup blocker:

```text
app=BeyondTwoSouls_Steam.exe; engine=DXVK
vkCreateDevice ok
```

So the first compatibility fix was real and necessary.

## New evidence from direct Deck investigation
### With default active OMFG mode (`reproject-blend`)
Observed in OMFG log after ~45s while the process stayed alive:

```text
app=BeyondTwoSouls_Steam.exe; engine=DXVK; apiVersion=1.3.0
vkCreateDevice ok; gpu=AMD Custom GPU 0932 (RADV VANGOGH)
vkCreateSwapchainKHR ok; extent=1280x800; format=37; presentMode=MAILBOX; minImages=4->6; usage=TRANSFER_SRC|TRANSFER_DST|STORAGE|COLOR_ATTACHMENT (0x1b) -> TRANSFER_SRC|TRANSFER_DST|SAMPLED|STORAGE|COLOR_ATTACHMENT (0x1f); images=6; mode=reproject-blend-test
vkQueuePresentKHR frame=1; queueFamily=0; imageIndex=0; waitSemaphores=1
reproject-blend primed previous frame history
vkQueuePresentKHR frame=2; queueFamily=0; imageIndex=1; waitSemaphores=1
first reproject blended generated-frame present succeeded
reproject blended frame present=1; generatedImageIndex=2; currentImageIndex=1
vkQueuePresentKHR frame=3; queueFamily=0; imageIndex=3; waitSemaphores=1
reproject blended frame present=2; generatedImageIndex=4; currentImageIndex=3
```

At the same time, the process tree remained alive:
- live Steam `AppId=960990`
- live Proton process chain
- live `wineserver`
- live `BeyondTwoSouls_Steam.exe`

Interpretation:
- the game is no longer crashing at startup
- OMFG is no longer blocked at `vkCreateDevice`
- the game reaches swapchain creation and the first few presents
- but it does **not** continue into sustained present activity under active FG mode

### With OMFG passthrough
A controlled wrapper test forcing `OMFG_LAYER_MODE="passthrough"` showed sustained present activity for the same game:

```text
vkCreateSwapchainKHR ok; extent=1280x800; format=37; presentMode=MAILBOX; minImages=4->4; usage=TRANSFER_SRC|TRANSFER_DST|STORAGE|COLOR_ATTACHMENT (0x1b) -> TRANSFER_SRC|TRANSFER_DST|STORAGE|COLOR_ATTACHMENT (0x1b); images=4; mode=passthrough
vkQueuePresentKHR passthrough frame=1
...
vkQueuePresentKHR passthrough frame=60
...
vkQueuePresentKHR passthrough frame=300
...
vkQueuePresentKHR passthrough frame=1620
```

Interpretation:
- the wrapper itself is not the problem
- the layer loading into Beyond is not the problem
- the game can sustain present traffic with OMFG loaded when OMFG is not mutating/inserting generated frames
- the remaining issue is tied to **active generated-frame behavior**, not to basic layer presence

### With another active FG mode (`multi-blend`)
A second controlled wrapper test forcing `OMFG_LAYER_MODE="multi-blend"` showed the same general early-progress-then-stall pattern:

```text
vkCreateSwapchainKHR ok; extent=1280x800; format=37; presentMode=MAILBOX; minImages=4->7; usage=TRANSFER_SRC|TRANSFER_DST|STORAGE|COLOR_ATTACHMENT (0x1b) -> TRANSFER_SRC|TRANSFER_DST|SAMPLED|STORAGE|COLOR_ATTACHMENT (0x1f); images=7; mode=multi-blend-test
vkQueuePresentKHR frame=1
multi-blend primed previous frame history
vkQueuePresentKHR frame=2
first multi blended generated-frame present succeeded
multi blended frame present=2; generatedImageIndices=[2, 3]; currentImageIndex=1
vkQueuePresentKHR frame=3
multi blended frame present=4; generatedImageIndices=[5, 6]; currentImageIndex=4
```

Interpretation:
- this is probably **not only** a reprojection-specific shader problem
- the shared failure pattern appears across more than one active FG mode
- likely suspects now include:
  - generated-frame insertion/present sequencing on this title
  - swapchain image-count mutation (`4 -> 6` / `4 -> 7`)
  - added sampled usage on this swapchain path
  - MAILBOX-specific behavior in this title under active FG insertion

## Current best understanding
Most evidence-backed statement right now:
- **Beyond: Two Souls works with OMFG loaded in passthrough, but stalls shortly after active generated-frame modes begin presenting.**

That is much narrower and better than the old situation.

## Next evidence-based debugging directions
Prefer these over blind guesses:
1. compare simple generated modes (`copy`, `history-copy`, `clear`, `bfi`) against Beyond to separate:
   - extra present insertion
   - swapchain mutation
   - shader sampling/reprojection
2. isolate whether the stall is tied to:
   - extra images only
   - sampled-usage mutation only
   - generated presents before original present ordering
3. capture per-run notes with:
   - exact wrapper contents
   - exact mode
   - exact commit
   - log snippet showing last successful present

## Repo snapshot
Key compatibility fix already landed in:
- `273d171` — `fix: gate timing injection for real game compatibility`

The Beyond-specific black-screen/stall issue remains open after that fix.
