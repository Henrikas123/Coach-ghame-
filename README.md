# Coach Academy

Roblox boxing coach academy tycoon, by Henyte.

- `CoachAcademy_panels.rbxl` — ready-to-open place: loading screen, title screen, HUD and all panels (English).
- `CoachAcademy_active2_checkpoint.rbxl` — original checkpoint the build starts from.
- `src/` — all game scripts (Rojo-style names: `*.server.lua`, `*.client.lua`).
- `assets/icons/` — HUD icon PNGs to upload to Roblox (ids go into `IconConfig.lua`).
- `tools/build_place.luau` — builds `CoachAcademy_panels.rbxl` from the checkpoint + `src/` (`lune run tools/build_place.luau`).
- `tools/ui-preview/` — Roblox mock + renderer: runs the real server and client code without Studio, takes screenshots and checks flows.

Details (Lithuanian): [docs/HUD_PANELS.md](docs/HUD_PANELS.md).
