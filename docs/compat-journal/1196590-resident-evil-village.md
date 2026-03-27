# 1196590 — Resident Evil Village

## Identity
- AppID: `1196590`
- Executable seen in logs: `re8.exe`
- Engines seen in logs:
  - `DXVK`
  - `vkd3d`

## Main outcome
Status: **working with OMFG after the timing-injection fix**.

Validated repo snapshot:
- commit `273d171` and later

## Original failure signature
Before the fix, the key symptoms were:
- user-visible error: `D3D12CreateDeviceFailed`
- OMFG log reached instance creation, then failed in device creation

Bad log snippets that informed the diagnosis:

```text
app=re8.exe; engine=DXVK
app=re8.exe; engine=vkd3d
vkCreateDevice returned -13
```

Interpretation:
- the layer was loading into the game
- the failure happened after `vkCreateInstance`
- the failure happened before swapchain/present
- both DXVK and VKD3D paths were affected

## Root-cause experiment that proved the issue
Temporary wrapper-only experiment:
- `OMFG_CREATE_DEVICE_APPEND_TIMING_EXTENSIONS=0`
- `OMFG_CREATE_DEVICE_APPEND_TIMING_FEATURES=0`

That immediately changed the outcome from device-create failure to successful device creation and present activity.

Good log snippets from the successful experiment:

```text
app=re8.exe; engine=DXVK
vkCreateDevice ok
app=re8.exe; engine=vkd3d
vkCreateDevice ok
vkCreateSwapchainKHR ok
first reproject blended generated-frame present succeeded
reproject blended frame present=...
```

Interpretation:
- the failure was tied to OMFG timing extension / feature injection during `vkCreateDevice`
- the base interception, swapchain mutation, and generated-frame path were not the root problem

## Final fix
Committed in:
- `273d171` — `fix: gate timing injection for real game compatibility`

Behavior after the fix:
- timing extension/feature injection is **off by default** for real games
- explicit timing validation scripts opt back in when needed

## Confirmed post-fix behavior
Dedicated Deck rerun showed:

```text
app=re8.exe; engine=DXVK; ... vkCreateDevice ok
app=re8.exe; engine=vkd3d; ... vkCreateDevice ok
vkCreateSwapchainKHR ok
first reproject blended generated-frame present succeeded
reproject blended frame present=300
```

Additional runtime evidence:
- live `re8.exe` process observed during validation
- live Proton chain observed during validation
- live `wineserver` observed during validation

## Practical note
As of the validated fix, RE Village is the current proof point that OMFG can:
- load in a real Proton game
- survive both DXVK and VKD3D startup paths
- create the swapchain
- generate and present interpolated frames in-game
