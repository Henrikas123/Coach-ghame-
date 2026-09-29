# Coach Academy

Roblox boksininkų / kovotojų trenerių akademijos tycoon.

- `CoachAcademy_active2_checkpoint.rbxl` — originalus checkpoint.
- `CoachAcademy_panels.rbxl` — checkpoint su HUD panelėmis (Profilis, Akademija, Personalas, Skautai, Rėmėjai, Turnyrai, Telefonas).
- `src/` — naujas ir pakeistas Luau kodas (Rojo stiliaus struktūra: `*.server.lua`, `*.client.lua`).
- `tools/build_place.luau` — surenka `CoachAcademy_panels.rbxl` iš checkpoint + `src/` (`lune run tools/build_place.luau`).
- `tools/ui-preview/` — Roblox mock + renderer: paleidžia tikrą serverio ir kliento kodą be Studio, daro ekrano nuotraukas ir tikrina srautus.

Išsamiau: [docs/HUD_PANELS.md](docs/HUD_PANELS.md).
