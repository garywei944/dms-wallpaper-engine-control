# Wallpaper Engine Control

English | [简体中文](README.zh-CN.md)

A [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) bar widget for
[linux-wallpaperengine](https://github.com/Almamu/linux-wallpaperengine): see what every monitor
shows, skip to the next playlist item, pause, or stop the renderers to free GPU memory.

[![Panel with one card per monitor](screenshot.png)](https://www.youtube.com/watch?v=LNpJ-PKpF-Q)

▶ [Watch the demo on YouTube](https://www.youtube.com/watch?v=LNpJ-PKpF-Q) (1 min 18 s)

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
- The panel opens the linux-wallpaper-engine app to choose wallpapers, or brings its window
  forward if it is already open, without restarting the wallpapers on screen.

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

The app does not need to run all the time. Open it with the **Choose wallpapers** button in the
panel header when you want to change wallpapers, and close it when you are done; the wallpapers
keep running. For its window to show up when the widget starts it, turn off the app's system
tray setting (or its *minimize on startup* setting); with the tray off, closing the window also
quits the app.

The widget works around two behaviours of version 0.4.11:

- On launch the app restarts every renderer in its list of active wallpapers, back at each
  playlist's first item, because its check for running renderers (`pgrep -a
  linux-wallpaperengine`) never matches the kernel's 15-character process name. Before opening
  the app, the widget therefore empties that list in the app's `active-wallpapers.json`; the
  widget keeps its own record. As a consequence, a global setting you change in the app (FPS,
  scaling, audio) applies to the monitors you apply a wallpaper to afterwards, not to the others.
  If you open the app some other way, it restarts the monitors still in that list.
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
  dms ipc call wallpaperEngineControl openApp       # choose wallpapers in the app
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

There is no daemon. For every poll and every click, the widget runs the `wallpaper-engine-control`
script next to it, reads the JSON it prints, and draws the panel from it. The script looks at the
live system, acts, and exits. The only long-running processes are the renderers themselves.

```
DMS bar widget ── on a poll and on each click ──► wallpaper-engine-control <action> --json
                                                     │ reads: /proc, hyprctl, Wallpaper Engine's config.json
                                                     │ acts:  systemd-run, signals, the pause window
                                                     ▼
wallpaper-engine-DP-1-<suffix>.service   linux-wallpaperengine --screen-root DP-1 --playlist DP-1 --bg …
wallpaper-engine-DP-2-<suffix>.service   linux-wallpaperengine --screen-root DP-2 --playlist DP-2 --bg …
```

### Renderers

Each monitor, or each group of monitors a wallpaper spans, gets one `linux-wallpaperengine`
process in a transient systemd user unit named `wallpaper-engine-<output>-<suffix>.service`.
The units live outside DMS's cgroup, so wallpapers keep running through `dms restart` or while the
widget is disabled. Their logs are in `journalctl --user -u 'wallpaper-engine-*'`. The renderer
rotates its playlist on its own timer; the widget does not take part in that.

### What the controller reads

The controller keeps almost no state of its own. Every run looks at the system as it is:

- **Renderers** are this user's processes whose executable is `linux-wallpaperengine` and that
  have a screen argument; window previews and CEF helper processes are skipped. Renderers started
  some other way, by the app or from a terminal, are found the same way.
- **The wallpaper on screen** is the file a renderer has open under `/proc/<pid>/fd`: a scene keeps
  its `scene.pkg` open and mpv keeps the video file open. The `project.json` in that Workshop
  directory gives the title and preview. That is why the cards follow the renderer's own playlist
  rotation instead of showing the item it was started with.
- **Card layout** comes from `hyprctl monitors`: each card takes its monitor's shape, and cards are
  sorted by their monitor's top-left corner.
- **Paused** means the pause window is fullscreen on its special workspace (`hyprctl clients`).

Two things persist, in `~/.local/state/wallpaper-engine-control/`:

- `outputs.json` holds the launch arguments of every output. Each status call adopts the arguments
  of the renderers it finds, so a wallpaper applied in the app or by hand is remembered. For a
  playlist the `--bg` is dropped, so every start picks a fresh item.
- `stopped` is left by **Stop** so that automatic starts keep the wallpapers off.

### Start and hotplug

When DMS loads the widget, it runs `start --auto --wait 90`. That waits until PulseAudio is up and
every path in `outputs.json` exists, since the disk holding the wallpapers may mount late in a
fresh session. It then launches every remembered output that is connected and has no renderer.
When the set of screens changes, the widget runs `start --auto` again after 2 s, because a docking
station reports its outputs one at a time. That start also ends renderers whose monitor is gone:
linux-wallpaperengine keeps running after its monitor is unplugged, drawing nothing.

A launch counts as successful once Hyprland reports a layer surface owned by the new PID on that
monitor, within 20 s. If the renderer exits first, typically because a wallpaper fails to load,
the controller tries another playlist item, up to three per output.

### Next

linux-wallpaperengine has no runtime control interface. Its command line can choose where a
playlist starts, though: `--playlist` resets the output to the playlist's first item, and a `--bg`
placed after it picks another. **Next** reads the playlist from Wallpaper Engine's `config.json`,
picks a random item that is on disk and not the current one, and launches a second renderer with
that `--bg`. Once Hyprland maps the new layer surface, the controller waits 0.6 s for Hyprland's
layer fade-in to cover the old renderer, then ends the old one. While both run, the newer renderer
is the one reported for that output. A wallpaper that fails to load is replaced by another item
before the old renderer goes away.

### Pause

linux-wallpaperengine stops rendering while any window is fullscreen and keeps its last frame.
**Pause** opens a small `zenity` window titled `wallpaper-engine-pause` in its own unit,
`wallpaper-engine-pause.service`; the window rule above makes it fullscreen on a hidden special
workspace, so every renderer sees a fullscreen window and stops drawing. **Resume** stops that unit.
The widget does not use `SIGSTOP`: DBus/MPRIS events queued while the renderer is stopped crash it
on resume.

### Stop

**Stop** sends SIGTERM to every renderer and SIGKILL to any still running after 3 s, addressing
each through a pidfd so a reused PID is never signalled. It reads `nvidia-smi` before and after to
report the GPU memory released.

### The widget

All bars share one QML singleton, which runs one controller call at a time: a status poll, plus
the actions you trigger. The poll runs every 10 s while a panel is open and every 2 minutes
otherwise, and opening the panel refreshes it at once. An action that arrives during a poll is queued behind it. A
call that does not answer within its timeout plus 5 s is abandoned, so a controller that cannot
start, for example because the plugin directory moved, cannot freeze the panel. The panel shows
the result of the last call, so an open panel can lag a playlist rotation by up to 10 s, and the
bar icon can take up to 2 minutes to notice renderers started or stopped outside the widget.

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
