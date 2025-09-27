import QtQuick 2.15
import QtQuick.Controls.Material 2.15

Item {
    id: root

    implicitWidth: 44
    implicitHeight: 220

    property real from: 0.0
    property real to: 1.0
    property real stepSize: 0.0
    property real value: 0.0
    property bool syncing: false
    property bool pressed: pointer.active

    property color grooveColor: "#121212"
    property color trackColor: "#2f2f2f"
    property color handleColor: "#f2f2f2"
    property color handleBorderColor: "#5e5e5e"
    property color handleActiveColor: "#d6d6d6"

    signal userValueChanged(real value)

    readonly property real _minValue: Math.min(from, to)
    readonly property real _maxValue: Math.max(from, to)
    readonly property real _range: _maxValue - _minValue
    readonly property real _handleHeight: Math.max(34, Math.min(height * 0.35, 48))
    readonly property real _topLimit: _handleHeight / 2
    readonly property real _bottomLimit: height - _handleHeight / 2
    readonly property real _handleCenter: _range === 0
                                       ? (_topLimit + _bottomLimit) / 2
                                       : _bottomLimit - (_bottomLimit - _topLimit) * ((value - _minValue) / _range)

    function _clamp(val, lo, hi) {
        return val < lo ? lo : (val > hi ? hi : val)
    }

    function setFromPosition(posY) {
        var center = _clamp(posY, _topLimit, _bottomLimit)
        var ratio = (_bottomLimit - center) / (_bottomLimit - _topLimit)
        var newValue = _minValue + ratio * _range
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
        id: track
        anchors.fill: parent
        radius: width / 2
        color: grooveColor
        border.color: "#2a2a2a"
        border.width: 1
    }

    Rectangle {
        id: fill
        anchors.horizontalCenter: track.horizontalCenter
        width: track.width
        height: _bottomLimit - _handleCenter + _handleHeight / 2
        anchors.bottom: track.bottom
        radius: track.radius
        color: trackColor
        opacity: 0.7
    }

    Rectangle {
        id: handle
        width: Math.max(24, track.width - 10)
        height: _handleHeight
        radius: 6
        color: pressed ? handleActiveColor : handleColor
        border.color: handleBorderColor
        border.width: 1
        anchors.horizontalCenter: track.horizontalCenter
        y: _handleCenter - height / 2
        layer.enabled: true
        layer.smooth: true

        Rectangle {
            anchors.fill: parent
            anchors.margins: 6
            radius: 4
            color: "#ffffff"
            opacity: 0.08
        }
    }

    TapHandler {
        id: pointer
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        gesturePolicy: TapHandler.DragThreshold
        enabled: root.enabled
        onPressedChanged: {
            if (pressed) {
                root.forceActiveFocus()
                root.setFromPosition(point.position.y)
            }
        }
        onPositionChanged: {
            if (active)
                root.setFromPosition(point.position.y)
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        enabled: root.enabled
        onWheel: {
            var step = stepSize > 0.0 ? stepSize : (_range > 0 ? _range / 100 : 0.01)
            var delta = wheel.angleDelta.y / 120
            var newValue = value + delta * step
            newValue = _clamp(newValue, _minValue, _maxValue)
            if (Math.abs(newValue - value) > 0.0005)
                value = newValue
        }
    }
}
