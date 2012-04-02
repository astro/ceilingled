Font = require './pixelfont'

W = 72
H = 32

class Projectile
    constructor: ({@attacker, @energy, yOffset}) ->
        console.log "Projectile.yOffset", yOffset
        if @attacker.constructor is Player
            @x = @attacker.x + 1
        else
            @x = @attacker.x - 1
        @y = @attacker.y + yOffset

    draw: (ctx, cb) ->
        ctx.save()
        ctx.translate(@x, @y)

        cb()

        ctx.restore()

    tick: ->
        if @attacker.constructor is Player
            @x += @dx
        else
            @x -= @dx
        if @x < -1 or @x > W + 1
            rmObject @

        for object in objects.concat(players)
            if object?.damage and
               object isnt @attacker and
               @x >= object.x - object.width / 2 and
               @x <= object.x + object.width / 2 + @dx and
               @y >= object.y - object.height / 2 and
               @y <= object.y + object.height / 2
                # Hit!
                console.log "Hit #{object.x}x#{object.y}+#{object.width}x#{object.height}+#{@dx} with #{@energy} by #{@x}x#{@y}"
                object.damage @energy, @attacker
                rmObject @
                #objects.push new Explosion(@x, @y, @attacker, 5)
                break

class LaserProjectile extends Projectile
    dx: 3

    draw: (ctx) ->
        super ctx, ->
            ctx.beginPath()
            ctx.moveTo(0, 0)
            ctx.lineTo(3, 0)
            ctx.strokeStyle = '#99f'
            ctx.stroke()

class NukeProjectile extends Projectile
    dx: 1.5

    tick: ->
        super

        targets = objects.filter (o) ->
            o.damage? and o?.constructor isnt Projectile
        lock = null
        lock_distance = null
        for target in targets
            distance = Math.sqrt(Math.pow(@x - target.x, 2) + Math.pow(@y - target.y, 2))
            if lock is null or
               distance < lock_distance
                lock = target
                lock_distance = distance
        if lock and lock.y < @y
            @y -= 0.5
        else if lock and lock.y > @y
            @y += 0.5

    draw: (ctx) ->
        super ctx, ->
            ctx.beginPath()
            ctx.moveTo(-1, -1)
            ctx.lineTo(2, 0)
            ctx.lineTo(-1, 1)
            ctx.fillStyle = '#fa0'
            ctx.fill()

    damage: (amount, attacker) ->
        rmObject @
        objects.push new Explosion @x, @y, attacker, 4

class Weapon
    constructor: ({@player, yOffset}) ->
        @yOffset = yOffset || 0
        @active = yes #no
        @reloading = 0

    tick: ->
        if @reloading > 0
            @reloading--

        if @active and @reloading <= 0
            @trigger()
            @reloading = @reload_time

    trigger: ->
        objects.push new @projectile({attacker: @player, @energy, @yOffset})

class Laser extends Weapon
    reload_time: 4
    energy: 2
    projectile: LaserProjectile

class Nuke extends Weapon
    reload_time: 50
    energy: 10
    projectile: NukeProjectile


class Explosion
    constructor: (@x, @y, @attacker, @steps=6) ->
        @radius = 2
        @brightness = 1

    tick: ->
        @radius++
        @brightness -= 1 / @steps
        if @brightness <= 0
            rmObject @
        else
            # Damage
            for o in objects
                if o?.damage
                    distance = Math.sqrt(Math.pow(o.x - @x, 2) + Math.pow(o.y - @y, 2))
                    if distance <= @radius
                        o.damage 10 * @brightness, @attacker

    draw: (ctx) ->
        ctx.save()
        ctx.translate(@x, @y)

        ctx.beginPath()
        ctx.arc 0, 0, @radius, 0, 2 * Math.PI
        [r, g, b] = explosion_color @brightness
        ctx.fillStyle = "rgb(#{r}, #{g}, #{b})"
        globalAlpha = ctx.globalAlpha
        ctx.globalAlpha = Math.sin(@brightness * Math.PI / 2)
        ctx.fill()

        ctx.globalAlpha = globalAlpha
        ctx.restore()

