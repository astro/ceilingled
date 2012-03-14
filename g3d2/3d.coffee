W = 24
H = 24
CAM_Y = 3
track = []
camZ = 0
phase = 0
phase_delta = 1
dx_amplitude = 0
dy_amplitude = 0

class Segment
    constructor: ->
        phase += phase_delta
        if phase >= Math.PI
            phase %= Math.PI
            dx_amplitude = Math.random() * 12 - 6
            console.log "dx_amplitude", dx_amplitude
            dy_amplitude = Math.random() * 12 - 4
            console.log "dy_amplitude", dy_amplitude
            phase_delta = Math.PI / (5 + 8 * Math.random())
            console.log "phase_delta", phase_delta

        @dx = Math.sin(phase) * dx_amplitude
        @dy = Math.sin(phase) * dy_amplitude
        @w = Math.sin(phase) * 2 + 10
        @h = Math.random() * 10 + 2

    depth: 10

tick = ->
    if track[0]
        velocity = 3
        if track[0].dy > 0
            velocity *= 1 + track[0].dy / 50
        else
            velocity /= 1 - track[0].dy / 10
        console.log "velocity", velocity
        camZ += velocity
    while track[0] and track[0].depth < camZ
        camZ -= track[0].depth
        console.log "camZ", camZ
        track.splice(0, 1)

    while track.length < 200
        track.push new Segment()

getTrackTranslation = (z) ->
    z -= camZ
    i = 0
    #while track[i] && z >= track[i].depth

drawTrack = (ctx) ->
    z1 = -camZ + track[0].depth + 0.1
    console.log "camZ", camZ, "dx", track[0].dx, "dy", track[0].dy
    x = track[0].dx * (1 - camZ / track[0].depth)
    y = track[0].dy * (1 - camZ / track[0].depth) + 5

    segs = []

    for i in [1..track.length-1]
        seg1 = track[i - 1]
        seg2 = track[i]
        x2 = x + seg2.dx
        y2 = y + seg2.dy
        z2 = z1 + seg2.depth
        yDisplace = 0 #-z / 1000

        ctx.beginPath()
        bottom = H * ((y + CAM_Y) / z1 + 0.5) + yDisplace
        if i is 1
            bottom = Math.max bottom, H
        segs.push
            front:
                x1: W * ((x - seg1.w) / z1 + 0.5)
                x2: W * ((x + seg1.w) / z1 + 0.5)
                y1: H * ((y + CAM_Y - seg1.h) / z1 + 0.5) + yDisplace
                y2: bottom
            back:
                x1: W * ((x2 - seg2.w) / z2 + 0.5)
                y1: H * ((y2 + CAM_Y - seg2.h) / z2 + 0.5) + yDisplace
                x2: W * ((x2 + seg2.w) / z2 + 0.5)
                y2: H * ((y2 + CAM_Y) / z2 + 0.5) + yDisplace
            z: z2

        x = x2
        y = y2
        z1 = z2

    for i in [segs.length-1..0]
        { front, back, z } = segs[i]

        # fog
        ctx.fillStyle = "rgba(0, 0, 0, #{Math.max(0, z / 2000)})"
        ctx.fillRect back.x1, back.y1, back.x2 - back.x1, back.y2 - back.y1

        # left landscape
        ctx.beginPath()
        ctx.moveTo front.x1, front.y2
        ctx.lineTo 0, front.y2
        ctx.lineTo 0, back.y2
        ctx.lineTo back.x1, back.y2
        ctx.fillStyle = '#070'
        ctx.fill()
        # right landscape
        ctx.beginPath()
        ctx.moveTo front.x2, front.y2
        ctx.lineTo W - 1, front.y2
        ctx.lineTo W - 1, back.y2
        ctx.lineTo back.x2, back.y2
        ctx.fillStyle = '#070'
        ctx.fill()
        # left wall
        ctx.beginPath()
        ctx.moveTo back.x1, back.y1
        ctx.lineTo back.x1, back.y2
        ctx.strokeStyle = '#ba0'
        ctx.stroke()
        ctx.beginPath()
        ctx.moveTo front.x1, front.y1
        ctx.lineTo front.x1, front.y2
        ctx.lineTo back.x1, back.y2
        ctx.lineTo back.x1, back.y1
        ctx.fillStyle = '#dc4'
        ctx.fill()
        # right wall
        ctx.beginPath()
        ctx.moveTo back.x2, back.y1
        ctx.lineTo back.x2, back.y2
        ctx.strokeStyle = '#ba0'
        ctx.stroke()
        ctx.beginPath()
        ctx.moveTo front.x2, front.y1
        ctx.lineTo front.x2, front.y2
        ctx.lineTo back.x2, back.y2
        ctx.lineTo back.x2, back.y1
        ctx.fillStyle = '#dc4'
        ctx.fill()
        # floor
        ctx.beginPath()
        ctx.moveTo front.x1, front.y2
        ctx.lineTo front.x2, front.y2
        ctx.strokeStyle = '#ef0'
        ctx.stroke()
        ctx.beginPath()
        ctx.moveTo front.x1, front.y2
        ctx.lineTo front.x2, front.y2
        ctx.lineTo back.x2, back.y2
        ctx.lineTo back.x1, back.y2
        ctx.fillStyle = '#cd0'
        ctx.fill()
        # ceiling
        ###
        ctx.beginPath()
        ctx.moveTo back.x1, back.y1
        ctx.lineTo back.x2, back.y1
        ctx.strokeStyle = '#111'
        ctx.stroke()
        ctx.beginPath()
        ctx.moveTo front.x1, front.y1
        ctx.lineTo front.x2, front.y1
        ctx.lineTo back.x2, back.y1
        ctx.lineTo back.x1, back.y1
        ctx.fillStyle = '#000'
        ctx.fill()
        ###

        ctx.beginPath()
        # ul
        ctx.moveTo front.x1, front.y1
        ctx.lineTo back.x1, back.y1
        # ur
        ctx.moveTo front.x2, front.y1
        ctx.lineTo back.x2, back.y1
        ctx.strokeStyle = '#fff'
        ctx.stroke()

        ctx.beginPath()
        # lr
        ctx.moveTo front.x2, front.y2
        ctx.lineTo back.x2, back.y2
        # ll
        ctx.moveTo front.x1, front.y2
        ctx.lineTo back.x1, back.y2
        ctx.strokeStyle = '#333'
        ctx.stroke()

{ Renderer } = require './render'

renderer = new Renderer
renderer.on_drain = ->
    ctx = renderer.ctx

    ctx.fillStyle = "#00c"
    ctx.fillRect 0, 0, W, H

    tick()
    drawTrack ctx
