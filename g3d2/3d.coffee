W = 72
H = 32
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
            dx_amplitude = Math.random() * 20 - 10
            console.log "dx_amplitude", dx_amplitude
            dy_amplitude = Math.random() * 16 - 8
            console.log "dy_amplitude", dy_amplitude
            phase_delta = Math.PI / (3 + 7 * Math.random())
            console.log "phase_delta", phase_delta

        @dx = Math.sin(phase) * dx_amplitude
        @dy = Math.sin(phase) * dy_amplitude

    depth: 15

tick = ->
    camZ += 2
    while track[0] and track[0].depth < camZ
        camZ -= track[0].depth
        console.log "camZ", camZ
        track.splice(0, 1)

    while track.length < 30
        track.push new Segment()

drawTrack = (ctx) ->
    z1 = -camZ + track[0].depth + 0.1
    console.log "camZ", camZ, "dx", track[0].dx, "dy", track[0].dy
    x = track[0].dx * (1 - camZ / track[0].depth)
    w = 16
    y = track[0].dy * (1 - camZ / track[0].depth)
    h = 20

    segs = []

    for i in [1..track.length-1]
        seg1 = track[i - 1]
        seg2 = track[i]
        x2 = x + seg2.dx
        y2 = y + seg2.dy
        z2 = z1 + seg2.depth

        ctx.beginPath()

        segs.push
            front:
                x1: W * ((x - w) / z1 + 0.5)
                x2: W * ((x + w) / z1 + 0.5)
                y1: H * ((y - h) / z1 + 0.5)
                y2: H * ((y + h) / z1 + 0.5)
            back:
                x1: W * ((x2 - w) / z2 + 0.5)
                y1: H * ((y2 - h) / z2 + 0.5)
                x2: W * ((x2 + w) / z2 + 0.5)
                y2: H * ((y2 + h) / z2 + 0.5)
            z: z2

        x = x2
        y = y2
        z1 = z2

    for i in [segs.length-1..0]
        { front, back, z } = segs[i]

        # fog
        ctx.fillStyle = "rgba(0, 0, 0, #{Math.max(0, z / 5000)})"
        ctx.fillRect back.x1, back.y1, back.x2 - back.x1, back.y2 - back.y1

        # left wall
        ctx.beginPath()
        ctx.moveTo back.x1, back.y1
        ctx.lineTo back.x1, back.y2
        ctx.strokeStyle = '#222'
        ctx.stroke()
        ctx.beginPath()
        ctx.moveTo front.x1, front.y1
        ctx.lineTo front.x1, front.y2
        ctx.lineTo back.x1, back.y2
        ctx.lineTo back.x1, back.y1
        ctx.fillStyle = '#222'
        ctx.fill()
        # right wall
        ctx.beginPath()
        ctx.moveTo back.x2, back.y1
        ctx.lineTo back.x2, back.y2
        ctx.strokeStyle = '#222'
        ctx.stroke()
        ctx.beginPath()
        ctx.moveTo front.x2, front.y1
        ctx.lineTo front.x2, front.y2
        ctx.lineTo back.x2, back.y2
        ctx.lineTo back.x2, back.y1
        ctx.fillStyle = '#222'
        ctx.fill()
        # floor
        ctx.beginPath()
        ctx.moveTo front.x1, front.y2
        ctx.lineTo front.x2, front.y2
        ctx.strokeStyle = '#fff'
        ctx.stroke()
        ctx.beginPath()
        ctx.moveTo front.x1, front.y2
        ctx.lineTo front.x2, front.y2
        ctx.lineTo back.x2, back.y2
        ctx.lineTo back.x1, back.y2
        ctx.fillStyle = '#333'
        ctx.fill()
        # ceiling
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

        ctx.beginPath()
        # ul
        ctx.moveTo front.x1, front.y1
        ctx.lineTo back.x1, back.y1
        # ur
        ctx.moveTo front.x2, front.y1
        ctx.lineTo back.x2, back.y1
        # lr
        ctx.moveTo front.x2, front.y2
        ctx.lineTo back.x2, back.y2
        # ll
        ctx.moveTo front.x1, front.y2
        ctx.lineTo back.x1, back.y2
        ctx.strokeStyle = '#fff'
        ctx.stroke()

{ Renderer } = require './render'

renderer = new Renderer
renderer.on_drain = ->
    ctx = renderer.ctx

    ctx.fillStyle = "#000"
    ctx.fillRect 0, 0, W, H

    tick()
    drawTrack ctx
