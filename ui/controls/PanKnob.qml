import QtQuick 2.15
import QtQuick.Controls.Material 2.15

Item {
    id: root

    property real from: -1.0
    property real to: 1.0
    property real stepSize: 0.01
    property real value: 0.0
    property bool syncing: false
    property bool pressed: pointer.active
    property real diameter: 68
    property color baseColor: "#252525"
    property color rimColor: "#3c3c3c"
    property color glowColor: "#4a90e2"

    signal userValueChanged(real value)

    implicitWidth: diameter
    implicitHeight: diameter
    width: diameter
    height: diameter

    readonly property real _minValue: Math.min(from, to)
    readonly property real _maxValue: Math.max(from, to)
    readonly property real _range: _maxValue - _minValue
    readonly property real _normalized: _range === 0 ? 0.5 : (value - _minValue) / _range
    readonly property real _minAngle: -135
    readonly property real _maxAngle: 135
    readonly property real _angle: _minAngle + (_maxAngle - _minAngle) * _normalized

    function _clamp(val, lo, hi) {
        return val < lo ? lo : (val > hi ? hi : val)
    }

    function adjustBy(delta) {
        if (_range <= 0)
            return
        var factor = _range / 150
        var newValue = value + delta * factor
        if (stepSize > 0.0)
            newValue = Math.round(newValue / stepSize) * stepSize
        newValue = _clamp(newValue, _minValue, _maxValue)
        if (Math.abs(newValue - value) > 0.0005)
            value = newValue
    }

    function setFromExternal(newValue) {
        var clamped = _clamp(newValue, _minValue, _maxValue)
        if (Math.abs(clamped - value) > 0.0005) {
            syncing = true
            value = clamped
        }
    }

    onValueChanged: {
        if (syncing) {
            syncing = false
            return
        }
        userValueChanged(value)
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: baseColor
        border.color: pressed ? glowColor : rimColor
        border.width: pressed ? 3 : 2
        layer.enabled: true
        layer.smooth: true
    }

    Rectangle {
        anchors.centerIn: parent
        width: diameter * 0.8
        height: width
        radius: width / 2
        color: "#1a1a1a"
        border.color: pressed ? glowColor : "#555555"
        border.width: 1
    }

    Item {
        id: pointerRoot
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        rotation: _angle

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.verticalCenter
            width: 4
            height: parent.height / 2 - 12
            radius: 2
            color: "#f5f5f5"
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.verticalCenter
            width: 6
            height: 12
            radius: 3
            color: "#bbbbbb"
        }
    }

    TapHandler {
        id: pointer
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        gesturePolicy: TapHandler.DragThreshold
        enabled: root.enabled
        property real lastY: 0
        onPressedChanged: {
            if (pressed) {
                root.forceActiveFocus()
                lastY = point.position.y
            }
        }
        onPointChanged: {
            if (!active)
                return
            var dy = lastY - point.position.y
            lastY = point.position.y
            root.adjustBy(dy)
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        enabled: root.enabled
        onWheel: {
            var delta = wheel.angleDelta.y / 120
            root.adjustBy(delta * 6)
        }
    }
}
