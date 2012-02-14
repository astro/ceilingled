#{ Output } = require './sdl_output'
{ Output } = require './g3d2_output'

Canvas = require('canvas')

getNow = ->
    new Date().getTime()

pick_randomly = (a...) ->
    a[Math.floor(Math.random() * a.length)]

class Renderer
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


class DrawText
    constructor: (@text) ->

    draw: (ctx, t) ->
        th = 18
        padding = 1
        ctx.font = "#{th}px Tahoma";
        unless @font_lines?
            @font_lines = []
            for line in @text.split(/\n/)
                while line.length > 0
                    i = line.length
                    while i > 1 && ctx.measureText(line.slice(0, i)).width > @width
                        i--
                    @font_lines.push(line.slice(0, i))
                    line = line.slice(i)

        height = padding * 2 + @font_lines.length * th
        ctx.translate(0, -t * Math.max(0, height - @height) + padding)
        ctx.textBaseline = 'top'
        ctx.fillStyle = '#fff'
        for line in @font_lines
            ctx.fillText(line, 0, 0)
            ctx.translate(0, th)


class Transition
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

class BlendTransition extends Transition
    prepareA: (ctx, t) ->
        ctx.globalAlpha = 1 - t

    prepareB: (ctx, t) ->
        ctx.globalAlpha = t

class HorizontalSlideTransition extends Transition
    constructor: ->
        super

        @direction = pick_randomly('left', 'right')

    prepareA: (ctx, t) ->
        if @direction is 'left'
            ctx.translate t * @width, 0
        else
            ctx.translate t * -@width, 0

    prepareB: (ctx, t) ->
        if @direction is 'left'
            ctx.translate (1 - t) * -@width, 0
        else
            ctx.translate (1 - t) * @width, 0

class VerticalSlideTransition extends Transition
    prepareA: (ctx, t) ->
        ctx.translate 0, t * -@height

    prepareB: (ctx, t) ->
        ctx.translate 0, (1 - t) * @height

class RotateTransition extends Transition
    pick_edge: ->
        if @edge?
            return
        @edge = pick_randomly [0, 0],
            [@width, 0], [@width, @height], [0, @height]
        #@edge = [0, 0]
        @anti_edge = [-@edge[0], -@edge[1]]
        @direction = pick_randomly 'up', 'down'
        console.log "edge", @edge, "direction", @direction

    prepareA: (ctx, t) ->
        @pick_edge()

        ctx.translate @edge...
        if @direction is 'up'
            a = -t
        else
            a = t
        ctx.rotate(a * Math.PI / 2)
        ctx.translate @anti_edge...

    prepareB: (ctx, t) ->
        @pick_edge()

        if @direction is 'up'
            a = 1 - t
        else
            a = t - 1
        ctx.translate @edge...
        ctx.rotate(a * Math.PI / 2)
        ctx.translate @anti_edge...


class Compositor
    PHASE: 3000
    TRANSITION_PHASE: 5000

    constructor: (@width, @height) ->
        @current = null
        @queue = []
        @state = 'show'

    add: (drawable) ->
        drawable.width = @width
        drawable.height = @height

        @queue.push drawable

    make_transition: (a, b) ->
        klass = pick_randomly BlendTransition, HorizontalSlideTransition, VerticalSlideTransition, RotateTransition
        transition = new klass(a, b)
        transition.width = @width
        transition.height = @height
        transition

    tick: ->
        if @get_t() >= 1
            if @state is 'show'
                @state = 'transition'
                @current = @make_transition(@current, @queue[0])
                @start = getNow()
            else if @state is 'transition'
                @state = 'show'
                delete @current

        unless @current
            @current = @queue.shift()
            console.log "new current", @current
            @start = getNow()

    get_t: ->
        if @state is 'show'
            phase = @PHASE
        else if @state is 'transition'
            phase = @TRANSITION_PHASE
        if @start
            (getNow() - @start) / phase
        else
            0

    draw: (ctx) ->
        ctx.save()
        @current?.draw(ctx, @get_t())
        ctx.restore()


renderer = new Renderer
compositor = new Compositor renderer.width, renderer.height
setInterval ->
    compositor.add new DrawText(pick_randomly "Hello World\nfrobfrobfrobfrobfrobfrobfrobfrobfrobfrobfrobfrobfrobfrob\n", "\nWe ♥ GNU/Linux", "Umlaute könnten funktionieren", "Foo bar\nprint \"Hello\"\nGOTO 23\n<<</>>")
, 500

renderer.on_drain = ->
    console.log "on_drain"
    ctx = renderer.ctx

    ctx.fillStyle = '#000'
    ctx.fillRect 0, 0, renderer.width, renderer.height
    ctx.antialias = 'grey'

    compositor.tick()
    compositor.draw renderer.ctx
