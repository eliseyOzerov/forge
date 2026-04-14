# Forge Roadmap

Forge is a cross-platform native UI framework driven by the needs of the Wave app.
Scope is gated on "Wave actually needs this" — speculative surface area waits.

## Strategic milestones

1. **M1 — iOS framework feature-complete for Wave**
2. **M2 — Wave shipped on iOS** (framework validated in production)
3. **M3 — Forge ported to Android** (portable abstractions pay off)
4. **M4 — Wave shipped on Android** (proves the portability claim)
5. **M5 — Fundraising window opens** (grants / sponsors / consulting)

No public launch, no open-sourcing push, no fundraising motion before M4.

---

## M1 — iOS framework for Wave

Four parallel tracks. Theming lands first (small, unblocks component polish);
then components and platform abstractions run in parallel.

### Track A — Theming

- [x] ColorTheme + 12-hue palette generation
- [ ] SpacingTheme (xxs–xl5)
- [ ] TextTheme (font stacks, size ramp, weights)
- [ ] SurfaceTheme (radius, elevation)
- [ ] ButtonTheme (height, padding)
- [ ] IconTheme (sizing)
- [ ] AvatarTheme
- [ ] InputTheme
- [ ] DividerTheme
- [ ] System brightness listener + animated theme transitions

### Track B — Components

**Built:** Text, Image, Icon, Surface, SVG, Loader, Graphic, Box, Flex,
Button, TextField, Toggle, Stepper, Slider, Plane.

- [ ] Segmented control (discrete snap on a line)
- [ ] Range slider (two-thumb)
- [ ] Masked TextField / OTP-style segmented input (birthday, codes)
- [ ] Chip
- [ ] Tile
- [ ] Skeleton loader
- [ ] Progress indicator (determinate + indeterminate)
- [ ] Knob / Gauge (rotary input)
- [ ] Radial hue picker
- [ ] 2D color plane (saturation × brightness)
- [ ] Map
- [ ] Video player
- [ ] Audio player (voice messages)

### Track C — Navigation, overlays, motion

- [ ] Router abstraction
- [ ] Toolbar / Navbar
- [ ] Sheet
- [ ] Alert
- [ ] Popover
- [ ] Effects system (transform, fade, blur, scale, slide; compoundable)
- [ ] Lift / shared-element transitions
- [ ] Enter / exit transitions

### Track D — Platform abstractions

Portable protocols in core, iOS adapters in the platform layer.
Same discipline as Canvas / Color / Filter.

- [ ] HTTP / WebSocket client
- [ ] File storage
- [ ] Key-value storage
- [ ] Local database
- [ ] Location
- [ ] Camera
- [ ] File / media picker
- [ ] NFC
- [ ] Encryption
- [ ] Push notifications
- [ ] Deep links
- [ ] Authentication

### Track E — Cleanup (ongoing)

- [ ] Move remaining style/config types outside `#if canImport(UIKit)`
- [ ] Remove `Path.stroked` CG overload
- [ ] Finish Surface → Canvas migration (FadeLayer / BlendLayer group compositing)

### M1 exit criteria

- Every Wave screen can be built without dropping into UIKit
- No CG / UIKit types leak through portable APIs
- Theme switching is animated and responds to system brightness

---

## M2 — Wave on iOS

- [ ] Port Wave screens onto Forge
- [ ] Stabilize APIs under production use (breaking changes allowed here; this
      is the last window before porting)
- [ ] Ship to App Store

---

## M3 — Forge on Android

- [ ] Pick host language / rendering layer (Kotlin + Compose runtime, or
      Kotlin + Skia/Canvas direct — decide at M3 start)
- [ ] Port core: Node, View, Binding, Observable, Provider
- [ ] Port portable primitives (Canvas, Color, Animation, Path, Filter)
- [ ] Port components in the order Wave uses them
- [ ] Port platform abstractions against Android APIs

Any CG / UIKit leak found during this phase is a receipt for M1 discipline
failing — fix at the source in core, not in the Android adapter.

---

## M4 — Wave on Android

- [ ] Reuse Wave screen code unchanged (the portability claim)
- [ ] Ship to Play Store

---

## M5 — Fundraising

Earliest realistic window. Likely paths:

- NLnet / Sovereign Tech Fund grants
- GitHub Sponsors
- Consulting around the framework

Avoid VC unless a separate commercial product makes sense.
