import QtQuick

Canvas {
  id: root
  anchors.fill: parent

  property int glyphSize: 28
  property int columnWidth: 28

  property int minLength: 12
  property int maxLength: 42

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

  function makeStream(column, seedVisible) {
    var length =
      randomInt(minLength, maxLength)

    // Streams occupy fixed character columns and advance at independent rates.
    var stepEvery = randomInt(1, 9)

    var stream = {
      column: column,
      x: column * columnWidth,

      size: glyphSize,
      length: length,

      stepEvery: stepEvery,
      stepCounter: randomInt(0, stepEvery),

      cells: [],
      nextY: -glyphSize,

      // Makes recycled streams enter at different times.
      delay: randomInt(0, 120)
    }

    if (seedVisible) {
      // Initial startup looks like rain already in progress rather than
      // hundreds of streams entering from the top simultaneously.
      var headY = Math.random() * height

      var visibleCells =
        Math.min(
          length,
          Math.max(1, Math.floor(headY / glyphSize) + 1)
        )

      var firstY =
        headY - (visibleCells - 1) * glyphSize

      for (var i = 0; i < visibleCells; ++i) {
        var y = firstY + i * glyphSize
        stream.cells.push(makeCell(y, i === visibleCells - 1))
      }

      stream.nextY = headY + glyphSize
      stream.delay = randomInt(0, 25)
    }

    return stream
  }

  function initialise() {
    var next = []

    var columnCount =
      Math.max(1, Math.floor(width / columnWidth))

    // Exactly one stream per column.
    for (var i = 0; i < columnCount; ++i)
      next.push(makeStream(i, true))

    streams = next
    requestPaint()
  }

  function recycle(index) {
    streams[index] = makeStream(streams[index].column, false)
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

        if (i === cellCount - 1) {
          // Newly-added leading glyph.
          ctx.fillStyle = "#e5ffe8"
        } else if (i >= cellCount - 3) {
          // A couple of fresh characters remain brighter.
          ctx.fillStyle = "#79ff94"
        } else if (i >= cellCount - 8) {
          // Recent body: still vivid, but clearly behind the head.
          ctx.fillStyle = "#18c94d"
        } else {
          // Older retained characters are darker.
          ctx.fillStyle = "#0b7a2b"
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
