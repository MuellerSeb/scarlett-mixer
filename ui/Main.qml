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
    property var mixTabs: []
    property string currentMixName: ""

    function updateMixState(name, data) {
        var previous = mixData[name]
        var clone = Object.assign({}, mixData)
        clone[name] = data
        mixData = clone

        var pairingChanged = !previous || previous.stereo_pair !== data.stereo_pair
        if (pairingChanged) {
            mixTabs = buildMixTabs()
        } else {
            ensureCurrentMix()
        }
    }

    function buildMixTabs() {
        var result = []
        for (var i = 0; i < mixNames.length; ++i) {
            var name = mixNames[i]
            var data = mixData[name]
            if (data && data.stereo_pair) {
                var partner = data.stereo_pair
                var partnerIndex = mixNames.indexOf(partner)
                if (partnerIndex >= 0 && partnerIndex < i)
                    continue
                result.push({ mixName: name, label: "Mix " + name + " / " + partner, stereoPartner: partner })
            } else {
                result.push({ mixName: name, label: "Mix " + name, stereoPartner: "" })
            }
        }
        return result
    }

    function indexOfMix(name) {
        for (var i = 0; i < mixTabs.length; ++i) {
            if (mixTabs[i].mixName === name)
                return i
        }
        return -1
    }

    function ensureCurrentMix() {
        var idx = indexOfMix(currentMixName)
        if (idx < 0) {
            if (currentMixName && mixData[currentMixName] && mixData[currentMixName].stereo_pair) {
                var partner = mixData[currentMixName].stereo_pair
                var partnerIdx = indexOfMix(partner)
                if (partnerIdx >= 0) {
                    currentMixName = mixTabs[partnerIdx].mixName
                    return
                }
            }
            if (mixTabs.length > 0)
                currentMixName = mixTabs[0].mixName
        } else if (idx >= mixTabs.length && mixTabs.length > 0) {
            currentMixName = mixTabs[mixTabs.length - 1].mixName
        }
    }

    onMixTabsChanged: ensureCurrentMix()
    Component.onCompleted: {
        mixTabs = buildMixTabs()
        ensureCurrentMix()
    }

    function isPairLinked(left, right) {
        var leftMix = mixData[left]
        return !!(leftMix && leftMix.stereo_pair === right)
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
                Layout.preferredWidth: Math.min(root.width * 0.75, implicitWidth)
                currentIndex: Math.max(0, root.indexOfMix(root.currentMixName))
                onCurrentIndexChanged: {
                    if (currentIndex >= 0 && currentIndex < root.mixTabs.length)
                        root.currentMixName = root.mixTabs[currentIndex].mixName
                }

                Repeater {
                    model: root.mixTabs
                    TabButton {
                        text: modelData.label
                        leftPadding: 20
                        rightPadding: 20
                        implicitWidth: Math.max(150, contentItem.implicitWidth + leftPadding + rightPadding)
                        checkable: true
                        checked: index === mixTabBar.currentIndex
                        onClicked: mixTabBar.currentIndex = index
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            radius: 12
            color: "#1f1f1f"
            border.color: "#3a3a3a"
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        text: "Stereo Mix Links"
                        font.pixelSize: 18
                        Layout.fillWidth: true
                    }

                    Label {
                        text: "Link neighbouring mixes to create stereo tabs"
                        font.pixelSize: 12
                        opacity: 0.65
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    Layout.preferredHeight: childrenRect.height
                    spacing: 10

                    Repeater {
                        model: root.stereoPairs
                        delegate: Button {
                            text: modelData.label
                            width: 120
                            highlighted: root.isPairLinked(modelData.left, modelData.right)
                            enabled: Boolean(root.mixData[modelData.left]) && Boolean(root.mixData[modelData.right])
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

        StackLayout {
            id: mixStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: Math.max(0, root.indexOfMix(root.currentMixName))

            Repeater {
                model: root.mixTabs
                Loader {
                    sourceComponent: mixPageComponent
                    property string mixName: modelData.mixName
                    property string stereoPartner: modelData.stereoPartner
                    onLoaded: {
                        if (item)
                            item.mixName = mixName
                        if (item)
                            item.stereoPartner = stereoPartner
                    }
                    onMixNameChanged: {
                        if (item)
                            item.mixName = mixName
                    }
                    onStereoPartnerChanged: {
                        if (item)
                            item.stereoPartner = stereoPartner
                    }
                }
            }
        }
    }

    Component {
        id: mixPageComponent
        Item {
            id: mixPage
            anchors.fill: parent
            property string mixName
            property string stereoPartner: ""
            readonly property var mixState: root.mixData[mixName] || null
            readonly property bool isStereo: !!(mixState && mixState.stereo_pair)
            property real channelStripHeight: 420

            Component {
                id: channelStripComponent
                Item {
                    id: channelStrip
                    width: 120
                    height: mixPage.channelStripHeight
                    property string mixName: mixPage.mixName
                    property int channelIndex: index
                    property var channelData: modelData
                    property bool showPan: mixPage.isStereo

                    function sync() {
                        if (!channelData)
                            return
                        if (Math.abs(channelVolumeSlider.value - channelData.volume) > 0.0005) {
                            channelVolumeSlider.syncing = true
                            channelVolumeSlider.value = channelData.volume
                        }
                        var panTarget = channelStrip.showPan && channelData ? channelData.pan : 0
                        if (channelPanDial.visible && Math.abs(channelPanDial.value - panTarget) > 0.0005) {
                            channelPanDial.syncing = true
                            channelPanDial.value = panTarget
                        } else if (!channelStrip.showPan && Math.abs(channelPanDial.value) > 0.0005) {
                            channelPanDial.syncing = true
                            channelPanDial.value = 0
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
                    onShowPanChanged: sync()
                    Component.onCompleted: sync()

                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        color: "#1e1e1e"
                        border.color: "#323232"
                        border.width: 1

                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            Text {
                                text: channelData ? channelData.name : ""
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignHCenter
                                width: parent.width
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                            }

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: "#2c2c2c"
                                opacity: 0.6
                            }

                            Item {
                                width: parent.width
                                height: 220

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: 0
                                    spacing: 10

                                    Rectangle {
                                        width: 18
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        radius: 7
                                        color: "#101010"
                                        border.color: "#272727"
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
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: 42
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
                            }

                            Column {
                                visible: channelStrip.showPan
                                width: parent.width
                                spacing: 4

                                Dial {
                                    id: channelPanDial
                                    from: -1
                                    to: 1
                                    stepSize: 0.01
                                    value: 0
                                    visible: channelStrip.showPan
                                    enabled: channelStrip.showPan
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 68
                                    height: 68
                                    property bool syncing: false
                                    onValueChanged: {
                                        if (syncing) {
                                            syncing = false
                                            return
                                        }
                                        if (channelStrip.showPan)
                                            bridge.setChannelPan(channelStrip.mixName, channelStrip.channelIndex, value)
                                    }
                                }

                                Text {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    font.pixelSize: 11
                                    opacity: 0.75
                                    text: channelStrip.showPan && channelData ? channelStrip.formatPan(channelData.pan) : "Pan Center"
                                }
                            }

                            Item {
                                width: parent.width
                                height: channelStrip.showPan ? 4 : 0
                            }

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 6

                                Button {
                                    id: muteButton
                                    text: "M"
                                    checkable: true
                                    font.pixelSize: 12
                                    width: 42
                                    height: 28
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
                                    width: 42
                                    height: 28
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

                            Rectangle {
                                width: parent.width
                                height: 4
                                radius: 2
                                color: "#303030"
                            }

                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                font.pixelSize: 11
                                opacity: 0.7
                                text: channelData ? "Vol " + Math.round(channelData.volume * 100) / 100 : ""
                            }
                        }
                    }

                    function formatPan(value) {
                        if (value > 0.01)
                            return "Pan R " + Math.round(value * 100) / 100
                        if (value < -0.01)
                            return "Pan L " + Math.round(Math.abs(value) * 100) / 100
                        return "Pan Center"
                    }
                }
            }

            function syncControls() {
                var state = mixState

                var volumeTarget = state ? state.volume : 0
                if (Math.abs(masterVolumeSlider.value - volumeTarget) > 0.0005) {
                    masterVolumeSlider.syncing = true
                    masterVolumeSlider.value = volumeTarget
                }

                var targetPan = (state && mixPage.isStereo) ? state.pan : 0
                if (Math.abs(masterPanDial.value - targetPan) > 0.0005) {
                    masterPanDial.syncing = true
                    masterPanDial.value = targetPan
                }

                var muteTarget = state ? state.mute : false
                if (mixMuteButton.checked !== muteTarget) {
                    mixMuteButton.syncing = true
                    mixMuteButton.checked = muteTarget
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
                        text: mixPage.isStereo ? "Stereo with Mix " + (mixState ? mixState.stereo_pair : mixPage.stereoPartner) : "Mono mix"
                        opacity: 0.7
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
                            onHeightChanged: mixPage.channelStripHeight = Math.max(420, height - 32)
                            Component.onCompleted: mixPage.channelStripHeight = Math.max(420, height - 32)

                            Row {
                                id: channelRow
                                spacing: 16
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                height: parent.height
                                Repeater {
                                    id: channelRepeater
                                    model: mixState && mixState.channels ? mixState.channels : []
                                    delegate: channelStripComponent
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
                                text: mixPage.isStereo ? "Linked with Mix " + (mixState ? mixState.stereo_pair : mixPage.stereoPartner) : "Mono Output"
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
                                font.pixelSize: 13
                                opacity: 0.7
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
                                    Layout.preferredWidth: 72
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: 10

                                    Slider {
                                        id: masterVolumeSlider
                                        orientation: Qt.Vertical
                                        from: 0
                                        to: 1
                                        stepSize: 0.01
                                        value: 0.75
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.fillHeight: true
                                        Layout.preferredWidth: 46
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
                                        text: mixState ? "Vol " + Math.round(mixState.volume * 100) / 100 : "Vol 0"
                                        horizontalAlignment: Text.AlignHCenter
                                        Layout.fillWidth: true
                                        font.pixelSize: 12
                                        opacity: 0.75
                                    }
                                }

                                ColumnLayout {
                                    visible: mixPage.isStereo
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: 96
                                    spacing: 8

                                    Dial {
                                        id: masterPanDial
                                        from: -1
                                        to: 1
                                        stepSize: 0.01
                                        value: 0
                                        visible: mixPage.isStereo
                                        enabled: mixPage.isStereo
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.preferredWidth: 86
                                        Layout.preferredHeight: 86
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
                                        text: mixPage.isStereo && mixState ? (mixState.pan > 0.01 ? "Pan R " + Math.round(mixState.pan * 100) / 100 : mixState.pan < -0.01 ? "Pan L " + Math.round(Math.abs(mixState.pan) * 100) / 100 : "Pan Center") : "Pan Center"
                                        horizontalAlignment: Text.AlignHCenter
                                        Layout.fillWidth: true
                                        font.pixelSize: 12
                                        opacity: 0.75
                                    }
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
