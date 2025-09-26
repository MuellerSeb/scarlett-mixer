import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

ApplicationWindow {
    id: root
    width: 960
    height: 600
    visible: true
    title: "Scarlett Mixer (Prototype)"

    property real mixALevelL: 0.0
    property real mixALevelR: 0.0

    Material.theme: Material.Dark

    Connections {
        target: bridge
        function onMixSnapshot(name, data) {
            if (name !== "A")
                return

            joinSwitch.syncing = true
            joinSwitch.checked = data.joined

            volumeSlider.syncing = true
            volumeSlider.value = data.volume

            panDial.syncing = true
            panDial.value = data.pan

            leftSlider.syncing = true
            leftSlider.value = data.gain_l

            rightSlider.syncing = true
            rightSlider.value = data.gain_r

            root.mixALevelL = data.level_l || 0
            root.mixALevelR = data.level_r || 0
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Label {
            text: "Mix A"
            font.pixelSize: 20
        }

        RowLayout {
            spacing: 24

            Switch {
                id: joinSwitch
                text: "Join L/R"
                checked: true
                property bool syncing: false
                onToggled: {
                    if (syncing) {
                        syncing = false
                        return
                    }
                    bridge.setJoin("A", checked)
                }
            }

            ColumnLayout {
                visible: joinSwitch.checked

                Label { text: "Volume" }

                Slider {
                    id: volumeSlider
                    from: 0
                    to: 1
                    value: 0.75
                    stepSize: 0.01
                    property bool syncing: false
                    onValueChanged: {
                        if (syncing) {
                            syncing = false
                            return
                        }
                        bridge.setVolume("A", value)
                    }
                }
            }

            ColumnLayout {
                visible: joinSwitch.checked

                Label { text: "Pan" }

                Dial {
                    id: panDial
                    from: -1
                    to: 1
                    value: 0
                    stepSize: 0.01
                    property bool syncing: false
                    onValueChanged: {
                        if (syncing) {
                            syncing = false
                            return
                        }
                        bridge.setPan("A", value)
                    }
                }
            }

            ColumnLayout {
                visible: !joinSwitch.checked

                Label { text: "Left" }

                Slider {
                    id: leftSlider
                    from: 0
                    to: 1
                    value: 0.75
                    stepSize: 0.01
                    property bool syncing: false
                    onValueChanged: {
                        if (syncing) {
                            syncing = false
                            return
                        }
                        bridge.setLeft("A", value)
                    }
                }
            }

            ColumnLayout {
                visible: !joinSwitch.checked

                Label { text: "Right" }

                Slider {
                    id: rightSlider
                    from: 0
                    to: 1
                    value: 0.75
                    stepSize: 0.01
                    property bool syncing: false
                    onValueChanged: {
                        if (syncing) {
                            syncing = false
                            return
                        }
                        bridge.setRight("A", value)
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 140
            radius: 8
            color: "#202020"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 24

                ColumnLayout {
                    Layout.fillHeight: true
                    spacing: 8

                    Label { text: "Left" }

                    Rectangle {
                        Layout.fillHeight: true
                        width: 26
                        radius: 6
                        color: "#101010"
                        border.width: 1

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: parent.height * root.mixALevelL
                            color: root.mixALevelL > 0.8 ? "#ff4d4d" : root.mixALevelL > 0.6 ? "#ffaa00" : "#55ff55"
                            radius: 4
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillHeight: true
                    spacing: 8

                    Label { text: "Right" }

                    Rectangle {
                        Layout.fillHeight: true
                        width: 26
                        radius: 6
                        color: "#101010"
                        border.width: 1

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: parent.height * root.mixALevelR
                            color: root.mixALevelR > 0.8 ? "#ff4d4d" : root.mixALevelR > 0.6 ? "#ffaa00" : "#55ff55"
                            radius: 4
                        }
                    }
                }
            }
        }

        Label {
            text: "Open on phone: http://<your-ip>:8088/"
            opacity: 0.7
        }

        Label {
            text: "(Web UI can control Mix A in this prototype)"
            opacity: 0.7
        }

        Item { Layout.fillHeight: true }
    }
}
