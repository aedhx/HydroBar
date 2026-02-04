# HydroBar – Raycast Extension

Control [HydroBar](https://github.com/aedhx/HydroBar) (macOS menu bar hydration app) from Raycast.

## Requirements

- **macOS**
- [HydroBar](https://github.com/aedhx/HydroBar) installed and running (menu bar)
- [Raycast](https://www.raycast.com/)

## Commands

| Command | Description |
|--------|-------------|
| **Add Water – Preset 1** | Log your first preset amount (e.g. small glass) |
| **Add Water – Preset 2** | Log your second preset amount |
| **Add Water – Preset 3** | Log your third preset amount |
| **Add Water (Custom)** | Log a custom amount in ml (e.g. `250`) |

HydroBar must be running for the URL scheme `hydrobar://` to work. If it isn’t, the extension will show a toast.

## Install in Raycast

1. Clone or copy this folder and run `npm install` in it.
2. In Raycast: **Settings → Extensions → Add Extension → Add from folder** → select the `raycast-hydrobar` folder.
3. **Important:** Open a terminal, go to the `raycast-hydrobar` folder and run:
   ```bash
   npm run dev
   ```
   This imports the extension into Raycast and makes the commands appear. Leave this terminal open while you use the extension (or stop it with Ctrl+C — the commands stay available).
4. In Raycast, search for **"HydroBar"** or **"Add Water"** to see the commands.

## Icons

Extension: `assets/icon.png`. Commands: `preset-0.3.png`, `preset-0.5.png`, `preset-1.png`, `custom.png` in `assets/` (each 512×512 PNG). **If icons don’t show:** Quit Raycast completely (Quit Raycast from menu bar), then reopen; run `npm run build` then `npm run dev` again.

Place a 512×512 PNG as `assets/icon.png` (optional). You can use [HydroBar’s icon](https://github.com/aedhx/HydroBar/blob/main/Resources/HydroBar-icon.png) resized to 512×512.

## How it works

The extension opens URLs that HydroBar handles:

- `hydrobar://add/preset/0` → preset 1  
- `hydrobar://add/preset/1` → preset 2  
- `hydrobar://add/preset/2` → preset 3  
- `hydrobar://add?ml=250` → custom amount in ml  

See [HydroBar](https://github.com/aedhx/HydroBar) for the app and source.

---

## Distribution

To package the extension for distribution (e.g. to attach to a GitHub Release):

From the **repository root** (parent of `raycast-hydrobar`), run:

```bash
./package-raycast-extension.sh
```

This creates `hydrobar-raycast-extension.zip` in the repo root, excluding `node_modules` and build artifacts. Recipients should:

1. Unzip the archive
2. `cd raycast-hydrobar && npm install`
3. In Raycast: **Settings → Extensions → Add Extension → Add from folder** → select the `raycast-hydrobar` folder
4. Run `npm run dev` in the extension folder so Raycast picks up the commands
