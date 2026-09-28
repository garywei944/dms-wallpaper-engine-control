pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Common
import qs.Services

// Single owner of the controller state for every bar instance (DMS draws one bar per monitor).
Singleton {
    id: root

    property string controller: "" // wallpaper-engine-control next to this file, set on load

    property string engineState: "loading" // loading | running | paused | stopped | error
    property var outputs: [] // [{output, pid, playlist, aspect, wallpaper: {id, title, type, path, preview}}]
    property bool startable: false
    property string error: ""
    property int freedMib: 0
    property string busy: "" // controller action in flight
    property string busyOutput: "" // the output a single-screen next targets
    property var queued: null // a user request that arrived during a status poll
    property bool fillPending: false // a monitor appeared while the controller was busy

    readonly property bool running: engineState === "running"
    readonly property bool paused: engineState === "paused"
    readonly property bool stopped: engineState === "stopped"
    readonly property bool acting: busy !== "" && busy !== "status"
    readonly property bool canSwitch: running && outputs.some(entry => entry.playlist !== "")

    readonly property var failures: ({
            "next": "Could not switch wallpapers",
            "pause": "Could not pause wallpapers",
            "resume": "Could not resume wallpapers",
            "stop": "Could not stop wallpapers",
            "start": "Could not start wallpapers"
        })

    // Controller arguments for an intent, resolved against the state at launch time so a request
    // queued behind a poll stays valid; null when the intent does not apply.
    function resolve(intent) {
        switch (intent) {
        case "status":
            return ["status"];
        case "toggle":
            return running ? ["pause"] : paused ? ["resume"] : null;
        case "pause":
            return running ? ["pause"] : null;
        case "resume":
            return paused ? ["resume"] : null;
        case "next":
            return canSwitch ? ["next"] : null;
        case "stop":
            return running || paused ? ["stop"] : null;
        case "start":
            return stopped && startable ? ["start"] : null;
        case "login":
            // Waits for PulseAudio and the wallpapers' disk; stays off after an explicit stop.
            return ["start", "--auto", "--wait", "90"];
        case "fill":
            return ["start", "--auto"];
        }
        return null;
    }

    function request(intent, output) {
        if (controller === "" || resolve(intent) === null)
            return false;
        if (busy === "") {
            launch(intent, output || "");
            return true;
        }
        if (busy !== "status" || queued !== null || intent === "status")
            return false;
        queued = {
            "intent": intent,
            "output": output || ""
        };
        return true;
    }

    function launch(intent, output) {
        const args = resolve(intent);
        if (args === null)
            return;
        const action = args[0];
        busy = action;
        busyOutput = action === "next" ? output : "";
        const command = [controller, ...args, "--json"];
        if (busyOutput !== "")
            command.push("--output", busyOutput);
        const id = "wallpaperEngineControl." + (action === "status" ? "status" : "action");
        Proc.runCommand(id, command, stdout => finish(action, stdout), 0, action === "status" ? 10000 : 120000);
    }

    function finish(action, stdout) {
        let data = null;
        try {
            data = JSON.parse(stdout);
        } catch (e) {
            console.warn("wallpaperEngineControl: unreadable controller output:", stdout);
        }
        if (data) {
            engineState = data.state;
            outputs = data.outputs || [];
            startable = !!data.startable;
            error = data.error || "";
            if (action === "stop" && !data.error)
                freedMib = data.freed_mib || 0;
            if (data.error && action !== "status")
                ToastService.showError(failures[action], data.error);
        } else {
            engineState = "error";
            error = "wallpaper-engine-control returned no status";
        }
        busy = "";
        busyOutput = "";
        if (queued !== null) {
            const next = queued;
            queued = null;
            launch(next.intent, next.output);
        } else if (fillPending) {
            fillPending = false;
            launch("fill", "");
        }
    }

    Component.onCompleted: {
        const url = Qt.resolvedUrl("wallpaper-engine-control").toString();
        controller = decodeURIComponent(url.replace(/^file:\/\//, ""));
        request("login");
    }

    // A newly connected monitor gets its remembered wallpaper; debounced because Hyprland
    // reports a docking station's outputs one at a time.
    Connections {
        target: Quickshell

        function onScreensChanged() {
            hotplug.restart();
        }
    }

    Timer {
        id: hotplug
        interval: 2000
        onTriggered: {
            if (!root.request("fill"))
                root.fillPending = true;
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: root.request("status")
    }

    IpcHandler {
        target: "wallpaperEngineControl"

        function toggle(): string {
            return root.request("toggle") ? "ok" : "ignored";
        }
        function pause(): string {
            return root.request("pause") ? "ok" : "ignored";
        }
        function resume(): string {
            return root.request("resume") ? "ok" : "ignored";
        }
        function next(): string {
            return root.request("next") ? "ok" : "ignored";
        }
        function nextFocused(): string {
            const monitor = Hyprland.focusedMonitor;
            return monitor && root.request("next", monitor.name) ? "ok" : "ignored";
        }
        function stop(): string {
            return root.request("stop") ? "ok" : "ignored";
        }
        function start(): string {
            return root.request("start") ? "ok" : "ignored";
        }
        function status(): string {
            return root.engineState;
        }
    }
}
