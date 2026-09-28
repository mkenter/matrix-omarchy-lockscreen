import QtQuick

Canvas {
  id: root
  anchors.fill: parent

  property int minSize: 12
  property int maxSize: 48

  property int minLength: 18
  property int maxLength: 48

  // Roughly half of ordinary glyphs mutate.
  property real mutableChance: 0.50

  property string glyphs:
    "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ" +
    "ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉ" +
    "ﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ" +
    "+-=<>:*"

  property var streams: []

  function randomGlyph() {
    return glyphs.charAt(Math.floor(Math.random() * glyphs.length))
  }

  function randomInt(minimum, maximum) {
    return minimum + Math.floor(Math.random() * (maximum - minimum + 1))
  }

  function makeCell(y, isHead) {
    return {
      y: y,
      char: randomGlyph(),

      // About half the body stays fixed for its whole lifetime.
      // The leading glyph is always alive/changing.
      mutates: isHead || Math.random() < mutableChance,

      // Different glyphs mutate at unrelated random rates.
      mutateEvery: isHead
        ? randomInt(1, 4)
        : randomInt(2, 18),

      mutateCounter: 0
    }
  }

  function makeStream(seedVisible) {
    // Bias toward distant/smaller streams, with occasional foreground ones.
    var depth = Math.pow(Math.random(), 1.65)

    var size =
      minSize + depth * (maxSize - minSize)

    var length =
      randomInt(minLength, maxLength)

    // Far = dimmer.
    // Close = brighter.
    var opacity =
      0.22 + depth * 0.78

    // Advance in discrete character rows.
    //
    // Far streams tend to advance slowly.
    // Near streams tend to advance faster.
    // Randomness keeps streams at similar depth from synchronising.
    var stepEvery =
      Math.round(14 - depth * 9 + Math.random() * 5)

    stepEvery = Math.max(2, stepEvery)

    var stream = {
      x: Math.random() * Math.max(1, width - size),

      size: size,
      length: length,
      opacity: opacity,

      stepEvery: stepEvery,
      stepCounter: randomInt(0, stepEvery),

      cells: [],
      nextY: -size,

      // Makes recycled streams enter at different times.
      delay: randomInt(0, 90)
    }

    if (seedVisible) {
      // Initial startup looks like rain already in progress rather than
      // hundreds of streams entering from the top simultaneously.
      var headY = Math.random() * height

      var visibleCells =
        Math.min(
          length,
          Math.max(1, Math.floor(headY / size) + 1)
        )

      var firstY =
        headY - (visibleCells - 1) * size

      for (var i = 0; i < visibleCells; ++i) {
        var y = firstY + i * size
        stream.cells.push(makeCell(y, i === visibleCells - 1))
      }

      stream.nextY = headY + size
      stream.delay = randomInt(0, 25)
    }

    return stream
  }

  function initialise() {
    var next = []

    // Deliberately dense.
    // 1920px -> ~240 streams
    // 2560px -> ~320 streams
    // 3440px -> ~430 streams
    var count = Math.round(width / 8)
    count = Math.max(220, Math.min(520, count))

    for (var i = 0; i < count; ++i)
      next.push(makeStream(true))

    streams = next
    requestPaint()
  }

  function recycle(index) {
    streams[index] = makeStream(false)
  }

  function advanceStream(stream) {
    // The old glyphs DO NOT MOVE.
    //
    // We merely create a new cell one row below the previous head.
    var cell = makeCell(stream.nextY, true)

    // The previous head stops receiving special head mutation behaviour.
    if (stream.cells.length > 0) {
      var oldHead = stream.cells[stream.cells.length - 1]

      oldHead.mutates =
        Math.random() < mutableChance

      oldHead.mutateEvery =
        randomInt(2, 18)

      oldHead.mutateCounter = 0
    }

    stream.cells.push(cell)
    stream.nextY += stream.size

    // Oldest glyph disappears from the tail.
    while (stream.cells.length > stream.length)
      stream.cells.shift()
  }

  Component.onCompleted: initialise()

  onWidthChanged: {
    if (width > 0 && height > 0)
      initialise()
  }

  onHeightChanged: {
    if (width > 0 && height > 0)
      initialise()
  }

  onPaint: {
    var ctx = getContext("2d")

    ctx.fillStyle = "#000000"
    ctx.fillRect(0, 0, width, height)

    ctx.textAlign = "left"
    ctx.textBaseline = "top"

    for (var s = 0; s < streams.length; ++s) {
      var stream = streams[s]

      if (!stream)
        continue

      if (stream.delay > 0) {
        stream.delay--
      } else {
        stream.stepCounter++

        if (stream.stepCounter >= stream.stepEvery) {
          stream.stepCounter = 0
          advanceStream(stream)
        }
      }

      ctx.font =
        Math.round(stream.size) + "px monospace"

      var cellCount = stream.cells.length

      for (var i = 0; i < cellCount; ++i) {
        var cell = stream.cells[i]

        // Every glyph owns its own mutation timer.
        if (cell.mutates) {
          cell.mutateCounter++

          if (cell.mutateCounter >= cell.mutateEvery) {
            cell.char = randomGlyph()
            cell.mutateCounter = 0

            // Randomise its cadence again every time it changes.
            cell.mutateEvery =
              i === cellCount - 1
                ? randomInt(1, 4)
                : randomInt(2, 18)
          }
        }

        if (
          cell.y < -stream.size ||
          cell.y > height + stream.size
        )
          continue

        // 0 = oldest/tail
        // 1 = newest/head
        var position =
          cellCount <= 1
            ? 1
            : i / (cellCount - 1)

        if (i === cellCount - 1) {
          // Bright white-green leading character.
          ctx.fillStyle =
            "rgba(225,255,230," +
            stream.opacity +
            ")"
        } else if (i >= cellCount - 3) {
          // Bright green immediately behind the head.
          var nearHeadAlpha =
            Math.min(
              1.0,
              stream.opacity * 0.92
            )

          ctx.fillStyle =
            "rgba(90,255,120," +
            nearHeadAlpha +
            ")"
        } else {
          // Nonlinear fade toward the old end of the stream.
          //
          // Keeping the middle fairly visible and killing the very old
          // glyphs quickly resembles the movie more than a linear gradient.
          var fade =
            Math.pow(position, 1.45)

          var alpha =
            Math.max(
              0.015,
              fade * stream.opacity
            )

          ctx.fillStyle =
            "rgba(0,255,65," +
            alpha +
            ")"
        }

        ctx.fillText(
          cell.char,
          stream.x,
          cell.y
        )
      }

      // Recycle only after the tail has completely left the display.
      if (
        stream.cells.length > 0 &&
        stream.cells[0].y > height
      ) {
        recycle(s)
      }
    }
  }

  Timer {
    interval: 33
    running: true
    repeat: true
    onTriggered: root.requestPaint()
  }
}
