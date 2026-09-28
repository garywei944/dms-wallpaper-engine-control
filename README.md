# Wallpaper Engine Control

A [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) bar widget for
[linux-wallpaperengine](https://github.com/Almamu/linux-wallpaperengine): see what every monitor
shows, skip to the next playlist item, pause, or stop the renderers to free GPU memory.

![Panel with one card per monitor](screenshot.png)

It works with the renderer as shipped. No patched build is needed.

## Features

- One card per monitor, laid out as the monitors stand: left to right, portrait and ultrawide
  shapes, and balanced rows beyond three screens. Each card shows the Workshop preview and title
  of the wallpaper on screen and has its own **next** button.
- **Next** crossfades to another random item of the monitor's playlist.
- **Pause** freezes the current frame with no GPU load and resumes instantly.
- **Stop** ends every renderer and reports the GPU memory it released. Wallpapers then stay off,
  across logins too, until you start them again.
- Wallpapers start when DMS starts, start on a monitor you plug in, and stop on a monitor you
  unplug.

## Requirements

- Hyprland: monitors, layer surfaces and the pause window are read through `hyprctl`.
- DankMaterialShell 1.6.2 or newer.
- `linux-wallpaperengine`, Python 3.10 or newer, `zenity`, and a systemd user session.
- Optional: the [linux-wallpaper-engine](https://github.com/jagrat7/linux-wallpaper-engine) app
  to choose wallpapers and playlists, and `nvidia-smi` for the released-memory figure.

Tested on Hyprland 0.56.2 with DMS 1.6.2 and linux-wallpaperengine `b016d7d`, on three 4K
monitors plus Hyprland headless outputs for hotplug, portrait and spanned setups.

## Install

Clone the plugin into the DMS plugin directory and restart DMS:

```sh
git clone https://github.com/garywei944/dms-wallpaper-engine-control \
  ~/.config/DankMaterialShell/plugins/wallpaperEngineControl
dms restart
```

Then enable **Wallpaper Engine Control** under Settings → Plugins and add it to the bar.

### Window rule for pause

linux-wallpaperengine stops rendering while any window is fullscreen. Pause uses that by opening
a small `zenity` window titled `wallpaper-engine-pause`; this rule parks it, fullscreen, on a
hidden special workspace.

Hyprland 0.56 or newer, `hyprland.lua`:

```lua
hl.window_rule({
    match = { class = "^zenity$", title = "^wallpaper-engine-pause$" },
    workspace = "special:wallpaper-engine-pause silent",
    fullscreen = true,
    no_focus = true,
    no_anim = true,
})
```

`hyprland.conf` (Hyprland 0.53 and newer):

```ini
windowrule = match:class ^zenity$, match:title ^wallpaper-engine-pause$, workspace special:wallpaper-engine-pause silent, fullscreen on, no_focus on, no_anim on
```

Renderers started with `--no-fullscreen-pause` or `--fullscreen-pause-only-active` cannot be
paused this way.

## Choosing wallpapers

The widget keeps each monitor on whatever you last ran there. Apply a wallpaper or a playlist to
every monitor once, with the linux-wallpaper-engine app or by starting `linux-wallpaperengine
--screen-root <output> --playlist <name>` yourself. The widget learns the launch arguments of
every running renderer and keeps them in `~/.local/state/wallpaper-engine-control/outputs.json`.

Playlists come from Wallpaper Engine's `config.json` in your Steam library. **Next** needs a
playlist; a monitor running a single wallpaper has no next button.

### With the linux-wallpaper-engine app

The app does not need to run all the time; open it when you want to change wallpapers. Two
behaviours of version 0.4.11 are worth knowing:

- On launch it restarts every renderer it remembers, because its check for running renderers
  (`pgrep -a linux-wallpaperengine`) never matches the kernel's 15-character process name.
- While it runs, a renderer it started that exits cleanly gets its wallpaper marked as broken in
  the app. The widget therefore stops the app's renderers with SIGKILL, as the app itself does.
  The app still drops that monitor from its own list of active wallpapers, which only affects
  what the app displays.

## Usage

- **Left click** opens the panel. **Right click** pauses or resumes.
- IPC for keybindings and scripts:

  ```sh
  dms ipc call wallpaperEngineControl toggle        # pause or resume
  dms ipc call wallpaperEngineControl next          # every monitor
  dms ipc call wallpaperEngineControl nextFocused   # the focused monitor
  dms ipc call wallpaperEngineControl pause|resume|stop|start|status
  dms ipc call widget toggle wallpaperEngineControl # open the panel
  ```

  For example, in `hyprland.lua`:

  ```lua
  hl.bind("SUPER + CTRL + W", hl.dsp.exec_cmd("dms ipc call wallpaperEngineControl nextFocused"))
  ```

  or in `hyprland.conf`:

  ```ini
  bind = SUPER CTRL, W, exec, dms ipc call wallpaperEngineControl nextFocused
  ```

- The controller also works on its own; run it with `--help` from the plugin directory:

  ```sh
  ~/.config/DankMaterialShell/plugins/wallpaperEngineControl/wallpaper-engine-control status
  ```

## How it works

`wallpaper-engine-control` runs each monitor's renderer as a transient systemd user unit named
`wallpaper-engine-<output>-<suffix>.service`, so renderers survive `dms restart`. Their logs are in
`journalctl --user -u 'wallpaper-engine-*'`.

linux-wallpaperengine has no runtime control interface. Its command line can choose where a
playlist starts, though: `--playlist` resets the output to the playlist's first item, and a `--bg`
placed after it picks another. **Next** launches a second renderer that starts at a random item,
waits until Hyprland maps its layer surface, and ends the old renderer once the fade-in is done.
The renderer then keeps rotating the playlist on its own timer. A wallpaper that fails to load is
replaced by another item before the old renderer goes away.

**Pause** relies on the fullscreen detection described above. The widget does not use `SIGSTOP`:
DBus/MPRIS events queued while the renderer is stopped crash it on resume.

## Limitations

- Hyprland only.
- Video wallpapers show about 0.2 s of black when switching, because the renderer maps its surface
  before mpv delivers the first frame.
- **Next** starts a new random pass through the playlist, so a recently shown item can come back.
- Monitors stay remembered after you unplug them, so they get their wallpaper back when you plug
  them in again. Delete an entry from `outputs.json` to forget a monitor.

Not affiliated with Wallpaper Engine or linux-wallpaperengine.

## License

[MIT](LICENSE)
