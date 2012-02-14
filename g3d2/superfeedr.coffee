{ Renderer, Compositor, DrawText } = require './render'
{ getNow, pick_randomly } = require './util'

renderer = new Renderer
compositor = new Compositor renderer.width, renderer.height

renderer.on_drain = ->
    ctx = renderer.ctx

    ctx.fillStyle = '#000'
    ctx.fillRect 0, 0, renderer.width, renderer.height
    ctx.antialias = 'grey'

    compositor.tick()
    compositor.draw renderer.ctx

{ Superfeedr } = require('superfeedr')

client = new Superfeedr("user", "***");
client.on 'connected', ->
    client.subscribe "http://en.wikipedia.org/w/index.php?title=Special:RecentChanges&feed=atom", (err, feed) ->
        console.log "subscribe", err, feed
    client.on 'notification', (notification) ->
        console.log "notification", notification
        notification.entries.forEach (notification) ->
            compositor.add new DrawText(notification.title)
