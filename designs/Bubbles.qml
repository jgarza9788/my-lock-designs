import QtQuick
import qs.Commons
import qs.Commons as Commons

// Bubbles: your wallpaper with soap bubbles drifting over it, the way the
// old Windows Vista screensaver had them. They bounce off the edges of the
// screen and off each other, their rainbow rims turning slowly as they go.
// Every key gives one of them a push; a wrong password pops the lot, and new
// ones blow in a moment later.
//
// Each bubble is a small shader over its own square: the wallpaper behind it
// bent as through a lens, a thin-film rainbow swirling over it and a window
// reflected in it. One FrameAnimation moves them all.
DesignBase {
  id: lock
  inputItem: field.input
  shakeOnFail: true
  flashOnFail: false

  // ---- The bubbles ---------------------------------------------------------
  // How many, as one per this many square pixels of screen, within a range.
  property int pixelsPerBubble: 140000
  property int minBubbles: 6
  property int maxBubbles: 16
  // Diameter, in screen heights.
  property real minSize: 0.08
  property real maxSize: 0.2
  // Drifting speed in screen heights a second. A push fades back to this.
  property real minSpeed: 0.04
  property real maxSpeed: 0.09
  // How hard a key pushes a bubble, in screen heights a second.
  property real keyPush: 0.35
  // How much a bubble wobbles out of round, at rest and just after a bump.
  property real wobbleRest: 0.015
  property real wobbleBump: 0.08
  // A different arrangement per number (also what the snapshots show).
  property int seed: 11

  // ---- The look ------------------------------------------------------------
  // How strong the rainbow film is (0 clear glass, 1 strong), and how much the
  // view through a bubble bends towards its rim.
  property real filmAmount: 0.8
  property real lens: 0.35

  // ---- State ---------------------------------------------------------------
  readonly property int count: Math.max(0, Math.min(maxBubbles, Math.max(minBubbles,
    Math.round(width * height / Math.max(1, pixelsPerBubble)))))
  // Per bubble: centre, velocity, radius and wobble, kept in plain JS so
  // the frame loop does not go through QML properties for its arithmetic.
  property var bodies: []
  property real elapsed: 0

  function rng(s) {
    s = s >>> 0
    return function() {
      s = (s + 0x6D2B79F5) >>> 0
      var t = s
      t = Math.imul(t ^ (t >>> 15), t | 1)
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296
    }
  }

  // A free spot for a bubble of radius r, away from the others where it can.
  function place(b, r, rand, others) {
    for (var tries = 0; tries < 40; tries++) {
      b.x = r + rand() * Math.max(1, width - 2 * r)
      b.y = r + rand() * Math.max(1, height - 2 * r)
      var clear = true
      for (var j = 0; j < others.length; j++) {
        var o = others[j]
        if (o === b || o.popped) continue
        var dx = o.x - b.x, dy = o.y - b.y
        if (dx * dx + dy * dy < (o.r + r) * (o.r + r)) { clear = false; break }
      }
      if (clear) return
    }
  }

  function reset() {
    if (width <= 0 || height <= 0) { bodies = []; return }
    var rand = rng(seed)
    var list = []
    for (var i = 0; i < count; i++) {
      var r = height * (minSize + (maxSize - minSize) * Math.pow(rand(), 1.4)) / 2
      var a = rand() * Math.PI * 2
      var speed = height * (minSpeed + (maxSpeed - minSpeed) * rand())
      var b = { x: 0, y: 0, r: r, vx: Math.cos(a) * speed, vy: Math.sin(a) * speed, base: speed,
                phase: rand() * 6.28,
                wobble: wobbleRest, popped: false }
      place(b, r, rand, list)
      list.push(b)
    }
    bodies = list
    publish()
  }

  // Copy the bodies onto the bubble items.
  function publish() {
    for (var i = 0; i < bodies.length; i++) {
      var item = bubbles.itemAt(i)
      if (!item) continue
      var b = bodies[i]
      var w = b.wobble * Math.sin(elapsed * 5.2 + b.phase)
      item.cx = b.x
      item.cy = b.y
      item.squashX = 1 + w
      item.squashY = 1 - w
    }
  }

  function step(dt) {
    var list = bodies, n = list.length, i, b
    for (i = 0; i < n; i++) {
      b = list[i]
      b.x += b.vx * dt
      b.y += b.vy * dt
      b.wobble += (wobbleRest - b.wobble) * Math.min(1, dt * 1.5)
      // A push dies away to the bubble's own drifting speed.
      var v = Math.sqrt(b.vx * b.vx + b.vy * b.vy)
      if (v > 0.001) {
        var k = 1 + (b.base / v - 1) * Math.min(1, dt * 0.6)
        b.vx *= k
        b.vy *= k
      }
      if (b.x < b.r) { b.x = b.r; b.vx = Math.abs(b.vx); b.wobble = Math.max(b.wobble, wobbleBump * 0.5) }
      else if (b.x > width - b.r) { b.x = width - b.r; b.vx = -Math.abs(b.vx); b.wobble = Math.max(b.wobble, wobbleBump * 0.5) }
      if (b.y < b.r) { b.y = b.r; b.vy = Math.abs(b.vy); b.wobble = Math.max(b.wobble, wobbleBump * 0.5) }
      else if (b.y > height - b.r) { b.y = height - b.r; b.vy = -Math.abs(b.vy); b.wobble = Math.max(b.wobble, wobbleBump * 0.5) }
    }
    // Bubbles bounce off each other like billiard balls, heavier the bigger.
    for (i = 0; i < n; i++) {
      var p = list[i]
      if (p.popped) continue
      for (var j = i + 1; j < n; j++) {
        var q = list[j]
        if (q.popped) continue
        var dx = q.x - p.x, dy = q.y - p.y
        var reach = p.r + q.r
        var d2 = dx * dx + dy * dy
        if (d2 >= reach * reach || d2 < 0.0001) continue
        var d = Math.sqrt(d2)
        var nx = dx / d, ny = dy / d
        var mp = p.r * p.r, mq = q.r * q.r
        var overlap = reach - d
        p.x -= nx * overlap * mq / (mp + mq)
        p.y -= ny * overlap * mq / (mp + mq)
        q.x += nx * overlap * mp / (mp + mq)
        q.y += ny * overlap * mp / (mp + mq)
        var rel = (p.vx - q.vx) * nx + (p.vy - q.vy) * ny
        if (rel <= 0) continue
        var impulse = 2 * rel / (mp + mq)
        p.vx -= impulse * mq * nx
        p.vy -= impulse * mq * ny
        q.vx += impulse * mp * nx
        q.vy += impulse * mp * ny
        p.wobble = Math.max(p.wobble, wobbleBump)
        q.wobble = Math.max(q.wobble, wobbleBump)
      }
    }
    elapsed += dt
    publish()
  }

  // A key: one bubble at random gets a push.
  function nudge() {
    if (bodies.length === 0) return
    var b = bodies[Math.floor(Math.random() * bodies.length)]
    var a = Math.random() * Math.PI * 2
    b.vx += Math.cos(a) * keyPush * height
    b.vy += Math.sin(a) * keyPush * height
    b.wobble = wobbleBump * 1.5
  }

  // A wrong password: every bubble pops, one after another.
  function popAll() {
    for (var i = 0; i < bodies.length; i++) {
      var item = bubbles.itemAt(i)
      if (!item) continue
      bodies[i].popped = true
      item.pop(Math.round(Math.random() * 450))
    }
  }

  // A popped bubble comes back somewhere else.
  function respawn(i) {
    var b = bodies[i]
    if (!b) return
    place(b, b.r, Math.random, bodies)
    var a = Math.random() * Math.PI * 2
    b.vx = Math.cos(a) * b.base
    b.vy = Math.sin(a) * b.base
    b.popped = false
    publish()
  }

  onCountChanged: Qt.callLater(reset)
  onWidthChanged: Qt.callLater(reset)
  onHeightChanged: Qt.callLater(reset)
  onSeedChanged: Qt.callLater(reset)

  FrameAnimation {
    running: lock.animating && !lock.snapshotMode && lock.bodies.length > 0
    onTriggered: lock.step(Math.min(0.05, frameTime))
  }

  Typing { lock: lock; onTyped: lock.nudge() }

  Connections {
    target: lock
    function onFailureMessageChanged() {
      if (lock.failureMessage.length > 0) lock.popAll()
    }
  }

  // ---- The scene -----------------------------------------------------------
  Wallpaper { id: wall; anchors.fill: parent; lock: lock; blur: 0; dim: 0.1; vignette: false }
  // What the bubbles see through themselves. A still picture, drawn again only
  // when the wallpaper changes.
  ShaderEffectSource {
    id: wallSource
    sourceItem: wall
    textureSize: Qt.size(Math.max(1, Math.round(lock.width / 2)), Math.max(1, Math.round(lock.height / 2)))
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  Repeater {
    id: bubbles
    model: lock.count
    onItemAdded: Qt.callLater(lock.reset)

    Item {
      id: bubble
      required property int index
      readonly property real diameter: {
        var b = lock.bodies[index]
        return b ? Math.max(8, Math.round(b.r * 2)) : 0
      }
      // Where each one tints its film: round the colour wheel, a step apart.
      readonly property real hue: (index * 0.137 + lock.seed * 0.05) % 1
      property real cx: -1000
      property real cy: -1000
      property real squashX: 1
      property real squashY: 1

      x: cx - diameter / 2
      y: cy - diameter / 2
      width: diameter
      height: diameter
      visible: diameter > 0
      transform: Scale { origin.x: bubble.width / 2; origin.y: bubble.height / 2; xScale: bubble.squashX; yScale: bubble.squashY }

      function pop(delay) {
        popAnim.stop()
        popDelay.duration = delay
        popAnim.start()
      }

      SequentialAnimation {
        id: popAnim
        paused: running && !lock.animating
        PauseAnimation { id: popDelay; duration: 0 }
        ParallelAnimation {
          NumberAnimation { target: skin; property: "scale"; to: 1.25; duration: 140; easing.type: Easing.OutQuad }
          NumberAnimation { target: skin; property: "opacity"; to: 0; duration: 140 }
          NumberAnimation { target: splash; property: "opacity"; from: 0.9; to: 0; duration: 380 }
          NumberAnimation { target: splash; property: "scale"; from: 0.9; to: 1.6; duration: 380; easing.type: Easing.OutCubic }
        }
        PauseAnimation { duration: 900 + Math.round(Math.random() * 900) }
        ScriptAction { script: lock.respawn(bubble.index) }
        ParallelAnimation {
          NumberAnimation { target: skin; property: "scale"; from: 0.15; to: 1; duration: 700; easing.type: Easing.OutBack }
          NumberAnimation { target: skin; property: "opacity"; from: 0; to: 1; duration: 400 }
        }
      }

      // The bubble itself, faded out by a pop while the ring below stays.
      Item {
        id: skin
        anchors.fill: parent

        ShaderEffect {
          anchors.fill: parent
          property vector2d center: Qt.vector2d(bubble.cx / Math.max(1, lock.width), bubble.cy / Math.max(1, lock.height))
          property vector2d radius: Qt.vector2d(bubble.diameter / 2 / Math.max(1, lock.width), bubble.diameter / 2 / Math.max(1, lock.height))
          property real time: lock.elapsed
          property real hue: bubble.hue
          property real filmAmount: lock.filmAmount
          property real lens: lock.lens
          property variant wall: wallSource
          fragmentShader: Qt.resolvedUrl("shaders/bubble.frag.qsb")
        }
      }

      // The ring a pop leaves for a moment.
      Rectangle {
        id: splash
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: Math.max(1, Math.round(bubble.diameter * 0.02))
        border.color: Qt.rgba(1, 1, 1, 0.8)
        opacity: 0
        antialiasing: true
      }
    }
  }

  // ---- The time and the field ----------------------------------------------
  Column {
    anchors.centerIn: parent
    anchors.verticalCenterOffset: -Math.round(lock.height * 0.06)
    spacing: 10
    visible: !lock.hideTime

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: lock.clock("HH:mm")
      textFormat: Text.PlainText
      color: Commons.Color.lock.text
      style: Text.Raised
      styleColor: Qt.rgba(0, 0, 0, 0.35)
      font.family: Style.font.family
      font.pixelSize: Math.round(Style.font.baseSize * 9)
      font.weight: Font.Light
      font.letterSpacing: 2
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: lock.date("dddd d MMMM")
      textFormat: Text.PlainText
      color: lock.withAlpha(Commons.Color.lock.text, 0.8)
      style: Text.Raised
      styleColor: Qt.rgba(0, 0, 0, 0.35)
      font.family: Style.font.family
      font.pixelSize: Style.font.title
      font.letterSpacing: 2
    }
  }

  PasswordField {
    id: field
    lock: lock
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: Math.round(lock.height * 0.16)
    width: 400
    height: 58
    radius: height / 2
    showLockGlyph: false
    placeholder: lock.tr("Password")
    color: lock.withAlpha(Commons.Color.lock.background, 0.6)
  }
}
