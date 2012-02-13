net = require 'net'

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
        @frame[@height - y - 1][x] = ((g >> 4) & 0xF).toString(16)

    flush: =>
        if no and @sock
            frame = ""
            for x in [0..@width-1]
                for y in [0..@height-1]
                    frame += @frame[y][x]
            console.log @frame.map((line) -> line.join("")).join("\n")
            #frame = @frame.map((line) -> line.join("")).join("")
            ###
                replace(/\x67/, "\x65\x1").
                replace(/\x68/, "\x65\x2").
                replace(/\x65/, "\x65\x3").
                replace(/\x66/, "\x65\x4")
            ###

            console.log "frame", frame.length, frame
            return @sock.write "03#{frame}\r\n"

        if @sock
            pad = (v) ->
                s = v.toString(16)
                while s.length < 2
                    s = "0#{s}"
                s.slice(s.length - 2)

            buffered = yes
            for x in [0..(@width - 1)]
                for y in [0..(@height - 1)]
                    if @frame[y][x] isnt @old_frame[y][x]
                        c = @old_frame[y][x] = @frame[y][x]
                        #console.log "02#{pad x}#{pad y}#{c}"
                        buffered = @sock.write "02#{pad x}#{pad y}#{c}\r\n", 'binary'
            buffered

    loop: =>
        lastTick = new Date().getTime()
        @on_drain?()
        if @flush()
            now = new Date().getTime()
            setTimeout @loop, Math.max(1, 50 - now + lastTick)
        else
            @sock.once 'drain', =>
                console.log "drain"
                @loop()