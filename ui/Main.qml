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
    property var stereoPairs: [
        { label: "A / B", left: "A", right: "B" },
        { label: "C / D", left: "C", right: "D" },
        { label: "E / F", left: "E", right: "F" },
        { label: "G / H", left: "G", right: "H" },
        { label: "I / J", left: "I", right: "J" }
    ]

    function updateMixState(name, data) {
        var clone = Object.assign({}, mixData)
        clone[name] = data
        mixData = clone
    }

    function isPairLinked(left, right) {
        var leftMix = mixData[left]
        return leftMix && leftMix.stereo_pair === right
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
                    onLoaded: {
                        if (item)
                            item.mixName = mixName
                    }
                    onMixNameChanged: {
                        if (item)
                            item.mixName = mixName
                    }
                }
            }
        }
    }

    Component {
        id: channelStripComponent
        ColumnLayout {
            id: channelStrip
            width: 88
            implicitWidth: 88
            implicitHeight: 340
            spacing: 8

            property string mixName: ""
            property int channelIndex: -1
            property var channelData: null

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
            property bool isStereo: !!(mixState && mixState.stereo_pair)

            function syncControls() {
                if (!mixState)
                    return

                if (Math.abs(masterVolumeDial.value - mixState.volume) > 0.0005) {
                    masterVolumeDial.syncing = true
                    masterVolumeDial.value = mixState.volume
                }

                var targetPan = mixPage.isStereo ? mixState.pan : 0
                if (Math.abs(panDial.value - targetPan) > 0.0005) {
                    panDial.syncing = true
                    panDial.value = targetPan
                }

                if (mixMuteButton.checked !== mixState.mute) {
                    mixMuteButton.syncing = true
                    mixMuteButton.checked = mixState.mute
                }

                if (channelRepeater) {
                    for (var ci = 0; ci < channelRepeater.count; ++ci) {
                        var channelItem = channelRepeater.itemAt(ci)
                        channelRepeater.assignItemProperties(ci, channelItem)
                    }
                }
            }

            onMixStateChanged: syncControls()
            onIsStereoChanged: syncControls()
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
                        text: mixPage.isStereo ? "Paired with Mix " + mixState.stereo_pair : "Mono mix"
                        opacity: 0.6
                        font.pixelSize: 14
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    radius: 12
                    color: "#171717"
                    border.color: "#2a2a2a"
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        Label {
                            text: "Stereo Links"
                            font.pixelSize: 16
                        }

                        Flow {
                            width: parent.width
                            spacing: 8

                            Repeater {
                                model: root.stereoPairs
                                delegate: Button {
                                    text: modelData.label
                                    Layout.preferredWidth: 96
                                    highlighted: root.isPairLinked(modelData.left, modelData.right)
                                    enabled: root.mixData[modelData.left] && root.mixData[modelData.right]
                                    onClicked: {
                                        if (root.isPairLinked(modelData.left, modelData.right)) {
                                            bridge.setStereoPair(modelData.left, "")
                                        } else {
                                            bridge.setStereoPair(modelData.left, modelData.right)
                                        }
                                    }
                                }
                            }
                        }
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
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                height: parent.height
                                Repeater {
                                    id: channelRepeater
                                    model: mixState && mixState.channels ? mixState.channels.length : 0
                                    delegate: channelStripComponent

                                    function assignItemProperties(itemIndex, item) {
                                        if (!item)
                                            return
                                        item.mixName = mixPage.mixName
                                        item.channelIndex = itemIndex
                                        item.channelData = mixState && mixState.channels ? mixState.channels[itemIndex] : null
                                    }

                                    onItemAdded: assignItemProperties(index, item)
                                    onModelChanged: {
                                        for (var i = 0; i < count; ++i)
                                            assignItemProperties(i, itemAt(i))
                                    }
                                }
                            }

                            ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }
                        }
                    }

                    Rectangle {
                        width: 320
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

                            Label {
                                text: mixPage.isStereo ? "Linked with Mix " + mixState.stereo_pair : "Mono Output"
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
                                font.pixelSize: 13
                                opacity: 0.65
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 16

                                ColumnLayout {
                                    visible: mixPage.isStereo
                                    Layout.preferredWidth: 36
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
                                    visible: mixPage.isStereo
                                    Layout.preferredWidth: 36
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
                                    visible: !mixPage.isStereo
                                    Layout.preferredWidth: 36
                                    Layout.fillHeight: true
                                    spacing: 6

                                    Label {
                                        text: "Level"
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
                                            height: parent.height * (mixState ? Math.max(mixState.level_l, mixState.level_r) : 0)
                                            radius: 4
                                            color: mixState && Math.max(mixState.level_l, mixState.level_r) > 0.8 ? "#ff4d4d"
                                                   : mixState && Math.max(mixState.level_l, mixState.level_r) > 0.6 ? "#ffaa00"
                                                   : "#55ff55"
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillHeight: true
                                    Layout.fillWidth: true
                                    spacing: 12

                                    Dial {
                                        id: masterVolumeDial
                                        from: 0
                                        to: 1
                                        stepSize: 0.01
                                        value: 0.75
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.preferredWidth: 110
                                        Layout.preferredHeight: 110
                                        property bool syncing: false
                                        onValueChanged: {
                                            if (syncing) {
                                                syncing = false
                                                return
                                            }
                                            bridge.setVolume(mixPage.mixName, value)
                                        }
                                    }

                                    Label {
                                        text: mixState ? "Vol " + Math.round(mixState.volume * 100) / 100 : ""
                                        horizontalAlignment: Text.AlignHCenter
                                        Layout.fillWidth: true
                                        font.pixelSize: 12
                                        opacity: 0.7
                                    }

                                    Dial {
                                        id: panDial
                                        from: -1
                                        to: 1
                                        stepSize: 0.01
                                        value: 0
                                        visible: mixPage.isStereo
                                        enabled: mixPage.isStereo
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.preferredWidth: 100
                                        Layout.preferredHeight: 100
                                        property bool syncing: false
                                        onValueChanged: {
                                            if (syncing) {
                                                syncing = false
                                                return
                                            }
                                            if (mixPage.isStereo)
                                                bridge.setPan(mixPage.mixName, value)
                                        }
                                    }

                                    Label {
                                        visible: mixPage.isStereo
                                        text: "Pan"
                                        horizontalAlignment: Text.AlignHCenter
                                        Layout.fillWidth: true
                                        font.pixelSize: 12
                                        opacity: 0.7
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
                                            bridge.setMixMute(mixPage.mixName, checked)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
