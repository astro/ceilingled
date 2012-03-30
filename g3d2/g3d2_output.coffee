net = require 'net'
{ getNow } = require './util'
BufferStream = require('bufferstream')

class exports.Output extends process.EventEmitter
    constructor: (host="bender.hq.c3d2.de", port=1340) ->
        @frame = []
        @old_frame = []
        for y in [0..(@height - 1)]
            @frame[y] = []
            @old_frame[y] = []
            for x in [0..(@width - 1)]
                @frame[y][x] = "0"
                @old_frame[y][x] = "0"
        @ceiling = []

        @ack_queue = []

        sock = net.connect port, host, =>
            @sock = sock
            # Priority
            @send_cmd "0401"
            # Activate input
            @send_cmd "0901"
            process.nextTick @loop
        sock.setEncoding 'utf8'
        #sock.on 'data', (data) ->
        #    console.log "<<", data
        sock.on 'close', =>
            delete @sock
            console.error "G3D2 connection closed"
            process.exit 1


        stream = new BufferStream size:'flexible', encoding: 'utf8'
        stream.split "\n", (line) =>
            # FIXME: y is line a Buffer?
            line = line.toString().replace("\r", "")
            if /^ok/.test line
                if (cb = @ack_queue.shift())
                    cb()
                else
                    console.warn "Received spurious 'ok'"
            else if /^bad/.test line
                if (cb = @ack_queue.shift())
                    cb new Error("Bad")
                else
                    console.warn "Received spurious 'bad'"
            else if (m = line.match(/^09/))
            else
                console.warn "Unknown message received:", line
        sock.pipe(stream)

    send_cmd: (line, cb) ->
        @sock.write "#{line}\r\n"
        @ack_queue.push (error) ->
            if error
                console.error "Error for #{line}\n#{error.stack or error.message or error}"
            cb? error

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

    putCeiling: (n, r, g, b) =>
        fmt = (c) ->
            s = Math.max(0, Math.min(255, Math.floor(c))).toString 16
            while s.length < 2
                s = "0#{s}"
            s
        @ceiling[n] = "#{fmt r}#{fmt g}#{fmt b}00"

    flush: =>
        if @sock
            #console.log @frame.map((line) -> line.join("")).join("\n")
            frame = @frame.map((line) -> line.join("")).join("")
            if frame isnt @old_frame
                @old_frame = frame
                @send_cmd "03#{frame}"
            else
                null

            for i in [0..Math.min(@ceiling.length-1, 3)]
                @send_cmd "02F#{i+1}#{@ceiling[i]}"

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