explosion_step = (n) ->
    switch n
        when 0
            [255, 0, 0, 255]
        when 1
            [255, 255, 0, 0]
        when 2
            [255, 233, 0, 0]
        else
            r = 255 * (1 - (n - 2) / 5)
            g = Math.max 0, 233 * (1 - (n - 2) / 3)
            [r, g, 0, 0]

explosion_color = (brightness) ->
    brightness = 1 - brightness
    brightness1 = Math.floor(brightness * 7)
    brightness2 = Math.ceil(brightness * 7)
    [r1, g1, b1, w1] = explosion_step brightness1
    if brightness1 is brightness2
        return [r1, g1, b1, w1]

    [r2, g2, b2, w2] = explosion_step brightness2
    d = 7 * brightness - brightness1
    a = (a1, a2) -> Math.ceil(a1 * d + a2 * (1 - d))
    [
        a r1, r2
        a g1, g2
        a b1, b2
        a w1, w2
    ]

class Enemy
    width: 4
    height: 3
    health: 20

    constructor: ->
        @x = W + 2
        @y = Math.ceil(Math.random() * H - 2) + 1
        @brightness = 224
        @makeNewDest()
        @weapons = [
            new Laser player: @
        ]

    makeNewDest: ->
        @destX = Math.floor(W * (Math.random() * 0.5 + 0.4))
        @destY = Math.floor(H * (Math.random() * 0.8 + 0.1))

    tick: ->
        # Move
        if @x < @destX - 0.5
            @x += 1
        else if @x > @destX + 0.5
            @x -= 1
        else
            @makeNewDest()

        if @y < @destY - 0.5
            @y += 1
        else if @y > @destY + 0.5
            @y -= 1
        else
            @makeNewDest()

        # Blink:
        @brightness = Math.min(@brightness + 32, 255)

        # Attack
        canHitPlayer = players.some (player) =>
            player.x <= @x and
            player.y > @y - @height and
            player.y < @y + @height
        for weapon in @weapons
            weapon.active = canHitPlayer
            weapon.tick()

    damage: (amount, attacker) ->
        @health -= amount
        # Blink:
        @brightness = 16

        if @health < 1
            rmObject @
            objects.push new Explosion @x, @y, attacker, 10
            attacker.award? 10
        else
            attacker.award? amount

    draw: (ctx) ->
        ctx.save()
        ctx.translate(@x, @y)

        ctx.beginPath()
        ctx.moveTo(-1, -1.5)
        ctx.lineTo(1, -1)
        ctx.lineTo(1, 1)
        ctx.lineTo(-1, 1.5)
        ctx.fillStyle = "rgb(0, #{@brightness}, 0)"
        ctx.fill()

        ctx.restore()

class Boss extends Enemy
    width: 3
    height: 6
    health: 200

    constructor: ->
        super
        @weapons = [
            new Laser player: @, yOffset: -3
            new Laser player: @, yOffset: 3
            new Nuke player: @
        ]
        @move_i = 0

    makeNewDest: ->
        @destX = Math.floor(W * (Math.random() * 0.7 + 0.2))
        @destY = Math.floor(H * (Math.random() * 0.8 + 0.1))

    tick: ->
        # Move
        @move_i = (@move_i + 2) % 3
        if @move_i is 0
            if @x < @destX - 0.5
                @x += 1
            else if @x > @destX + 0.5
                @x -= 1
            else
                @makeNewDest()

            if @y < @destY - 0.5
                @y += 1
            else if @y > @destY + 0.5
                @y -= 1
            else
                @makeNewDest()

        # Blink:
        @brightness = Math.min(@brightness + 32, 255)

        # Attack
        for weapon in @weapons
            weapon.active = yes # always
            weapon.tick()

    draw: (ctx) ->
        ctx.save()
        ctx.translate(@x, @y)

        ctx.beginPath()
        ctx.moveTo(-1, -3)
        ctx.lineTo(1, -3)
        ctx.lineTo(2, 0)
        ctx.lineTo(1, 3)
        ctx.lineTo(-1, 3)
        ctx.lineTo(0.5, 0)
        ctx.fillStyle = "rgb(0, #{@brightness}, #{@brightness})"
        ctx.fill()

        ctx.restore()

    damage: (amount, attacker) ->
        @health -= amount
        # Blink:
        @brightness = Math.floor(255, @health / 200)

        if @health < 1
            rmObject @
            objects.push new Explosion @x, @y, attacker, 20
            attacker.award? 30
        else
            attacker.award? amount

