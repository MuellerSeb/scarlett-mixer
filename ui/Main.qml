import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

ApplicationWindow {
    id: root
    width: 1280
    height: 720
    visible: true
    title: "Scarlett Mixer (Prototype)"

    Material.theme: Material.Dark

    property var mixNames: ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"]
    property var mixData: ({})

    function updateMixState(name, data) {
        var clone = Object.assign({}, mixData)
        clone[name] = data
        mixData = clone
    }

    Connections {
        target: bridge
        function onMixSnapshot(name, data) {
            updateMixState(name, data)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Label {
                text: "Scarlett 18i20 Mixer"
                font.pixelSize: 26
                Layout.fillWidth: true
            }

            TabBar {
                id: mixTabBar
                Layout.preferredWidth: Math.min(640, implicitWidth)
                Repeater {
                    model: root.mixNames
                    TabButton {
                        text: "Mix " + modelData
                        checkable: true
                        checked: index === mixTabBar.currentIndex
                        onClicked: mixTabBar.currentIndex = index
                    }
                }
            }
        }

        StackLayout {
            id: mixStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: mixTabBar.currentIndex

            Repeater {
                model: root.mixNames
                Loader {
                    sourceComponent: mixPageComponent
                    property string mixName: modelData
                }
            }
        }
    }

    Component {
        id: channelStripComponent
        ColumnLayout {
            id: channelStrip
            width: 88
            spacing: 8

            property string mixName
            property int channelIndex
            property var channelData

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 12
                color: "#1f1f1f"
                border.color: "#2f2f2f"
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    Label {
                        text: channelData ? channelData.name : ""
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 16
                            Layout.fillHeight: true
                            radius: 6
                            color: "#101010"
                            border.color: "#2a2a2a"
                            border.width: 1

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: parent.height * (channelData ? channelData.level : 0)
                                radius: 4
                                color: channelData && channelData.level > 0.8 ? "#ff4d4d"
                                       : channelData && channelData.level > 0.6 ? "#ffaa00"
                                       : "#55ff55"
                            }
                        }

                        Slider {
                            id: channelVolumeSlider
                            Layout.fillHeight: true
                            Layout.fillWidth: true
                            orientation: Qt.Vertical
                            from: 0
                            to: 1
                            stepSize: 0.01
                            value: 0.75
                            property bool syncing: false

                            onValueChanged: {
                                if (syncing) {
                                    syncing = false
                                    return
                                }
                                bridge.setChannelVolume(channelStrip.mixName, channelStrip.channelIndex, value)
                            }
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8

                        Button {
                            id: muteButton
                            text: "M"
                            checkable: true
                            font.pixelSize: 12
                            width: 32
                            checked: false
                            property bool syncing: false
                            onToggled: {
                                if (syncing) {
                                    syncing = false
                                    return
                                }
                                bridge.setChannelMute(channelStrip.mixName, channelStrip.channelIndex, checked)
                            }
                        }

                        Button {
                            id: soloButton
                            text: "S"
                            checkable: true
                            font.pixelSize: 12
                            width: 32
                            checked: false
                            property bool syncing: false
                            onToggled: {
                                if (syncing) {
                                    syncing = false
                                    return
                                }
                                bridge.setChannelSolo(channelStrip.mixName, channelStrip.channelIndex, checked)
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 4
                radius: 2
                color: "#303030"
            }

            Label {
                text: channelData ? Math.round(channelData.volume * 100) / 100 : ""
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
                font.pixelSize: 11
                opacity: 0.7
            }

            function sync() {
                if (!channelData)
                    return
                if (Math.abs(channelVolumeSlider.value - channelData.volume) > 0.0005) {
                    channelVolumeSlider.syncing = true
                    channelVolumeSlider.value = channelData.volume
                }
                if (muteButton.checked !== channelData.mute) {
                    muteButton.syncing = true
                    muteButton.checked = channelData.mute
                }
                if (soloButton.checked !== channelData.solo) {
                    soloButton.syncing = true
                    soloButton.checked = channelData.solo
                }
            }

            onChannelDataChanged: sync()
            Component.onCompleted: sync()
        }
    }

    Component {
        id: mixPageComponent
        Item {
            id: mixPage
            anchors.fill: parent
            property string mixName
            property var mixState: root.mixData[mixName] || null
            property var stereoOptions: ["No Pair"].concat(root.mixNames.filter(function(n) { return n !== mixName }))

            function syncControls() {
                if (!mixState)
                    return

                if (joinSwitch.checked !== mixState.joined) {
                    joinSwitch.syncing = true
                    joinSwitch.checked = mixState.joined
                }

                if (Math.abs(masterVolumeSlider.value - mixState.volume) > 0.0005) {
                    masterVolumeSlider.syncing = true
                    masterVolumeSlider.value = mixState.volume
                }

                if (Math.abs(panDial.value - mixState.pan) > 0.0005) {
                    panDial.syncing = true
                    panDial.value = mixState.pan
                }

                if (Math.abs(leftSlider.value - mixState.gain_l) > 0.0005) {
                    leftSlider.syncing = true
                    leftSlider.value = mixState.gain_l
                }

                if (Math.abs(rightSlider.value - mixState.gain_r) > 0.0005) {
                    rightSlider.syncing = true
                    rightSlider.value = mixState.gain_r
                }

                if (mixMuteButton.checked !== mixState.mute) {
                    mixMuteButton.syncing = true
                    mixMuteButton.checked = mixState.mute
                }

                var pairValue = mixState.stereo_pair && mixState.stereo_pair.length ? mixState.stereo_pair : "No Pair"
                var pairIndex = stereoOptions.indexOf(pairValue)
                if (pairIndex < 0)
                    pairIndex = 0
                if (pairSelector.currentIndex !== pairIndex) {
                    pairSelector.syncing = true
                    pairSelector.currentIndex = pairIndex
                    Qt.callLater(function() { pairSelector.syncing = false })
                }
            }

            onMixStateChanged: syncControls()
            Component.onCompleted: syncControls()

            ColumnLayout {
                anchors.fill: parent
                spacing: 16

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Label {
                        text: "Mix " + mixName
                        font.pixelSize: 22
                    }

                    Item { Layout.fillWidth: true }

                    Label {
                        text: mixState && mixState.stereo_pair ? "Paired with Mix " + mixState.stereo_pair : ""
                        opacity: 0.6
                        font.pixelSize: 14
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 24

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 14
                        color: "#171717"
                        border.color: "#2a2a2a"
                        border.width: 1

                        Flickable {
                            id: channelFlick
                            anchors.fill: parent
                            anchors.margins: 16
                            clip: true
                            contentWidth: channelRow.implicitWidth
                            contentHeight: height

                            Row {
                                id: channelRow
                                spacing: 16
                                anchors.verticalCenter: parent.verticalCenter
                                Repeater {
                                    model: mixState && mixState.channels ? mixState.channels.length : 0
                                    delegate: channelStripComponent {
                                        mixName: mixPage.mixName
                                        channelIndex: index
                                        channelData: mixState.channels[index]
                                    }
                                }
                            }

                            ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }
                        }
                    }

                    Rectangle {
                        width: 260
                        Layout.fillHeight: true
                        radius: 14
                        color: "#171717"
                        border.color: "#2a2a2a"
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 18
                            spacing: 16

                            Label {
                                text: "Master Section"
                                font.pixelSize: 18
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 12

                                ColumnLayout {
                                    Layout.preferredWidth: 28
                                    Layout.fillHeight: true
                                    spacing: 6

                                    Label {
                                        text: "L"
                                        horizontalAlignment: Text.AlignHCenter
                                        Layout.fillWidth: true
                                    }

                                    Rectangle {
                                        Layout.fillHeight: true
                                        Layout.fillWidth: true
                                        radius: 6
                                        color: "#101010"
                                        border.color: "#2a2a2a"
                                        border.width: 1

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            height: parent.height * (mixState ? mixState.level_l : 0)
                                            radius: 4
                                            color: mixState && mixState.level_l > 0.8 ? "#ff4d4d"
                                                   : mixState && mixState.level_l > 0.6 ? "#ffaa00"
                                                   : "#55ff55"
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Layout.preferredWidth: 28
                                    Layout.fillHeight: true
                                    spacing: 6

                                    Label {
                                        text: "R"
                                        horizontalAlignment: Text.AlignHCenter
                                        Layout.fillWidth: true
                                    }

                                    Rectangle {
                                        Layout.fillHeight: true
                                        Layout.fillWidth: true
                                        radius: 6
                                        color: "#101010"
                                        border.color: "#2a2a2a"
                                        border.width: 1

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            height: parent.height * (mixState ? mixState.level_r : 0)
                                            radius: 4
                                            color: mixState && mixState.level_r > 0.8 ? "#ff4d4d"
                                                   : mixState && mixState.level_r > 0.6 ? "#ffaa00"
                                                   : "#55ff55"
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillHeight: true
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Label {
                                        text: "Master"
                                        horizontalAlignment: Text.AlignHCenter
                                        Layout.fillWidth: true
                                    }

                                    Slider {
                                        id: masterVolumeSlider
                                        Layout.fillHeight: true
                                        orientation: Qt.Vertical
                                        from: 0
                                        to: 1
                                        stepSize: 0.01
                                        value: 0.75
                                        property bool syncing: false
                                        onValueChanged: {
                                            if (syncing) {
                                                syncing = false
                                                return
                                            }
                                            bridge.setVolume(mixName, value)
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Layout.preferredWidth: 80
                                    Layout.fillHeight: true
                                    spacing: 8

                                    Label {
                                        text: "Left / Right"
                                        horizontalAlignment: Text.AlignHCenter
                                        Layout.fillWidth: true
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        spacing: 12

                                        Slider {
                                            id: leftSlider
                                            Layout.fillHeight: true
                                            Layout.fillWidth: true
                                            enabled: !joinSwitch.checked
                                            orientation: Qt.Vertical
                                            from: 0
                                            to: 1
                                            stepSize: 0.01
                                            value: 0.75
                                            property bool syncing: false
                                            onValueChanged: {
                                                if (syncing) {
                                                    syncing = false
                                                    return
                                                }
                                                bridge.setLeft(mixName, value)
                                            }
                                        }

                                        Slider {
                                            id: rightSlider
                                            Layout.fillHeight: true
                                            Layout.fillWidth: true
                                            enabled: !joinSwitch.checked
                                            orientation: Qt.Vertical
                                            from: 0
                                            to: 1
                                            stepSize: 0.01
                                            value: 0.75
                                            property bool syncing: false
                                            onValueChanged: {
                                                if (syncing) {
                                                    syncing = false
                                                    return
                                                }
                                                bridge.setRight(mixName, value)
                                            }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                Switch {
                                    id: joinSwitch
                                    text: "Link L/R"
                                    checked: true
                                    property bool syncing: false
                                    onToggled: {
                                        if (syncing) {
                                            syncing = false
                                            return
                                        }
                                        bridge.setJoin(mixName, checked)
                                    }
                                }

                                Dial {
                                    id: panDial
                                    from: -1
                                    to: 1
                                    stepSize: 0.01
                                    value: 0
                                    enabled: joinSwitch.checked
                                    Layout.preferredWidth: 90
                                    Layout.preferredHeight: 90
                                    property bool syncing: false
                                    onValueChanged: {
                                        if (syncing) {
                                            syncing = false
                                            return
                                        }
                                        bridge.setPan(mixName, value)
                                    }
                                }

                                Button {
                                    id: mixMuteButton
                                    text: checked ? "Muted" : "Mute"
                                    checkable: true
                                    Layout.fillWidth: true
                                    property bool syncing: false
                                    onToggled: {
                                        if (syncing) {
                                            syncing = false
                                            return
                                        }
                                        bridge.setMixMute(mixName, checked)
                                    }
                                }
                            }

                            ComboBox {
                                id: pairSelector
                                Layout.fillWidth: true
                                model: mixPage.stereoOptions
                                property bool syncing: false
                                onActivated: {
                                    if (syncing) {
                                        syncing = false
                                        return
                                    }
                                    var selection = index === 0 ? "" : mixPage.stereoOptions[index]
                                    bridge.setStereoPair(mixName, selection)
                                }
                                delegate: ItemDelegate {
                                    text: modelData
                                }
                                contentItem: Text {
                                    text: parent.currentText
                                    color: "white"
                                    verticalAlignment: Text.AlignVCenter
                                }
                                background: Rectangle {
                                    implicitHeight: 34
                                    radius: 6
                                    color: "#202020"
                                    border.color: "#323232"
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
