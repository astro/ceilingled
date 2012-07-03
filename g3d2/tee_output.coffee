class exports.Output extends process.EventEmitter
    constructor: (@outputs) ->
        inited = 0
        @output_ids = []
        @drained = {}
        @outputs.forEach (output) =>
            unless output.on
                return console.log "weird output", output
            output.on 'init', (args...) =>
                console.log 'init', args...
                console.log "output wh", output.width, "x", output.height
                @width = Math.max (@outputs.map (output1) -> output1.width || 0)...
                @height = Math.max (@outputs.map (output1) -> output1.height || 0)...
                console.log "wh", @width, "x", @height

                inited++
                console.log "inited", inited, "/", @outputs.length
                if inited >= @outputs.length
                    console.log "Tee init"
                    @emit 'init', args...

            id = Math.random()
            @output_ids.push id
            output.on 'drain', =>
                @drained[id] = true
                @may_drain()

    may_drain: ->
        if @output_ids.every((id) =>
            @drained[id]
        )
            console.log "Tee drain"
            @emit 'drain'
            @drained = {}

    width: 24
    height: 24

    putPixel: (args...) ->
        @outputs.forEach (output) ->
            output.putPixel(args...)

    putCeiling: (args...) ->
        @outputs.forEach (output) ->
            output.putPixel?(args...)
