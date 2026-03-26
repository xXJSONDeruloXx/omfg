# Implementation status

## Summary

We now have a **working Linux Vulkan layer MVP** with successful remote runtime validation on the Steam Deck.

This is beyond paper architecture at this point.

## Current status

### Working
- explicit Vulkan layer negotiation / loading
- instance/device/swapchain/present interception
- queue tracking
- swapchain mutation for extra image capacity
- remote build + deploy loop
- remote smoke test loop on Steam Deck
- log capture back into local artifacts

### Verified runtime modes on Steam Deck

#### 1. `passthrough`
Working.

Validated with:
- `vkcube --c 120`

Observed:
- 120 real presents completed cleanly
- swapchain creation and present logging correct
- no crashes / no hangs

#### 2. `clear`
Working.

Validated with:
- `vkcube --c 120`

Observed:
- 120 real presents completed cleanly
- 120 generated placeholder presents completed cleanly
- extra frame insertion proven on real Linux hardware

#### 3. `copy`
Working and currently the best MVP mode.

Validated with:
- `vkcube --c 120`

Observed:
- 120 real presents completed cleanly
- 120 duplicated generated-frame presents completed cleanly
- swapchain image count bumped from 3 -> 5
- usage flags bumped to include `TRANSFER_SRC` + `TRANSFER_DST`
- per-frame copy from source app image into generated swapchain image succeeded across the full run

This is the current strongest proof that the project direction is viable.

---

## Important technical insight from implementation

### The stable duplicate-frame path was:
- increase swapchain image count
- acquire an extra image for the generated frame
- copy the source present image into that acquired image
- present original + generated frame on the same queue
- use conservative synchronization and queue idle in test mode

That is not final-product pacing, but it is a real, working insertion path.

---

## Remaining gap to true frame generation

Right now the layer can do:
- **post-process frame insertion**
- **duplicate-frame generation**

It still cannot do:
- **interpolated frame generation**

So the next major milestone is replacing duplicate copy with:
- optical-flow / warp / blend / inpaint logic

---

## Artifacts

### vkcube
- `artifacts/steamdeck/vkcube/passthrough/ppfg-vkcube.log`
- `artifacts/steamdeck/vkcube/clear/ppfg-vkcube.log`
- `artifacts/steamdeck/vkcube/copy/ppfg-vkcube.log`

### vkgears
- `artifacts/steamdeck/vkgears/clear/ppfg-vkgears.log`

---

## Notable unresolved item

### `vkgears`
Under the current remote test setup, `vkgears` is not yet a useful validation target.

Observed behavior:
- layer negotiation occurs
- the process times out under the remote harness
- we do not yet get the same clean create-device / create-swapchain / present trace as `vkcube`

That means `vkcube` is currently the reliable smoke-test target.

---

## Recommendation

The project has now crossed from:
- research only

to:
- working Linux runtime MVP with duplicate generated-frame insertion

The next best implementation step is:

## **add a real generated-frame backend behind the existing `copy` mode infrastructure**

Meaning:
- keep the current queue/swapchain/present path
- replace raw copy with interpolation logic
