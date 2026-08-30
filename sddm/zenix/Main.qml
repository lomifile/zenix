// Zenix greeter — SDDM Theme API 2.0, Qt 6.
//
// Deliberately depends on nothing but QtQuick, which sddm already pulls in via
// qt6-declarative. No Kirigami, no libplasma, no breeze: the greeter must not
// drag the Plasma stack onto a Hyprland-only box.
//
// Palette and type follow hypr/hyprlock.conf so unlocking looks like logging in.

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    // SDDM resizes the root item to the greeter window; these are fallbacks.
    width: 1920
    height: 1080
    color: cfg.bg

    // Kept separate from the Caps Lock hint so setting one never clobbers the
    // other's binding.
    property string errorText: ""

    QtObject {
        id: cfg
        readonly property color  bg:        config.backgroundColor || "#1c1c1e"
        readonly property color  fg:        config.textColor       || "#f5f5f7"
        readonly property color  dim:       config.dimTextColor    || "#98989d"
        readonly property color  accent:    config.accentColor     || "#0a84ff"
        readonly property string wallpaper: config.background      || ""
        readonly property real   dimming:   parseFloat(config.backgroundDimming || "0.55")
        readonly property int    clockSize: parseInt(config.clockFontSize || "86")
        // SF Pro is not redistributable, so Inter is the realistic fallback.
        readonly property var    fonts:     [config.fontFamily || "SF Pro Display",
                                             config.fallbackFontFamily || "Inter",
                                             "Noto Sans", "sans-serif"]
    }

    // ------------------------------------------------------------ background

    Image {
        id: wallpaper
        anchors.fill: parent
        source: cfg.wallpaper
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: status === Image.Ready
    }

    Rectangle {
        anchors.fill: parent
        color: cfg.bg
        opacity: wallpaper.visible ? cfg.dimming : 1.0
    }

    // ---------------------------------------------------------------- clock

    Timer {
        id: ticker
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        property var now: new Date()
        onTriggered: now = new Date()
    }

    ColumnLayout {
        id: clock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.round(root.height * 0.14)
        spacing: 4

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(ticker.now, "HH:mm")
            color: cfg.fg
            font.family: cfg.fonts[0]
            font.pixelSize: cfg.clockSize
            font.weight: Font.DemiBold
            renderType: Text.NativeRendering
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(ticker.now, "dddd, dd MMMM")
            color: cfg.dim
            font.family: cfg.fonts[0]
            font.pixelSize: 20
            renderType: Text.NativeRendering
        }
    }

    // ------------------------------------------------------------ login form

    ColumnLayout {
        id: form
        anchors.centerIn: parent
        anchors.verticalCenterOffset: Math.round(root.height * 0.08)
        spacing: 14
        width: 320

        // Avatar: the user's initial on a translucent disc. Drawing it beats
        // reading userModel's icon role, which is often missing or 1:1 tiny.
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 88; height: 88
            radius: width / 2
            color: Qt.rgba(1, 1, 1, 0.10)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.16)

            Text {
                anchors.centerIn: parent
                text: userBox.currentText.length > 0
                      ? userBox.currentText.charAt(0).toUpperCase() : "?"
                color: cfg.fg
                font.family: cfg.fonts[0]
                font.pixelSize: 38
                font.weight: Font.Medium
            }
        }

        // One user is the common case, so show a label and keep the combo for
        // when there are several.
        Text {
            Layout.alignment: Qt.AlignHCenter
            visible: userModel.count <= 1
            text: userBox.currentText
            color: cfg.fg
            font.family: cfg.fonts[0]
            font.pixelSize: 17
            font.weight: Font.Medium
        }

        ThemedCombo {
            id: userBox
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 220
            visible: userModel.count > 1
            model: userModel
            textRole: "name"
            currentIndex: userModel.lastIndex
            fg: cfg.fg; dim: cfg.dim; accent: cfg.accent
            fontFamily: cfg.fonts[0]
        }

        // Password
        Rectangle {
            id: field
            Layout.alignment: Qt.AlignHCenter
            width: 300; height: 46
            radius: 10
            color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 2
            border.color: password.activeFocus ? cfg.accent : Qt.rgba(1, 1, 1, 0.14)

            Behavior on border.color { ColorAnimation { duration: 120 } }

            // ColumnLayout owns this item's x, so the failure shake has to move
            // a transform rather than the position itself.
            transform: Translate { id: nudge }

            TextInput {
                id: password
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 44
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                passwordCharacter: "•"
                color: cfg.fg
                font.family: cfg.fonts[0]
                font.pixelSize: 16
                selectByMouse: true
                focus: true
                enabled: !busy.running
                onAccepted: root.attemptLogin()

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Password"
                    color: cfg.dim
                    font: password.font
                    visible: password.text.length === 0
                }
            }

            // Submit arrow, mirroring macOS
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                width: 32; height: 32
                radius: width / 2
                color: password.text.length > 0 ? cfg.accent : Qt.rgba(1, 1, 1, 0.10)
                visible: !busy.running

                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "→"
                    color: cfg.fg
                    font.pixelSize: 17
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.attemptLogin()
                }
            }

            BusyIndicator {
                id: busy
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 28; height: 28
                running: false
            }
        }

        Text {
            id: message
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 300
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.errorText !== "" ? root.errorText
                  : (keyboard.capsLock ? "Caps Lock is on" : "")
            color: root.errorText !== "" ? "#ff453a" : cfg.dim
            font.family: cfg.fonts[0]
            font.pixelSize: 13
        }
    }

    // ------------------------------------------------------------ bottom bar

    RowLayout {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 28
        spacing: 10

        Text {
            text: "Session"
            color: cfg.dim
            font.family: cfg.fonts[0]
            font.pixelSize: 13
        }

        ThemedCombo {
            id: sessionBox
            Layout.preferredWidth: 200
            model: sessionModel
            textRole: "name"
            currentIndex: sessionModel.lastIndex
            fg: cfg.fg; dim: cfg.dim; accent: cfg.accent
            fontFamily: cfg.fonts[0]
        }
    }

    RowLayout {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 28
        spacing: 22

        // Word labels rather than glyphs: no icon font to go missing, and the
        // macOS login screen spells them out too.
        Repeater {
            model: [
                { label: "Sleep",     enabled: sddm.canSuspend,  action: "suspend"  },
                { label: "Restart",   enabled: sddm.canReboot,   action: "reboot"   },
                { label: "Shut Down", enabled: sddm.canPowerOff, action: "poweroff" }
            ]

            delegate: Text {
                required property var modelData
                visible: modelData.enabled
                text: modelData.label
                color: hover.hovered ? cfg.fg : cfg.dim
                font.family: cfg.fonts[0]
                font.pixelSize: 13

                Behavior on color { ColorAnimation { duration: 120 } }

                HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: {
                        if (modelData.action === "suspend")  sddm.suspend()
                        else if (modelData.action === "reboot")   sddm.reboot()
                        else if (modelData.action === "poweroff") sddm.powerOff()
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------- logic

    function attemptLogin() {
        if (busy.running || password.text.length === 0)
            return
        root.errorText = ""
        busy.running = true
        sddm.login(userBox.currentText, password.text, sessionBox.currentIndex)
    }

    Connections {
        target: sddm

        function onLoginSucceeded() {
            busy.running = false
        }

        function onLoginFailed() {
            busy.running = false
            root.errorText = "Incorrect password"
            password.text = ""
            password.forceActiveFocus()
            shake.start()
        }

        function onInformationMessage(msg) {
            root.errorText = msg
        }
    }

    SequentialAnimation {
        id: shake
        loops: 2
        NumberAnimation { target: nudge; property: "x"; to: -8; duration: 45 }
        NumberAnimation { target: nudge; property: "x"; to:  8; duration: 45 }
        NumberAnimation { target: nudge; property: "x"; to:  0; duration: 45 }
    }

    Component.onCompleted: password.forceActiveFocus()
}
