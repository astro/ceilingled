SDL = require 'sdl'
SDL.init SDL.INIT.VIDEO
SDL.events.on 'QUIT', -> process.exit 0

W = 72
H = 32
ZOOM = 16
COLORS = 16

class exports.Output
    constructor: ->
        @screen = SDL.setVideoMode @width * ZOOM, @height * ZOOM, 24, SDL.SURFACE.SWSURFACE

    width:
        W

    height:
        H

    putPixel: (x, y, r, g, b) ->
        size = Math.max(ZOOM - 1, 1)
        color_step = 256 / COLORS
        green = Math.floor(g / color_step) * color_step
        #console.log "green", green
        SDL.fillRect @screen, [x * ZOOM, y * ZOOM, size, size], green << 8

    flush: ->
        SDL.flip @screen