# TODO: clouds, night mode
W = 32
H = 32
CAM_Y = 7
track = []
camZ = 0
phase = 0
phase_delta = 1
dx_amplitude = 0
dy_amplitude = 0
roofed_phase = no
scenery_dx = 0
scenery_dy = 0

class Segment
    constructor: ->
        phase += phase_delta
        if phase >= Math.PI
            phase %= Math.PI
            dx_amplitude = Math.random() * 8 - 4
            console.log "dx_amplitude", dx_amplitude
            dy_amplitude = Math.random() * 6 - 2
            console.log "dy_amplitude", dy_amplitude
            phase_delta = Math.PI / (8 + 23 * Math.random())
            console.log "phase_delta", phase_delta
            roofed_phase = Math.random() > 0.6

        @dx = Math.sin(phase) * dx_amplitude
        @dy = Math.sin(phase) * dy_amplitude
        @w = Math.sin(phase) * 4 + 4
        @h = Math.sin(phase) * 10 + 3
        @rgb = [
            127 + Math.ceil(127 * Math.random())
            127 + Math.ceil(127 * Math.random())
            127 + Math.ceil(127 * Math.random())
        ]
        @roofed = roofed_phase

    depth: 6

tick = ->
    if track[0]
        velocity = 2
        if track[0].dy > 0
            #velocity *= 1 + track[0].dy / 10
        else
            velocity /= 1 - track[0].dy / 5
        console.log "velocity", velocity
        camZ += velocity
    while track[0] and track[0].depth < camZ
        camZ -= track[0].depth
        scenery_dx += track[0].dx / 10
        scenery_dy = 2 - track[0].dy / 5
        console.log "camZ", camZ
        track.splice(0, 1)

    while track.length < 80
        track.push new Segment()

getTrackTranslation = (z) ->
    z -= camZ
    i = 0
    #while track[i] && z >= track[i].depth

