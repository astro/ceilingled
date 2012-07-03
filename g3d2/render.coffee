Canvas = require('canvas')

SDL = require './sdl_output'
G3D2 = require './g3d2_output'
Tee = require './tee_output'
{ getNow, pick_randomly } = require './util'

class exports.Renderer
    constructor: (host="bender", port=1339) ->
        @output = new Tee.Output([new G3D2.Output(host, port), new SDL.Output()])
        @output.on 'init', =>
            { width, height } = @output
            canvas = new Canvas width, height
            @ctx = canvas.getContext('2d');

            @output.on 'drain', =>
                @on_drain?()
                @render()

    render: ->
        data = @ctx.getImageData(0, 0, @output.width, @output.height)?.data
        #console.log "data", data
        offset = 0
        for y in [0..@output.height-1]
            for x in [0..@output.width-1]
                [r, g, b] = [data[offset++], data[offset++], data[offset++]]
                offset++
                @output.putPixel x, y, r, g, b

class DrawNop
    duration: 1

    draw: (ctx, t) ->


class DrawRoad
    duration: 10

    constructor: ->
        @track = []

    draw: (ctx, t) ->
        hw = Math.floor(@width / 2)
        hh = Math.floor(@height / 2)
        ctx.translate hw, hh

        x = 0
        y = 0
        z = t * 10
        for i_ in [10..1]
            z1 = z + i_
            track = @get_track(Math.floor(i))
            x += track.x
            y += track.y
            #if i - z - i < 1
            #track.x

            d = []
            for mz in [z1, z1 + 1]
                for mx in [-hw / 2, hw / 2]
                    sx = mx + x
                    sy = y
                    d.push
                        x: sx / z1

            ctx.moveTo d[0].x, d[0].y
            for j in [1..3]
                ctx.lineTo d[j].x, d[j].y

            ctx.fillStyle = '#333'
            ctx.fill()


    get_track: (i) ->
        i = Math.floor(i)
        while @track.length <= i
            @track.push { x: Math.random() * 2, y: Math.random() * 2 }


class exports.DrawText
    constructor: (@text) ->
        # Average; will be recalculated
        @set_duration Math.ceil(@text.length / 8)

    set_duration: (linecount) ->
        @duration = Math.ceil(Math.max(0, linecount - 2) * 800)

    draw: (ctx, t) ->
        th = 8
        padding = 6
        ctx.font = "#{th + 1}px TratexSvart";
        unless @font_lines?
            @font_lines = []
            for line in @text.split(/\n/)
                while line.length > 0
                    i = line.length
                    while i > 1 && ctx.measureText(line.slice(0, i)).width > @width
                        i--
                    @font_lines.push(line.slice(0, i))
                    line = line.slice(i)
            @set_duration @font_lines.length

        height = padding * 2 + @font_lines.length * th
        ctx.translate(0, Math.ceil(-t * Math.max(0, height - @height) + padding))
        ctx.textBaseline = 'top'
        ctx.fillStyle = '#fff'
        for line in @font_lines
            ctx.fillText(line, 0, 0)
            ctx.translate(0, th)


class exports.Transition
    duration: 1000

    constructor: (@a, @b) ->

    draw: (ctx, t) ->
        if @a?
            ctx.save()
            @prepareA ctx, t
            @a.draw(ctx, 1)
            ctx.restore()

        if @b?
            ctx.save()
            @prepareB ctx, t
            @b.draw(ctx, 0)
            ctx.restore()

    prepareA: (ctx, t) ->

    prepareB: (ctx, t) ->

class exports.BlendTransition extends exports.Transition
    duration: 900

    prepareA: (ctx, t) ->
        ctx.globalAlpha = 1 - t

    prepareB: (ctx, t) ->
        ctx.globalAlpha = t

class exports.HorizontalSlideTransition extends exports.Transition
    duration: 500

    constructor: ->
        super

        @direction = pick_randomly('left', 'right')

    prepareA: (ctx, t) ->
        if @direction is 'left'
            ctx.translate Math.floor(t * @width), 0
        else
            ctx.translate Math.floor(t * -@width), 0

    prepareB: (ctx, t) ->
        if @direction is 'left'
            ctx.translate Math.floor((1 - t) * -@width), 0
        else
            ctx.translate Math.floor((1 - t) * @width), 0

class exports.VerticalSlideTransition extends exports.Transition
    duration: 500

    prepareA: (ctx, t) ->
        ctx.translate 0, Math.floor(t * -@height)

    prepareB: (ctx, t) ->
        ctx.translate 0, Math.floor((1 - t) * @height)

class exports.RotateTransition extends exports.Transition
    duration: 2000

    pick_edge: ->
        if @edge?
            return
        @edge = pick_randomly [0, 0],
            [@width, 0], [@width, @height], [0, @height]
        #@edge = [0, 0]
        @anti_edge = [-@edge[0], -@edge[1]]
        @direction = pick_randomly 'up', 'down'
        #console.log "edge", @edge, "direction", @direction

    prepareA: (ctx, t) ->
        @pick_edge()

        ctx.translate @edge...
        if @direction is 'up'
            a = -t
        else
            a = t
        ctx.rotate(a * Math.PI / 2)
        ctx.translate @anti_edge...

        ctx.globalAlpha = 1 - t

    prepareB: (ctx, t) ->
        @pick_edge()

        if @direction is 'up'
            a = 1 - t
        else
            a = t - 1
        ctx.translate @edge...
        ctx.rotate(a * Math.PI / 2)
        ctx.translate @anti_edge...

        ctx.globalAlpha = t


class exports.Compositor
    constructor: (@width, @height) ->
        @current = null
        @queue = []
        @state = 'show'

    add: (drawable) ->
        drawable.width = @width
        drawable.height = @height

        @queue.push drawable

    make_transition: (a, b) ->
        klass = pick_randomly exports.BlendTransition, exports.HorizontalSlideTransition, exports.VerticalSlideTransition, exports.RotateTransition
        #klass = exports.RotateTransition
        transition = new klass(a, b)
        transition.width = @width
        transition.height = @height
        transition

    tick: ->
        if @get_t() >= 1
            if @state is 'show'
                @state = 'transition'
                @current = @make_transition(@current, @queue[0])
                @phase = @current.duration * (0.3 + 0.7 / Math.max(1, @queue.length / 3))
                @start = getNow()
            else if @state is 'transition'
                @state = 'show'
                delete @current

        unless @current
            console.log "queue length:", @queue.length
            @current = @queue.shift()
            unless @current
                @current = new DrawNop #DrawRoad()
            #console.log "new current", @current
            @start = getNow()
            @phase = @current.duration * (0.2 + 0.8 / Math.max(1, @queue.length / 3))

    get_t: ->
        if @start
            (getNow() - @start) / @phase
        else
            0

    draw: (ctx) ->
        ctx.save()
        @current?.draw(ctx, @get_t())
        ctx.restore()

        # Display queue length
        for i in [0..@queue.length]
            ctx.fillStyle = '#aaa'
            ctx.fillRect @width - i, @height - 1, 1, 1