class Player
    width: 4
    height: 3
    constructor: (@name, @x, @y, @color) ->
        @destX = @x
        @destY = @y
        @x = -5
        @health = 100
        @score = 0
        @displayScore = 0
        @brightness = 255

        @weapons = [
            new Laser player: @
            new Nuke player: @
        ]

    tick: ->
        # Blink:
        @brightness = Math.min(@brightness + 32, 255)

        # Move
        if @x < @destX - 1
            @x += 2
        else if @x > @destX + 1
            @x -= 2

        if @y < @destY - 1
            @y += 2
        else if @y > @destY + 1
            @y -= 2

        # Fire
        for weapon in @weapons
            weapon.tick()

    damage: (energy, attacker) ->
        # Blink:
        @brightness = Math.floor(255, @health / 100)
        objects.push new Explosion @x, @y, attacker, 3

        @health -= energy
        if @health < 1
            @award -100
            attacker.award? -10
            objects.push new Explosion @x, @y, attacker, 10

            @health = 100
            @x = -10

        attacker.award? -10

    award: (score) ->
        @score += score

    draw: (ctx) ->
        ctx.save()
        ctx.translate(@x, @y)

        ctx.beginPath()
        ctx.moveTo(1, 0)
        ctx.lineTo(-3, 2)
        ctx.lineTo(-2, 0)
        ctx.lineTo(-3, -2)
        ctx.fillStyle = "rgb(#{@brightness}, #{@brightness}, #{@brightness})"
        ctx.fill()

        ctx.restore()

    drawHUD: (ctx) ->
        ###
        if @displayScore < Math.floor(@score)
            @displayScore++
        else if @displayScore > Math.floor(@score)
            @displayScore--
        ###
        @displayScore = Math.floor @score

        ctx.save()
        ctx.translate(@x, @y)

        ctx.fillStyle = @color
        putText = (s, x, y) ->
            Font.putText ctx, x - Font.textWidth(s), y, s

        putText "#{@name}", -2, -6
        putText "#{Math.floor @displayScore}", -2, 1

        # Health bar
        ctx.beginPath()
        ctx.moveTo -2, 0.5
        ctx.lineTo -2 - (16 * @health / 100), 0.5
        ctx.strokeStyle = @color
        ctx.stroke()

        ctx.restore()


class Star
    constructor: ->
        @x = W
        @dx = 2 * Math.random() + 1
        @y = Math.floor(Math.random() * H)
        @brightness = Math.ceil(Math.random() * 15) + 16

    tick: ->
        @x -= @dx

    draw: (ctx) ->
        ctx.fillStyle = "rgb(#{@brightness}, #{@brightness}, #{@brightness})"
        ctx.fillRect @x, @y, 1, 1

players = [
    new Player("P1", 8, 5, '#f00')
    new Player("P2", 24, 12, '#00f')
    #new Player("P3", 24, 20, '#0f0')
    #new Player("P4", 8, 27, '#ff0')
]

maxEnemies = 1
setInterval ->
    maxEnemies++ if maxEnemies < 8
, 30000

