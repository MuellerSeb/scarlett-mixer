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

    Material.theme: Material.Dark

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
                onToggled: bridge.setJoin("A", checked)
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
                    onMoved: bridge.setVolume("A", value)
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
                    onMoved: bridge.setPan("A", value)
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
                    onMoved: bridge.setLR("A", value, -1)
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
                    onMoved: bridge.setLR("A", -1, value)
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 100
            radius: 8
            border.width: 1
            opacity: 0.9

            RowLayout {
                anchors.fill: parent
                spacing: 8

                Repeater {
                    model: 10

                    Rectangle {
                        Layout.fillHeight: true
                        width: 14
                        color: "#202020"
                        radius: 4
                        border.width: 1

                        property real level: Math.abs(Math.sin((Date.now() / 1000 + index) * 0.7))

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: parent.height * parent.level
                            color: level > 0.8 ? "#ff4d4d" : level > 0.6 ? "#ffaa00" : "#55ff55"
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
            text: "(Web UI can control Mix B in this prototype)"
            opacity: 0.7
        }

        Item { Layout.fillHeight: true }
    }
}
