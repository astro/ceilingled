SDL = require 'sdl'
SDL.init SDL.INIT.VIDEO
SDL.events.on 'QUIT', -> process.exit 0

W = 24
H = 24
ZOOM = 32
COLORS = 16

class exports.Output extends process.EventEmitter
    constructor: ->
        @screen = SDL.setVideoMode @width * ZOOM, @height * ZOOM, 24, SDL.SURFACE.SWSURFACE

        process.nextTick =>
            @emit 'init'
            @loop()

    width:
        W

    height:
        H

    putPixel: (x, y, r, g, b) ->
        size = Math.max(ZOOM - 1, 1)
        color_step = 255 / COLORS
        #green = Math.ceil(Math.floor(g / color_step) * color_step)
        SDL.fillRect @screen, [x * ZOOM, y * ZOOM, size, size], (r << 16) | (g << 8) | b

    flush: ->
        SDL.flip @screen

    loop: =>
        console.log "sdl drain"
        @emit 'drain'
        @flush()
        process.nextTick @loop
