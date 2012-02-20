net = require 'net'
{ getNow } = require './util'

class exports.Output
    constructor: (host="g3d2.hq.c3d2.de", port=1339) ->
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
            @sock.write "0403\r\n"
            process.nextTick @loop
        #sock.on 'data', (data) ->
        #    console.log "<< #{data}"
        sock.on 'close', =>
            delete @sock
            console.error "G3D2 connection closed"
            process.exit 1

    width: 72

    height: 32

    putPixel: (x, y, r, g, b) ->
        #console.log "putPixel", x, y, r, g, b
        g = Math.ceil(Math.log(g / 255 + 1) * 255)
        @frame[y][x] = ((g >> 4) & 0xF).toString(16)

    flush: =>
        if @sock
            console.log @frame.map((line) -> line.join("")).join("\n")
            frame = @frame.map((line) -> line.join("")).join("")
            @sock.write "03#{frame}\r\n"

    loop: =>
        lastTick = getNow()
        @on_drain?()
        if @flush()
            now = getNow()
            console.log "frametime", now - lastTick, "ms"
            #process.nextTick @loop
            setTimeout @loop, Math.max(0, 40 - now + lastTick)
        else
            @sock.once 'drain', =>
                now = getNow()
                console.log "draintime", now - lastTick, "ms"
                setTimeout @loop, Math.max(0, 40 - now + lastTick)
