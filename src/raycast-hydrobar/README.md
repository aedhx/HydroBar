# HydroBar for Raycast

Log a glass of water without leaving the keyboard. This extension drives [HydroBar](https://hydrobar.adx.cool/), the hydration tracker that lives in your Mac's menu bar.

Type a command, press Return: the ring in your menu bar moves and a small "+250 ml" appears under it. HydroBar's window never opens.

## Commands

| Command | What it does |
|---|---|
| **Add Water – Preset 1** | Logs your first preset |
| **Add Water – Preset 2** | Logs your second preset |
| **Add Water – Preset 3** | Logs your third preset |
| **Add Water (Custom)** | Logs the amount you type, in milliliters, from 1 to 5000 |
| **Undo Last Water** | Removes the last drink you logged |
| **Open HydroBar Statistics** | Opens HydroBar on its statistics |

The preset commands use the amounts set in HydroBar › Settings › Hydration. Change a preset there and the command follows.

## Requirements

- **HydroBar 2.0 or later**, from the [direct download](https://github.com/aedhx/HydroBar/releases/latest) or the Mac App Store. It doesn't need to be running: macOS launches it when a command needs it.
- **[Raycast](https://www.raycast.com/)**.
- **[Node.js](https://nodejs.org/) 22 or later**, to install the extension. It isn't on the Raycast Store yet.

## Install

```bash
git clone https://github.com/aedhx/HydroBar.git
cd HydroBar/src/raycast-hydrobar
npm install
npm run dev
```

`npm run dev` adds the extension to Raycast. Once the commands show up when you search for "HydroBar", stop it with Control-C: the extension stays installed.

Prefer not to clone? Download `hydrobar-raycast-extension.zip` from the [Releases](https://github.com/aedhx/HydroBar/releases) page, unzip it, and run the last two commands in the `raycast-hydrobar` folder.

**To update**, pull or download the new version and run `npm install && npm run dev` again.

**To remove it**, open Raycast › Settings › Extensions, right-click HydroBar and choose Uninstall Extension.

## Make it faster

In Raycast › Settings › Extensions › HydroBar, each command can have:

- an **alias**, such as `w1`, so that typing `w1` and Return logs your first preset;
- a **hotkey**, to log a glass from anywhere without opening Raycast at all.

HydroBar has its own global shortcuts too (Settings › Shortcuts). Use whichever you prefer; they do the same thing.

## If something doesn't work

**Nothing happens.** Check that HydroBar is version 2.0 or later (Settings › General) and that you've opened it at least once since installing it: macOS only learns about its links on first launch.

**"Could not reach HydroBar".** Raycast couldn't open the link at all. HydroBar isn't installed, or is older than 2.0.

**The toast says "Added" but the ring didn't move.** The toast confirms that the request was sent, not that it was accepted: these links can't answer back. When HydroBar turns a request down, for example an amount out of range or nothing left to undo, it says so itself in a notification. That needs notifications to be allowed for HydroBar in System Settings.

**The commands don't show up.** Run `npm run dev` again in the extension's folder, then search for "HydroBar" in Raycast.

## How it works

Each command opens a `hydrobar://` link, which HydroBar handles:

| Command | Link |
|---|---|
| Add Water – Preset 1, 2, 3 | `hydrobar://add?preset=1`, `2`, `3` |
| Add Water (Custom) | `hydrobar://add?ml=250` |
| Undo Last Water | `hydrobar://undo` |
| Open HydroBar Statistics | `hydrobar://open/stats` |

The same links work from Alfred, Keyboard Maestro, a Stream Deck or Terminal (`open "hydrobar://add?ml=250"`), and they accept other units (`?cl=25`, `?l=0.25`, `?oz=8`).

Two links are left out on purpose: `reset` and `set-goal` change your day or your goal, so HydroBar asks for a confirmation in the app before running them. They wouldn't save you a step from Raycast.

The full grammar, the security model and the error codes are in [the deep links spec](https://github.com/aedhx/HydroBar/blob/main/docs/specs/DEEP_LINKS.md) (in French).

## Development

```bash
npm run dev     # load the extension in Raycast, with live reload
npm run build   # production build into dist/
npm run lint    # Raycast's linter (needs a Raycast account)
```

Each command is one file in `src/`, named after its entry in `package.json`. The repository's CI type-checks the extension and fails if a command and its file don't match.

To build the zip attached to releases, run `./src/scripts/package-raycast-extension.sh`. It leaves out `node_modules` and `dist`.

## License

MIT, like [HydroBar](https://github.com/aedhx/HydroBar).