objects = []
rmObject = (o) ->
    if (i = objects.indexOf(o)) >= 0
        objects.splice(i, 1)

stars = []

tick = ->
    if Math.random() < 0.4
        stars.push new Star
    stars = stars.filter (star) ->
        star.tick()
        return star.x >= 0
    console.log("stars", stars.length)

    for player in players
        player.tick()
    enemies = 0
    for object in objects
        if object?.constructor is Enemy or object?.constructor is Boss
            enemies++
        object?.tick()
    if enemies < maxEnemies
        if Math.random() < 0.1
            objects.push new Boss
        else
            objects.push new Enemy
    console.log("objects", objects.length)

setInterval tick, 50


drawScene = (ctx) ->
    ctx.fillStyle = "#000"
    ctx.fillRect -g3d2.output.width, -g3d2.output.height, g3d2.output.width*2, g3d2.output.height*2

    ctx.save()
    for star in stars
        star.draw(ctx)
    ctx.translate 0.5, 0.5
    for object in objects
        object.draw(ctx)
    for player in players
        player.draw(ctx)
    ctx.restore()

{ Renderer } = require './render'

g3d2 = new Renderer 'g3d2.hq.c3d2.de', 1339
g3d2.output.on 'init', ->
g3d2.on_drain = ->
    ctx = g3d2.ctx
    ctx.antialias = 'grey'
    drawScene ctx

pentawallHD = new Renderer 'bender.hq.c3d2.de', 1340

pentawallHD.on_drain = ->
    ctx = pentawallHD.ctx
    ctx.antialias = 'grey'

    i = 0
    for player in players
        ctx.save()

        ctx.rect(0, i * pentawallHD.output.height / 2,
            pentawallHD.output.width, pentawallHD.output.height / 2)
        ctx.clip()

        ctx.translate pentawallHD.output.width - 6 - player.x,
            pentawallHD.output.height * (1 + i * 2) / 4 - player.y - 1

        drawScene ctx
        player.drawHUD(ctx)

        ctx.restore()
        i++


    ceilingBrightness = [0, 0, 0, 0]
    for object in objects
        if object.constructor is Explosion and
           (i = players.indexOf(object.attacker)) >= 0
            if ceilingBrightness[i] < object.brightness
                ceilingBrightness[i] = object.brightness
    for i in [0..3]
        brightness = ceilingBrightness[i]
        #r = Math.ceil(Math.sin(brightness * Math.PI / 2) * 255)
        #g = Math.ceil(brightness * 255)
        if brightness isnt 0
            console.log "explosion_color", brightness, explosion_color(brightness)
        pentawallHD.output.putCeiling i, explosion_color(brightness)...

pentawallHD.output.on 'slider', (id, value) ->
    console.log "slider", id, value
    switch id
        when 1
            players[0].destY = (1 - value) * (H - 2) + 1
        when 3
            players[1].destY = (1 - value) * (H - 2) + 1
        when 7
            players[2].destY = (1 - value) * (H - 2) + 1
        when 9
            players[3].destY = (1 - value) * (H - 2) + 1
pentawallHD.output.on 'knob', (id, value) ->
    console.log "knob", id, value
    switch id
        when 1
            players[0].destX = value * (W - 2) + 1
        when 3
            players[1].destX = value * (W - 2) + 1
        when 7
            players[2].destX = value * (W - 2) + 1
        when 9
            players[3].destX = value * (W - 2) + 1
pentawallHD.output.on 'button', (id, value) ->
    console.log "button", id, value
    switch id
        when '1a'
            players[0].weapons[0].active = value
        when '1b'
            players[0].weapons[1].active = value
        when '3a'
            players[1].weapons[0].active = value
        when '3b'
            players[1].weapons[1].active = value
        when '7a'
            players[2].weapons[0].active = value
        when '7b'
            players[2].weapons[1].active = value
        when '9a'
            players[3].weapons[0].active = value
        when '9b'
            players[3].weapons[1].active = value
