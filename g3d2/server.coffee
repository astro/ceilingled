{ Renderer, Compositor, DrawText } = require './render'
{ getNow, pick_randomly } = require './util'

renderer = new Renderer
compositor = new Compositor renderer.width, renderer.height
setInterval ->
    compositor.add new DrawText(pick_randomly "Hello", "World!")
, 500

renderer.on_drain = ->
    console.log "on_drain"
    ctx = renderer.ctx

    ctx.fillStyle = '#000'
    ctx.fillRect 0, 0, renderer.width, renderer.height
    ctx.antialias = 'grey'

    compositor.tick()
    compositor.draw renderer.ctx
