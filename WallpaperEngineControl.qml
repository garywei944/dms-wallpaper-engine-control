import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

// Bar pill for wallpaper-engine-control: left click opens the panel, right click pauses or resumes.
// IPC: dms ipc call wallpaperEngineControl toggle|pause|resume|next|nextFocused|stop|start|status
PluginComponent {
    id: root

    readonly property var engine: WallpaperEngineControlService

    readonly property color tone: {
        switch (engine.engineState) {
        case "running":
            return Theme.primary;
        case "paused":
            return Theme.warning;
        case "error":
            return Theme.error;
        }
        return Theme.surfaceVariantText;
    }
    readonly property string glyph: {
        switch (engine.engineState) {
        case "running":
        case "paused":
            return "wallpaper";
        case "error":
            return "error";
        }
        return "hide_image";
    }
    readonly property string stateLabel: {
        switch (engine.busy) {
        case "next":
            return "Switching…";
        case "pause":
            return "Pausing…";
        case "resume":
            return "Resuming…";
        case "stop":
            return "Stopping…";
        case "start":
            return "Starting…";
        }
        switch (engine.engineState) {
        case "running":
            return "Live";
        case "paused":
            return "Paused";
        case "stopped":
            return "Off";
        case "error":
            return "Error";
        }
        return "…";
    }

    pillRightClickAction: () => engine.request("toggle")
    popoutWidth: 520

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            StateIcon {
                anchors.verticalCenter: parent.verticalCenter
                size: root.iconSize
                name: root.glyph
                color: root.tone
                spinning: engine.acting
            }

            // A bare icon while wallpapers run; any other state is spelled out.
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: !engine.running || engine.acting
                text: root.stateLabel
                color: root.tone
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
            }
        }
    }

    verticalBarPill: Component {
        StateIcon {
            size: root.iconSize
            name: root.glyph
            color: root.tone
            spinning: engine.acting
        }
    }

    component ActionButton: DankButton {
        property bool emphasized

        width: (parent.width - parent.spacing * 2) / 3
        backgroundColor: emphasized ? Theme.buttonBg : Theme.surfaceContainerHighest
        textColor: emphasized ? Theme.buttonText : Theme.surfaceText
    }

    component StateIcon: Item {
        id: stateIcon

        property int size: Theme.iconSize
        property string name
        property color color
        property bool spinning

        implicitWidth: size
        implicitHeight: size

        DankIcon {
            anchors.centerIn: parent
            visible: !stateIcon.spinning
            name: stateIcon.name
            size: stateIcon.size
            color: stateIcon.color
        }

        DankSpinner {
            anchors.centerIn: parent
            visible: stateIcon.spinning
            size: stateIcon.size - 6
            color: stateIcon.color
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: panel

            readonly property bool shown: parentPopout ? parentPopout.shouldBeVisible : false

            headerText: "Wallpaper Engine"
            showCloseButton: true
            headerActions: Component {
                Rectangle {
                    implicitWidth: chip.implicitWidth + Theme.spacingM * 2
                    implicitHeight: 26
                    radius: height / 2
                    color: Theme.withAlpha(root.tone, 0.14)

                    Row {
                        id: chip
                        anchors.centerIn: parent
                        spacing: Theme.spacingXS

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !engine.acting
                            width: 8
                            height: 8
                            radius: 4
                            color: root.tone
                        }

                        DankSpinner {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: engine.acting
                            size: 12
                            color: root.tone
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.stateLabel
                            color: root.tone
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                        }
                    }
                }
            }

            onShownChanged: {
                if (shown)
                    engine.request("status");
            }

            Column {
                width: parent.width
                spacing: Theme.spacingM
                topPadding: Theme.spacingS
                bottomPadding: Theme.spacingXS

                // One card per monitor, left to right as they stand on the desk; more than three
                // wrap into balanced rows (4 -> 2x2, 5 -> 3+2).
                Grid {
                    id: screens

                    readonly property int count: engine.outputs.length
                    readonly property real cellWidth: (width - columnSpacing * (columns - 1)) / columns

                    width: parent.width
                    visible: count > 0
                    columns: Math.max(1, Math.ceil(count / Math.ceil(count / 3)))
                    columnSpacing: Theme.spacingS
                    rowSpacing: Theme.spacingM

                    Repeater {
                        model: engine.outputs

                        Item {
                            id: cell

                            required property var modelData

                            width: screens.cellWidth
                            height: card.height

                            Column {
                                id: card

                                readonly property var entry: cell.modelData
                                readonly property var wallpaper: entry.wallpaper || ({})
                                readonly property bool switching: engine.busy === "next" && (engine.busyOutput === "" || engine.busyOutput === entry.output)
                                readonly property real aspect: entry.aspect > 0 ? entry.aspect : 16 / 9

                                anchors.horizontalCenter: parent.horizontalCenter
                                // Tall screens are capped so a portrait monitor does not stretch the panel.
                                width: Math.min(parent.width, 240 * aspect)
                                spacing: Theme.spacingXS

                                // The Workshop preview, cropped to the screen's shape.
                                ClippingRectangle {
                                    width: parent.width
                                    height: Math.round(width / card.aspect)
                                    radius: Theme.cornerRadius
                                    color: Theme.surfaceContainerHigh

                                    DankIcon {
                                        anchors.centerIn: parent
                                        visible: preview.status !== Image.Ready
                                        name: "wallpaper"
                                        size: Theme.iconSize + 8
                                        color: Theme.surfaceVariantText
                                    }

                                    AnimatedImage {
                                        id: preview
                                        anchors.fill: parent
                                        source: card.wallpaper.preview ? "file://" + card.wallpaper.preview : ""
                                        sourceSize.width: 360
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: false
                                        playing: panel.shown && engine.running
                                        // Paused wallpapers keep their frame; show that as a still, grey preview.
                                        layer.enabled: engine.paused
                                        layer.effect: MultiEffect {
                                            saturation: -1
                                        }
                                    }

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.margins: Theme.spacingXS
                                        width: outputName.implicitWidth + Theme.spacingS * 2
                                        height: outputName.implicitHeight + 4
                                        radius: height / 2
                                        color: Theme.withAlpha(Theme.surface, 0.82)

                                        StyledText {
                                            id: outputName
                                            anchors.centerIn: parent
                                            text: card.entry.output
                                            color: Theme.surfaceText
                                            font.pixelSize: Theme.fontSizeSmall - 1
                                            font.weight: Font.Medium
                                        }
                                    }

                                    DankActionButton {
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.margins: Theme.spacingXS
                                        visible: card.entry.playlist !== ""
                                        enabled: engine.canSwitch && engine.busy === ""
                                        opacity: enabled ? 1 : 0.5
                                        buttonSize: 28
                                        iconSize: 18
                                        iconName: "skip_next"
                                        iconColor: Theme.surfaceText
                                        backgroundColor: Theme.withAlpha(Theme.surface, 0.82)
                                        tooltipText: "Next wallpaper on " + card.entry.output
                                        onClicked: engine.request("next", card.entry.output)
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        visible: card.switching
                                        color: Theme.withAlpha(Theme.surface, 0.55)

                                        DankSpinner {
                                            anchors.centerIn: parent
                                            size: 28
                                            color: Theme.primary
                                        }
                                    }
                                }

                                StyledText {
                                    width: parent.width
                                    text: card.wallpaper.title || "Unknown wallpaper"
                                    color: Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    width: parent.width
                                    text: [card.entry.playlist ? "Playlist " + card.entry.playlist : "Single wallpaper", card.wallpaper.type].filter(Boolean).join(" · ")
                                    color: Theme.surfaceVariantText
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }

                // Off, still loading, or a controller failure.
                Column {
                    width: parent.width
                    visible: engine.outputs.length === 0
                    spacing: Theme.spacingXS
                    topPadding: Theme.spacingL
                    bottomPadding: Theme.spacingL

                    DankIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: root.glyph
                        size: 44
                        color: root.tone
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: engine.engineState === "error" ? "Controller error" : engine.engineState === "loading" ? "Checking wallpapers…" : "Wallpapers are off"
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                    }

                    StyledText {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        visible: text !== ""
                        text: {
                            if (engine.engineState === "error")
                                return engine.error;
                            if (!engine.stopped)
                                return "";
                            if (!engine.startable)
                                return "Apply wallpapers in the Wallpaper Engine app once to set up each screen.";
                            if (engine.freedMib > 0)
                                return (engine.freedMib / 1024).toFixed(1) + " GB of GPU memory released";
                            return "GPU memory is free";
                        }
                        color: engine.engineState === "error" ? Theme.error : Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    // Only the likeliest next step wears the button colour; the rest stay tonal.
                    ActionButton {
                        emphasized: engine.paused
                        enabled: (engine.running || engine.paused) && engine.busy === ""
                        iconName: engine.paused ? "play_arrow" : "pause"
                        text: engine.paused ? "Resume" : "Pause"
                        // An open popout makes Hyprland skip the pause window's fullscreen rule.
                        onClicked: {
                            panel.closePopout();
                            Qt.callLater(() => engine.request("toggle"));
                        }
                    }

                    ActionButton {
                        emphasized: engine.running
                        enabled: engine.canSwitch && engine.busy === ""
                        iconName: "skip_next"
                        text: engine.outputs.length > 1 ? "Next all" : "Next"
                        onClicked: engine.request("next")
                    }

                    ActionButton {
                        emphasized: engine.stopped && engine.startable
                        enabled: engine.busy === "" && (emphasized || engine.running || engine.paused)
                        iconName: "power_settings_new"
                        text: engine.stopped ? "Start" : "Stop"
                        onClicked: engine.request(engine.stopped ? "start" : "stop")
                    }
                }
            }
        }
    }
}
