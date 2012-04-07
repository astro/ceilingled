{ Output } = require './g3d2_output'

last_rect = null
xOffset = 0
yOffset = 0


normalize_frame_mono = (frame) ->
    minBrightness = 3 * 255 - 1
    maxBrightness = 1
    for y in [0..frame.h-1]
        for x in [0..frame.w-1]
            rgb = frame.pixels[y][x]
            brightness = rgb[0] + rgb[1] + rgb[2]
            if brightness > maxBrightness
                maxBrightness = brightness
            if brightness < minBrightness
                minBrightness = brightness

    pixels = []
    for y in [0..frame.h-1]
        pixels.push (line = [])
        for x in [0..frame.w-1]
            rgb = frame.pixels[y][x]
            brightness = rgb[0] + rgb[1] + rgb[2]
            b = Math.ceil(255 * (brightness - minBrightness) / Math.max(1, maxBrightness - minBrightness))
            line[x] = [b, b, b]

    pixels

normalize_frame_rgb = (frame) ->
    return frame.pixels

    minRGB = [254, 254, 254]
    maxRGB = [1, 1, 1]
    for y in [0..frame.h-1]
        for x in [0..frame.w-1]
            rgb = frame.pixels[y][x]
            for i in [0..2]
                if rgb[i] > maxRGB[i]
                    maxRGB[i] = rgb[i]
                if rbg[i] < minRGB[i]
                    minRGB[i] = rgb[i]

    pixels = []
    for y in [0..frame.h-1]
        pixels.push (line = [])
        for x in [0..frame.w-1]
            rgb = frame.pixels[y][x]
            for i in [0..2]
                rgb[i] = Math.ceil(255 * (rgb[i] - minRGB[i]) / Math.max(1, maxRGB[i] - minRGB[i]))
                if rgb[i] < minRGB[i] or rgb[i] > maxRGB[i]
                    console.log "fail rgb", rgb, "min max", minRGB, maxRGB
            line[x] = rgb

    pixels


output = new Output 'bender.hq.c3d2.de', 1340
output.on 'init', ->
output.on_drain = ->
    if last_rect
        t1 = new Date().getTime()
        last_rect.pixels = normalize_frame_rgb last_rect
        t2 = new Date().getTime()
        console.log "normalize rgb", t2 - t1

        if /^g3d2/.test output.name
            t1 = new Date().getTime()
            last_rect.pixels = normalize_frame_mono last_rect
            t2 = new Date().getTime()
            console.log "normalize mono", t2 - t1

        for y in [0..last_rect.h-1]
            for x in [0..last_rect.w-1]
                rgb = last_rect.pixels[y][x]
                if /^g3d2/.test output.name
                    output.putPixel x, y, rgb...
                else
                    #console.log "x", x, "y", y, "rgb", rgb...
                    output.putPixel x, y, rgb...

{VNCClient} = require('vnc-client')


vnc = new VNCClient("localhost", 0, "secret")

req_update = ->
    vnc.requestUpdate xOffset, yOffset, output.width, output.height

vnc.on 'init', (params) ->
    console.log "init", params
    req_update()

vnc.on 'rect', (rect) ->
    last_rect = rect
    req_update()

