import QtQuick
import QtQuick.Effects
import Quickshell.Io
import qs.Commons
import qs.Ui

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
  property string userName: ""
  property bool syncingPasswordText: false
  property string currentTime: Qt.formatTime(new Date(), "HH:mm")
  property string currentDate: Qt.formatDate(new Date(), "dddd, d MMMM")
  property string batteryLevel: "--"
  property string batteryState: ""
  property string wifiName: "Wi-Fi"
  property string wifiSignal: ""

  readonly property string placeholderText: "Password"
  readonly property int fieldWidth: 140
  readonly property int fieldHeight: 45
  readonly property int outlineThickness: 3
  readonly property int fieldFontSize: Math.round(Style.font.heading * 1.125)
  readonly property int passwordDotFontSize: Math.round(Style.font.heading * 1.33)
  readonly property int passwordDotLetterSpacing: Math.round(Style.font.heading * 0.19)
  readonly property real fingerprintReserve: fingerprintConfigured ? Math.round(fingerprintIcon.implicitWidth + 12) : 0
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

  function syncPasswordText() {
    if (passwordInput.text === passwordText) return
    syncingPasswordText = true
    passwordInput.text = passwordText
    syncingPasswordText = false
  }

  function refreshStatus() {
    if (!batteryProcess.running) batteryProcess.running = true
    if (!networkProcess.running) networkProcess.running = true
  }

  function updateBattery(output) {
    var lines = String(output || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var parts = lines[i].split("\t")
      if (parts.length < 2) continue
      if (parts[0] === "percentage") root.batteryLevel = parts[1]
      if (parts[0] === "state") root.batteryState = parts[1]
    }
  }

  function updateNetwork(output) {
    var parts = String(output || "").trim().split("\t")
    if (parts.length >= 2 && parts[0] === "wifi") {
      root.wifiName = parts[1] || "Wi-Fi"
      root.wifiSignal = parts.length >= 3 ? parts[2] + "%" : ""
    } else {
      root.wifiName = "Sin conexión"
      root.wifiSignal = ""
    }
  }

  onPasswordTextChanged: syncPasswordText()
  onInputEnabledChanged: {
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }
  Component.onCompleted: {
    syncPasswordText()
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }

  Timer {
    interval: 1000
    repeat: true
    running: true
    onTriggered: {
      root.currentTime = Qt.formatTime(new Date(), "HH:mm")
      root.currentDate = Qt.formatDate(new Date(), "dddd, d MMMM")
    }
  }

  Timer {
    interval: 10000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refreshStatus()
  }

  Process {
    id: batteryProcess
    command: ["omarchy-battery-status", "--shell"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateBattery(text)
    }
  }

  Process {
    id: networkProcess
    command: ["omarchy-network-status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateNetwork(text)
    }
  }

  TextMetrics {
    id: dotMetrics
    font.family: "Inter"
    font.pixelSize: root.passwordDotFontSize
    font.letterSpacing: root.passwordDotLetterSpacing
    text: "●".repeat(passwordInput.text.length)
  }

  Rectangle {
    anchors.fill: parent
    color: Color.background

    Image {
      id: wallpaper
      anchors.fill: parent
      source: root.loadBackground ? root.fileUrl(root.backgroundPath) : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: false
      sourceSize.width: width
      sourceSize.height: height
    }

    Row {
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.topMargin: 34
      anchors.rightMargin: 42
      spacing: 22

      Text {
        text: "󰤨  " + root.wifiName
        color: Color.lock.text
        font.family: "Inter"
        font.pixelSize: Math.round(Style.font.heading * 0.72)
        opacity: 0.78
      }

      Text {
        text: (root.batteryState === "charging" ? "󰂄  " : "󰁹  ") + root.batteryLevel
        color: Color.lock.text
        font.family: "Inter"
        font.pixelSize: Math.round(Style.font.heading * 0.72)
        opacity: 0.78
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: { root.wakeRequested(); root.forcePasswordFocus() }
      onPositionChanged: root.wakeRequested()
    }

    Column {
      id: hero
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: 45
      spacing: 6

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.currentDate
        color: Color.lock.text
        font.family: "Inter"
        font.pixelSize: Math.round(Style.font.heading * 0.92)
        font.weight: Font.Medium
        opacity: 0.74
        horizontalAlignment: Text.AlignHCenter
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.currentTime
        color: Color.lock.text
        font.family: "Inter"
        font.pixelSize: Math.round(Style.font.heading * 4.1)
        font.weight: Font.Light
        font.letterSpacing: 1.0
        opacity: 0.96
        horizontalAlignment: Text.AlignHCenter
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.userName
        visible: text.length > 0
        color: Color.lock.text
        font.family: "Inter"
        font.pixelSize: Math.round(Style.font.heading * 0.9)
        font.weight: Font.Medium
        font.letterSpacing: 0.8
        opacity: 0.78
        horizontalAlignment: Text.AlignHCenter
      }
    }

    BorderSurface {
      id: inputField
      width: root.fieldWidth
      height: root.fieldHeight
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: parent.height * 0.09
      color: Color.lock.background
      borderSpec: root.inputBorderSpec
      radius: Style.cornerRadius
      clip: true

      TextInput {
        id: passwordInput
        anchors.fill: parent
        anchors.topMargin: inputField.borderTop
        anchors.rightMargin: inputField.borderRight + 18 + root.fingerprintReserve
        anchors.bottomMargin: inputField.borderBottom
        anchors.leftMargin: inputField.borderLeft + 18 + root.fingerprintReserve
        verticalAlignment: TextInput.AlignVCenter
        horizontalAlignment: TextInput.AlignHCenter
        activeFocusOnPress: true
        clip: true
        enabled: root.inputEnabled && !root.authenticatingPassword
        readOnly: root.authenticatingPassword
        echoMode: TextInput.Password
        passwordCharacter: "\u25CF"
        passwordMaskDelay: 0
        color: Color.lock.text
        selectionColor: Color.lock.selection
        selectedTextColor: Color.lock.text
        font.family: "Inter"
        font.pixelSize: text.length > 0 ? Math.max(1, Math.floor(root.passwordDotFontSize * root.passwordDotScale)) : root.fieldFontSize
        font.letterSpacing: text.length > 0 ? root.passwordDotLetterSpacing * root.passwordDotScale : 0
        cursorVisible: activeFocus && root.showPasswordCursor && text.length > 0
        cursorDelegate: Rectangle {
          width: 2
          color: Color.lock.text
          visible: passwordInput.cursorVisible
        }

        onTextChanged: {
          if (!root.syncingPasswordText) root.passwordTextEdited(text)
          if (text.length > 0) {
            root.wakeRequested()
          }
          if (text.length > 0 && root.failureMessage.length > 0) root.clearFailureRequested()
        }

        onAccepted: {
          var submitted = root.passwordText
          root.passwordTextEdited("")
          if (submitted.length > 0) root.submitPassword(submitted)
        }

        Keys.onPressed: function(event) {
          root.wakeRequested()
          if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
            root.passwordTextEdited("")
            event.accepted = true
          }
        }
      }

      Text {
        textFormat: Text.PlainText
        anchors.fill: passwordInput
        text: root.authenticatingPassword ? "Checking…" : (root.failureMessage.length > 0 ? root.failureMessage : root.placeholderText)
        visible: passwordInput.text.length === 0
        color: root.authenticatingPassword ? Color.lock.text : (root.failureMessage.length > 0 ? Color.lock.textError : Color.lock.placeholder)
        font.family: "Inter"
        font.pixelSize: root.fieldFontSize
        font.italic: !root.authenticatingPassword && root.failureMessage.length > 0
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
      }

      Text {
        id: fingerprintIcon
        objectName: "fingerprintIndicator"
        anchors.right: parent.right
        anchors.rightMargin: inputField.borderRight + 18
        anchors.verticalCenter: parent.verticalCenter
        visible: root.fingerprintConfigured
        text: "󰈷"
        color: Color.lock.placeholder
        font.family: "Inter"
        font.pixelSize: Math.round(root.fieldFontSize * 1.1)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }
    }
  }
}
