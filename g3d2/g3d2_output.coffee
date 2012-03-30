net = require 'net'
{ getNow } = require './util'
BufferStream = require('bufferstream')

INPUT_MAP =
    176:
        2:
            type: 'slider'
            id: 1
            norm: (v) -> v / 127
        3:
            type: 'slider'
            id: 2
            norm: (v) -> v / 127
        4:
            type: 'slider'
            id: 3
            norm: (v) -> v / 127
        5:
            type: 'slider'
            id: 4
            norm: (v) -> v / 127
        6:
            type: 'slider'
            id: 5
            norm: (v) -> v / 127
        8:
            type: 'slider'
            id: 6
            norm: (v) -> v / 127
        9:
            type: 'slider'
            id: 7
            norm: (v) -> v / 127
        12:
            type: 'slider'
            id: 8
            norm: (v) -> v / 127
        13:
            type: 'slider'
            id: 9
            norm: (v) -> v / 127
        14:
            type: 'knob'
            id: 1
            norm: (v) -> v / 127
        15:
            type: 'knob'
            id: 2
            norm: (v) -> v / 127
        16:
            type: 'knob'
            id: 3
            norm: (v) -> v / 127
        17:
            type: 'knob'
            id: 4
            norm: (v) -> v / 127
        18:
            type: 'knob'
            id: 5
            norm: (v) -> v / 127
        19:
            type: 'knob'
            id: 6
            norm: (v) -> v / 127
        20:
            type: 'knob'
            id: 7
            norm: (v) -> v / 127
        21:
            type: 'knob'
            id: 8
            norm: (v) -> v / 127
        22:
            type: 'knob'
            id: 9
            norm: (v) -> v / 127

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
            @send_cmd "00", (error, msg) =>
                console.log "00", error, msg
                if msg
                    @width = parseInt msg.width, 10
                    @height = parseInt msg.height, 10
                    @name = msg.name
                for y in [0..(@height - 1)]
                    @frame[y] = []
                    for x in [0..(@width - 1)]
                        @frame[y][x] = ""
                @emit 'init'
                process.nextTick @loop
        sock.setEncoding 'utf8'
        #sock.on 'data', (data) ->
        #    console.log "<<", data
        sock.on 'close', =>
            delete @sock
            console.error "G3D2 connection closed"
            process.exit 1


        stream = new BufferStream size:'flexible', encoding: 'utf8'
        current_msg = {}
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
            else if (m = line.match(/^09(..)(..)(..)/))
                id = parseInt m[1], 16
                value = parseInt m[2], 16
                event = parseInt m[3], 16
                if (input = INPUT_MAP[event]?[id])
                    value = input.norm value
                    @emit input.type, input.id, value
                else
                    console.log "Unknown input", event, id, value
            else if (m = line.match(/^([a-z].+?)=(.+)/))
                key = m[1]
                value = m[2]
                current_msg[key] = value
            else if line is ""
                if (cb = @ack_queue.shift())
                    cb(null, current_msg)
                else
                    console.warn "Received spurious message", current_msg
                current_msg = {}
            else
                console.warn "Unknown message received:", line
        sock.pipe(stream)

    send_cmd: (line, cb) ->
        @sock.write "#{line}\r\n"
        @ack_queue.push (error, result) =>
            @emit 'ack', error, result
            if error
                console.error "Error for #{line}\n#{error.stack or error.message or error}"
            cb? error, result

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

            if /^pentawallHD/.test(@name)
                for i in [0..Math.min(@ceiling.length-1, 3)]
                    if @ceiling[i]
                        @send_cmd "02F#{i+1}#{@ceiling[i]}"

    INTERVAL: 25

    loop: =>
        #console.log "queue", @ack_queue.length
        if @ack_queue.length >= 8
            return @once 'ack', @loop

        lastTick = getNow()
        @on_drain?()
        flushed = @flush()
        if flushed == true
            now = getNow()
            #console.log "frametime", now - lastTick, "ms"
            #process.nextTick @loop
            setTimeout @loop, Math.max(0, @INTERVAL - now + lastTick)
        else if flushed == null
            # Immediately check for frame modification
            #console.log "no difference"
            now = getNow()
            setTimeout @loop, Math.max(0, @INTERVAL / 2 - now + lastTick)
        else
            @sock.once 'drain', =>
                now = getNow()
                #console.log "draintime", now - lastTick, "ms"
                setTimeout @loop, Math.max(0, @INTERVAL - now + lastTick)
