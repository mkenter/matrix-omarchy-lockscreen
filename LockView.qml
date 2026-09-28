import QtQuick
import QtQuick.Effects

Item {
  id: root

  property string backgroundPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""
  property bool syncingPasswordText: false
  property bool showPrompt: false
  property var terminalLines: []

  readonly property int terminalPadding: 56
  readonly property int terminalFontSize: 28
  readonly property int terminalLetterSpacing: 2

  readonly property string placeholderText: "Enter Password"
  readonly property int fieldWidth: 381
  readonly property int fieldHeight: 67
  readonly property int outlineThickness: 3
  readonly property int fieldFontSize: Math.round(Style.font.heading * 1.125)
  readonly property int passwordDotFontSize: Math.round(Style.font.heading * 1.33)
  readonly property int passwordDotLetterSpacing: Math.round(Style.font.heading * 0.19)
  // Space to keep clear on each side of the field for the fingerprint icon
  // (icon width plus a gap) so the centered dots never run under it.
  readonly property real fingerprintReserve: fingerprintConfigured ? Math.round(fingerprintIcon.implicitWidth + 12) : 0
  // Shrink the dots to fit once the password outgrows the field, so every
  // keystroke stays visible — otherwise long passwords clip with no feedback.
  readonly property real passwordDotScale: dotMetrics.advanceWidth > 0
    ? Math.min(1, (passwordInput.width - 4) / dotMetrics.advanceWidth)
    : 1
  readonly property bool showPasswordCursor: inputEnabled && !authenticatingPassword && failureMessage.length === 0
  readonly property bool errorState: failureMessage.length > 0
  readonly property var inputBorderSpec: errorState
    ? Border.surfaceSpec("lock", "border-error", Color.lock.borderError, root.outlineThickness, "border-alpha")
    : Border.surfaceSpec("lock", "border-active", Color.lock.borderActive, root.outlineThickness, "border-alpha")

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()

  // Cache-busts the lock background by appending `?v=`. Adding a query
  // string keeps Image's loader happy while forcing it to reload when the
  // user picks a new background mid-session.
  function fileUrl(path) {
    if (!path) return ""
    var encoded = String(path).split("/").map(encodeURIComponent).join("/")
    return "file://" + encoded + "?v=" + backgroundVersion
  }

  function forcePasswordFocus() {
    passwordInput.forceActiveFocus()
  }

  function clearPassword() {
    passwordTextEdited("")
  }

  function appendTerminalLine(line) {
    var lines = terminalLines.slice()
    lines.push(line)

    // Keep enough history for several failed attempts without
    // eventually running off the bottom of the screen.
    if (lines.length > 16)
      lines = lines.slice(lines.length - 16)

    terminalLines = lines
  }

  function terminalDisplayText() {
    var lines = terminalLines.slice()

    if (!authenticatingPassword)
      lines.push("> " + "●".repeat(passwordText.length))

    return lines.join("\n")
  }

  function syncPasswordText() {
    if (passwordInput.text === passwordText) return
    syncingPasswordText = true
    passwordInput.text = passwordText
    syncingPasswordText = false
  }

  onPasswordTextChanged: syncPasswordText()

  onFailureMessageChanged: {
    if (failureMessage.length > 0) {
      appendTerminalLine(failureMessage.toUpperCase())
      showPrompt = true
      promptHideTimer.stop()
    }
  }

  onInputEnabledChanged: {
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }
  Component.onCompleted: {
    syncPasswordText()
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }

  Timer {
    id: promptHideTimer
    interval: 5000
    repeat: false
    onTriggered: {
      if (!root.authenticatingPassword && root.failureMessage.length === 0) {
        root.showPrompt = false
        root.terminalLines = []
      }
    }
  }

  function revealPrompt() {
    showPrompt = true
    promptHideTimer.restart()
    forcePasswordFocus()
  }

  // Measures the masked password at full size; passwordDotScale compares this
  // against the field width to decide how far the dots must shrink to fit.

  Rectangle {
    anchors.fill: parent
    color: Color.background

    Item {
      anchors.fill: parent
      clip: true

      MatrixRain {
        id: matrixRain
        anchors.fill: parent
        anchors.margins: -32

        layer.enabled: true

        layer.effect: MultiEffect {
          blurEnabled: true
          blur: 0.35
          blurMax: 32
        }
      }
    }

    Item {
      id: crtScreen
      anchors.fill: parent
      z: 20

      property real progress: root.showPrompt ? 1.0 : 0.0

      opacity: progress > 0.001 ? 1 : 0

      Behavior on progress {
        NumberAnimation {
          duration: root.showPrompt ? 190 : 145
          easing.type: root.showPrompt
            ? Easing.OutCubic
            : Easing.InCubic
        }
      }

      transform: Scale {
        origin.x: crtScreen.width / 2
        origin.y: crtScreen.height / 2
        xScale: 1.0
        yScale: Math.max(0.003, crtScreen.progress)
      }

      Rectangle {
        anchors.fill: parent
        color: "#010502"
      }

      // Subtle horizontal CRT scanlines.
      Canvas {
        anchors.fill: parent
        opacity: 0.14

        onPaint: {
          var ctx = getContext("2d")
          ctx.clearRect(0, 0, width, height)
          ctx.fillStyle = "#000000"

          for (var y = 0; y < height; y += 4)
            ctx.fillRect(0, y, width, 1)
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
      }

      Rectangle {
        anchors.fill: parent
        color: Qt.rgba(45 / 255, 110 / 255, 55 / 255, 0.045)
      }

      Item {
        id: terminalPrompt
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: root.terminalPadding
        anchors.topMargin: root.terminalPadding

        width: terminalText.implicitWidth
        height: terminalText.implicitHeight

        // Wide phosphor bloom.
        Text {
          x: 0
          y: 0
          text: terminalText.text
          textFormat: Text.PlainText
          color: Qt.rgba(75 / 255, 195 / 255, 90 / 255, 0.34)

          font.family: "monospace"
          font.pixelSize: root.terminalFontSize
          font.letterSpacing: root.terminalLetterSpacing

          layer.enabled: true
          layer.effect: MultiEffect {
            blurEnabled: true
            blur: 0.72
            blurMax: 48
          }
        }

        // Tighter inner glow.
        Text {
          x: 0
          y: 0
          text: terminalText.text
          textFormat: Text.PlainText
          color: Qt.rgba(115 / 255, 225 / 255, 125 / 255, 0.42)

          font.family: "monospace"
          font.pixelSize: root.terminalFontSize
          font.letterSpacing: root.terminalLetterSpacing

          layer.enabled: true
          layer.effect: MultiEffect {
            blurEnabled: true
            blur: 0.30
            blurMax: 24
          }
        }

        Text {
          id: terminalText
          textFormat: Text.PlainText

          text: root.terminalDisplayText()

          color: "#8fc99a"

          font.family: "monospace"
          font.pixelSize: root.terminalFontSize
          font.letterSpacing: root.terminalLetterSpacing

          layer.enabled: true
          layer.effect: MultiEffect {
            blurEnabled: true
            blur: 0.06
            blurMax: 8
          }
        }
      }
    }

    Rectangle {
      id: crtLine
      z: 21

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter

      height: 3
      color: "#d8ffe0"

      opacity: {
        var p = crtScreen.progress

        if (p <= 0 || p >= 0.24)
          return 0

        var distance = Math.abs(p - 0.08)
        return Math.max(0, 1.0 - distance / 0.16)
      }

      layer.enabled: true

      layer.effect: MultiEffect {
        blurEnabled: true
        blur: 0.8
        blurMax: 64
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: {
        root.wakeRequested()
        root.revealPrompt()
      }
      onPositionChanged: root.wakeRequested()
    }

    TextInput {
      id: passwordInput
      anchors.fill: parent
      opacity: 0

      activeFocusOnPress: true
      enabled: root.inputEnabled && !root.authenticatingPassword
      readOnly: root.authenticatingPassword
      echoMode: TextInput.Password

      onTextChanged: {
        if (!root.syncingPasswordText)
          root.passwordTextEdited(text)

        if (text.length > 0) {
          root.showPrompt = true
          promptHideTimer.restart()
          root.wakeRequested()
        }

        if (text.length > 0 && root.failureMessage.length > 0)
          root.clearFailureRequested()
      }

      onAccepted: {
        var submitted = root.passwordText

        if (submitted.length > 0) {
          root.appendTerminalLine("> " + "●".repeat(submitted.length))
          root.appendTerminalLine("CHECKING...")
        }

        root.passwordTextEdited("")

        if (submitted.length > 0)
          root.submitPassword(submitted)
      }

      Keys.onPressed: function(event) {
        root.showPrompt = true
        root.wakeRequested()

        if (
          event.key === Qt.Key_Escape ||
          ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_U)
        ) {
          root.passwordTextEdited("")
          event.accepted = true
        }
      }
    }
  }
}
