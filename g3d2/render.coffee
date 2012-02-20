Canvas = require('canvas')

#{ Output } = require './sdl_output'
{ Output } = require './g3d2_output'
{ getNow, pick_randomly } = require './util'

class exports.Renderer
    constructor: ->
        @output = new Output()
        { @width, @height } = @output
        canvas = new Canvas @width, @height
        @ctx = canvas.getContext('2d');

        @output.on_drain = =>
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
                #console.log "x", x, "y", y, [r, g, b]
                @output.putPixel x, y, r, g, b

class DrawNop
    duration: 1

    draw: (ctx, t) ->


class exports.DrawText
    constructor: (@text) ->
        # Average; will be recalculated
        @set_duration Math.ceil(@text.length / 8)

    set_duration: (linecount) ->
        @duration = Math.ceil(Math.max(0, linecount - 2) * 800)

    draw: (ctx, t) ->
        th = 8
        padding = 6
        ctx.font = "#{th + 1}px Terminal";
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
        transition = new klass(a, b)
        transition.width = @width
        transition.height = @height
        transition

    tick: ->
        if @get_t() >= 1
            if @state is 'show'
                @state = 'transition'
                @current = @make_transition(@current, @queue[0])
                @phase = @current.duration * (0.2 + 0.8 / Math.max(1, @queue.length / 3))
                @start = getNow()
            else if @state is 'transition'
                @state = 'show'
                delete @current

        unless @current
            @current = @queue.shift()
            unless @current
                @current = new DrawNop()
            #console.log "new current", @current
            @start = getNow()
            @phase = @current.duration * (0.5 + 0.7 / Math.max(1, @queue.length / 3))

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
