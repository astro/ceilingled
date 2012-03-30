net = require 'net'
{ getNow } = require './util'

class exports.Output
    constructor: (host="bender.hq.c3d2.de", port=1340) ->
        @frame = []
        @old_frame = []
        for y in [0..(@height - 1)]
            @frame[y] = []
            @old_frame[y] = []
            for x in [0..(@width - 1)]
                @frame[y][x] = "0"
                @old_frame[y][x] = "0"

        sock = net.connect port, host, =>
            @sock = sock
            @sock.write "0401\r\n"
            process.nextTick @loop
        #sock.on 'data', (data) ->
        #    console.log "<< #{data}"
        sock.on 'close', =>
            delete @sock
            console.error "G3D2 connection closed"
            process.exit 1

    width: 24

    height: 24

    putPixel: (y, x, r, g, b) ->
        #console.log "putPixel", x, y, r, g, b
        #g = Math.ceil(Math.log(g / 255 + 1) * 255)
        fmt = (c) ->
            s = Math.max(0, Math.min(255, c)).toString 16
            while s.length < 2
                s = "0#{s}"
            s
        @frame[y][x] = "#{fmt r}#{fmt g}#{fmt b}"

    flush: =>
        if @sock
            #console.log @frame.map((line) -> line.join("")).join("\n")
            frame = @frame.map((line) -> line.join("")).join("")
            if frame isnt @old_frame
                @old_frame = frame
                @sock.write "03#{frame}\r\n"
            else
                null

    INTERVAL: 25

    loop: =>
        lastTick = getNow()
        @on_drain?()
        flushed = @flush()
        if flushed == true
            now = getNow()
            console.log "frametime", now - lastTick, "ms"
            #process.nextTick @loop
            setTimeout @loop, Math.max(0, @INTERVAL - now + lastTick)
        else if flushed == null
            # Immediately check for frame modification
            console.log "no difference"
            now = getNow()
            setTimeout @loop, Math.max(0, @INTERVAL / 2 - now + lastTick)
        else
            @sock.once 'drain', =>
                now = getNow()
                console.log "draintime", now - lastTick, "ms"
                setTimeout @loop, Math.max(0, @INTERVAL - now + lastTick)
