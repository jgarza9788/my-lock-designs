import QtQuick
import qs.Commons
import qs.Commons as Commons

// Frost: the screen frosts over like a window on a winter night. Ice creeps
// in from the corners and edges along feathery ferns until the wallpaper is
// only a cold blur behind it, with the time wiped clear as if by a finger.
// Typing breathes on the glass and melts a patch round the field, which
// freezes over again once you stop; a wrong password is a cold snap.
//
// Two shaders: frostfield.frag works out once where and how the frost grows,
// frost.frag draws the window from that. Both run at half size, and the window
// is drawn again only while something on it changes, so a fully frozen screen
// costs nothing. A seasonal design, so it keeps its own palette.
DesignBase {
  id: lock
  inputItem: field.input
  shakeOnFail: true
  flashOnFail: false

  // ---- The freeze ----------------------------------------------------------
  // Seconds from clear glass to frozen over.
  property real freezeSeconds: 60
  // Where it starts: 0 is clear glass, a little more has the corners frosted
  // the moment the lock comes up.
  property real startFrost: 0
  // Steps a second while the frost grows. It creeps, so this can be low.
  property int growFps: 15
  // How far the frost veins run ahead of the frost front, and how much sooner
  // the bottom of the glass freezes than the top.
  property real veinPush: 0.4
  property real bottomBias: 0.15
  // A different fern pattern per number.
  property real seed: 7
  // How far a frozen screen is in boot snapshots and thumbnails.
  property real snapshotFrost: 0.9

  // ---- The look ------------------------------------------------------------
  readonly property color iceColor: "#eef6ff"
  readonly property color textColor: "#ffffff"
  // How white the thickest frost goes (1 hides the wallpaper, lower lets it
  // show through), and how much the clear glass mists.
  property real iceAmount: 0.55
  property real fogAmount: 0.25
  // How far ahead of the frost front the view blurs, as a share of the freeze.
  property real mistWidth: 0.2

  // ---- The breath ----------------------------------------------------------
  // Radius of the melted patch round the field, in screen heights: a start,
  // and how much each key adds (up to ten).
  property real breathSize: 0.11
  property real breathGrowth: 0.012
  // Milliseconds after the last key before it freezes over again, and how
  // long that takes.
  property int refreezeDelay: 2500
  property int refreezeDuration: 5000
  // How much of the remaining freeze a wrong password skips.
  property real coldSnap: 0.35

  // ---- State ---------------------------------------------------------------
  property real elapsed: 0
  property real breath: 0
  readonly property real progress: {
    var t = Math.min(1, elapsed / Math.max(1, freezeSeconds))
    return startFrost + (1 - startFrost) * (1 - Math.pow(1 - t, 1.6))
  }
  readonly property real shownProgress: snapshotMode ? snapshotFrost : progress
  readonly property int halfW: Math.max(1, Math.round(width / 2))
  readonly property int halfH: Math.max(1, Math.round(height / 2))

  Timer {
    interval: Math.round(1000 / Math.max(1, lock.growFps))
    repeat: true
    running: lock.animating && lock.elapsed < lock.freezeSeconds
    onTriggered: lock.elapsed = Math.min(lock.freezeSeconds, lock.elapsed + interval / 1000)
  }

  function breathe() {
    breathDown.stop()
    if (!breathUp.running && breath < 1) breathUp.restart()
    refreeze.restart()
  }

  NumberAnimation {
    id: breathUp
    target: lock; property: "breath"; to: 1
    duration: 700; easing.type: Easing.OutCubic
  }
  NumberAnimation {
    id: breathDown
    target: lock; property: "breath"; to: 0
    duration: lock.refreezeDuration; easing.type: Easing.InOutSine
  }
  Timer {
    id: refreeze
    interval: lock.refreezeDelay
    onTriggered: breathDown.restart()
  }

  Typing {
    lock: lock
    onTyped: lock.breathe()
    onCleared: refreeze.restart()
  }

  Connections {
    target: lock
    function onFailureMessageChanged() {
      if (lock.failureMessage.length === 0) return
      breathUp.stop()
      refreeze.stop()
      breathDown.stop()
      lock.breath = 0
      lock.elapsed += (lock.freezeSeconds - lock.elapsed) * lock.coldSnap
    }
  }

  // ---- The view through the glass, and what the shaders read ---------------
  Wallpaper { id: view; anchors.fill: parent; lock: lock; blur: 0; dim: 0.05; vignette: false }
  Wallpaper { id: viewBlurred; anchors.fill: parent; lock: lock; blur: 1; dim: 0; contrast: 0; vignette: false }

  // Both are still pictures: the sources are drawn again only when the
  // wallpaper changes.
  ShaderEffectSource {
    id: sharpSource
    sourceItem: view
    hideSource: true
    textureSize: Qt.size(lock.halfW, lock.halfH)
  }
  ShaderEffectSource {
    id: blurredSource
    sourceItem: viewBlurred
    hideSource: true
    textureSize: Qt.size(lock.halfW / 2, lock.halfH / 2)
  }

  ShaderEffect {
    id: frostField
    anchors.fill: parent
    property real aspect: width / Math.max(1, height)
    property real seed: lock.seed
    property real veinPush: lock.veinPush
    property real bottomBias: lock.bottomBias
    fragmentShader: Qt.resolvedUrl("shaders/frostfield.frag.qsb")
    blending: false
  }
  ShaderEffectSource {
    id: fieldSource
    sourceItem: frostField
    hideSource: true
    textureSize: Qt.size(lock.halfW, lock.halfH)
  }

  // The time and date as the shader wipes them out of the frost.
  Item {
    id: timeArt
    anchors.fill: parent

    Text {
      id: timeText
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: -Math.round(lock.height * 0.08)
      text: lock.clock("HH:mm")
      textFormat: Text.PlainText
      color: "white"
      font.family: Style.font.family
      font.weight: Font.Black
      font.pixelSize: Math.round(lock.height * 0.22)
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: timeText.bottom
      anchors.topMargin: -Math.round(lock.height * 0.01)
      text: lock.date("dddd, d MMMM")
      textFormat: Text.PlainText
      color: "white"
      font.family: Style.font.family
      font.weight: Font.Bold
      font.pixelSize: Math.round(lock.height * 0.04)
    }
  }
  ShaderEffectSource {
    id: timeSource
    sourceItem: timeArt
    hideSource: true
    textureSize: Qt.size(lock.halfW, lock.halfH)
  }

  // ---- The window ----------------------------------------------------------
  // In a half-size layer, so the per-pixel work is a quarter of the screen and
  // a frozen, quiet window is a cached picture.
  Item {
    anchors.fill: parent
    layer.enabled: true
    layer.smooth: true
    layer.textureSize: Qt.size(lock.halfW, lock.halfH)

    ShaderEffect {
      anchors.fill: parent
      property real progress: lock.shownProgress
      property real aspect: width / Math.max(1, height)
      property real breathX: (field.x + field.width / 2) / Math.max(1, lock.width)
      property real breathY: (field.y + field.height / 2) / Math.max(1, lock.height)
      property real breathSize: lock.breathSize + lock.breathGrowth * Math.min(10, lock.passwordText.length)
      property real breath: lock.snapshotMode ? 0 : lock.breath
      property real iceAmount: lock.iceAmount
      property real fogAmount: lock.fogAmount
      property real mistWidth: lock.mistWidth
      property real timeOpacity: lock.hideTime ? 0 : 1
      property point texel: Qt.point(1 / lock.halfW, 1 / lock.halfH)
      property color iceColor: lock.iceColor
      property color textColor: lock.textColor
      property variant sharp: sharpSource
      property variant blurred: blurredSource
      property variant field: fieldSource
      property variant timeMask: timeSource
      fragmentShader: Qt.resolvedUrl("shaders/frost.frag.qsb")
      blending: false
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  PasswordField {
    id: field
    lock: lock
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: Math.round(lock.height * 0.27)
    width: 380; height: 56; radius: 28
    opacity: lock.snapshotMode ? 0 : 1
    showLockGlyph: false
    color: Qt.rgba(0.06, 0.1, 0.16, 0.45)
    placeholder: lock.greeting() + ", " + lock.displayName
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 40
    opacity: lock.snapshotMode ? 0 : 1
    text: lock.failedAttempts > 0
      ? lock.tr(lock.failedAttempts === 1 ? "1 failed attempt" : "%1 failed attempts").arg(lock.failedAttempts)
      : lock.tr("Press Enter to unlock")
    textFormat: Text.PlainText
    color: lock.failedAttempts > 0 ? Commons.Color.lock.textError : lock.textColor
    style: Text.Raised
    styleColor: Qt.rgba(0, 0, 0, 0.45)
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
  }
}