drawTrack = (ctx) ->
    ##
    # Calculate Track Coordinates
    ##

    z1 = -camZ + track[0].depth + 0.1
    console.log "camZ", camZ, "dx", track[0].dx, "dy", track[0].dy
    x = track[0].dx * (1 - camZ / track[0].depth)
    y = track[0].dy * (1 - camZ / track[0].depth) + CAM_Y

    segs = []

    for i in [1..track.length-1]
        seg1 = track[i - 1]
        seg2 = track[i]
        x2 = x + seg2.dx
        y2 = y + seg2.dy
        z2 = z1 + seg2.depth
        yDisplace = 0 #-z / 1000
        n = 5 - i
        if n > 0
            if seg1.roofed
                updateCeiling i-1, seg1.rgb
            else
                updateCeiling i-1, seg1.rgb.map (color) -> color / 3

        top = H * ((y - seg1.h) / z1 + 0.5) + yDisplace
        bottom = H * (y / z1 + 0.5) + yDisplace
        if i is 1
            #top = Math.min top, 0
            bottom = Math.max bottom, H
        segs.push
            front:
                x1: W * ((x - seg1.w) / z1 + 0.5)
                x2: W * ((x + seg1.w) / z1 + 0.5)
                y1: top
                y2: bottom
            back:
                x1: W * ((x2 - seg2.w) / z2 + 0.5)
                y1: H * ((y2 - seg2.h) / z2 + 0.5) + yDisplace
                x2: W * ((x2 + seg2.w) / z2 + 0.5)
                y2: H * (y2 / z2 + 0.5) + yDisplace
            z: z2
            roofed: seg1.roofed and seg1.h > CAM_Y + 2 and seg2.h > CAM_Y + 2
            floorColor: seg1.rgb

        x = x2
        y = y2
        z1 = z2

    ##
    # Draw Scenery
    ##

    bottom = segs[segs.length - 1].back.y1 + 2
    drawMountain = (x, y, size) ->
        # Slopes
        ctx.beginPath()
        ctx.moveTo x, y
        ctx.lineTo x + size, y
        ctx.lineTo x + size / 2, y - size / 2
        ctx.fillStyle = '#555'
        ctx.fill()
        # Snow Cap
        ctx.beginPath()
        ctx.moveTo x + 2 * size / 6, y - 2 * size / 6
        ctx.lineTo x + 4 * size / 6, y - 2 * size / 6
        ctx.lineTo x + size / 2, y - size / 2
        ctx.fillStyle = '#eee'
        ctx.fill()

    # FIXME: was too lazy for proper calculashun
    for i in [-3..3]
        drawMountain scenery_dx + i * 24, bottom + scenery_dy, 21
        drawMountain scenery_dx + i * 24 + 14, bottom + scenery_dy, 15

    ##
    # Draw Precalculated Track (in reverse)
    ##

    for i in [segs.length-1..0]
        { front, back, z, roofed, floorColor } = segs[i]

        # fog
        ctx.fillStyle = "rgba(0, 0, 0, #{Math.max(0, z / 2000)})"
        ctx.fillRect back.x1, back.y1, back.x2 - back.x1, back.y2 - back.y1

        # left landscape
        ctx.beginPath()
        ctx.moveTo front.x1, front.y2 + 2
        ctx.lineTo 0, front.y2 + 2
        ctx.lineTo 0, back.y2 + 2
        ctx.lineTo back.x1, back.y2 + 2
        ctx.fillStyle = '#070'
        ctx.fill()
        # right landscape
        ctx.beginPath()
        ctx.moveTo front.x2, front.y2 + 2
        ctx.lineTo W, front.y2 + 2
        ctx.lineTo W, back.y2 + 2
        ctx.lineTo back.x2, back.y2 + 2
        ctx.fillStyle = '#070'
        ctx.fill()
        # left wall
        ctx.beginPath()
        ctx.moveTo back.x1, back.y1
        ctx.lineTo back.x1, back.y2 + 2
        ctx.strokeStyle = '#ba0'
        ctx.stroke()
        ctx.beginPath()
        ctx.moveTo front.x1, front.y1
        ctx.lineTo front.x1, front.y2 + 2
        ctx.lineTo back.x1, back.y2 + 2
        ctx.lineTo back.x1, back.y1
        ctx.fillStyle = '#dc4'
        ctx.fill()
        # right wall
        ctx.beginPath()
        ctx.moveTo back.x2, back.y1
        ctx.lineTo back.x2, back.y2 + 2
        ctx.strokeStyle = '#ba0'
        ctx.stroke()
        ctx.beginPath()
        ctx.moveTo front.x2, front.y1
        ctx.lineTo front.x2, front.y2 + 2
        ctx.lineTo back.x2, back.y2 + 2
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
        ctx.fillStyle = "rgb(#{floorColor.join(',')})"
        ctx.fill()
        # ceiling
        if roofed
            ###
            ctx.beginPath()
            ctx.moveTo back.x1, back.y1
            ctx.lineTo back.x2, back.y1
            ctx.strokeStyle = '#111'
            ctx.stroke()
            ###
            ctx.beginPath()
            ctx.moveTo front.x1, front.y1
            ctx.lineTo front.x2, front.y1
            ctx.lineTo back.x2, back.y1
            ctx.lineTo back.x1, back.y1
            ctx.fillStyle = "rgba(#{floorColor.join(',')}, 0.95)"
            ctx.fill()

        ctx.beginPath()
        # ul
        ctx.moveTo front.x1, front.y1
        ctx.lineTo back.x1, back.y1
        # ur
        ctx.moveTo front.x2, front.y1
        ctx.lineTo back.x2, back.y1
        ctx.strokeStyle = '#eee'
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
W = renderer.width
H = renderer.height
renderer.on_drain = ->
    ctx = renderer.ctx

    ctx.fillStyle = "#00c"
    ctx.fillRect 0, 0, W, H

    tick()
    drawTrack ctx

updateCeiling = (n, rgb) ->
    #console.log "updateCeiling", n, r, g, b
    maxColor = Math.max(rgb...)
    rgb = rgb.map (color) ->
        if color is maxColor
            color
        else
            Math.ceil(Math.pow(color / 255, 4) * 255)
    renderer.output.putCeiling n, rgb...
