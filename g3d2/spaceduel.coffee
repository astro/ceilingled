W = 72
H = 32

class Projectile
    constructor: ({@attacker, @energy}) ->
        if @attacker.constructor is Player
            @x = @attacker.x + 1
            @y = @attacker.y
        else
            @x = @attacker.x - 1
            @y = @attacker.y

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
               @x >= object.x - 1 and
               @x <= object.x + @dx and
               @y >= object.y - 1 and
               @y <= object.y + 1
                # Hit!
                console.log "Hit #{object} with #{@energy} by #{@}"
                object.damage @energy, @attacker
                rmObject @
                #objects.push new Explosion(@x, @y, 3)
                break

class LaserProjectile extends Projectile
    dx: 3

    draw: (ctx) ->
        super ctx, ->
            ctx.beginPath()
            ctx.moveTo(0, 0)
            ctx.lineTo(3, 0)
            ctx.strokeStyle = '#888'
            ctx.stroke()

class NukeProjectile extends Projectile
    dx: 1.5

    draw: (ctx) ->
        super ctx, ->
            ctx.beginPath()
            ctx.moveTo(-1, -1)
            ctx.lineTo(2, 0)
            ctx.lineTo(-1, 1)
            ctx.fillStyle = '#444'
            ctx.fill()


class Weapon
    constructor: ({@player}) ->
        @active = no
        @reloading = 0

    tick: ->
        if @reloading > 0
            @reloading--

        if @active and @reloading <= 0
            @trigger()
            @reloading = @reload_time

    trigger: ->
        objects.push new @projectile({attacker: @player, @energy})

class Laser extends Weapon
    reload_time: 3
    energy: 2
    projectile: LaserProjectile

class Nuke extends Weapon
    reload_time: 30
    energy: 10
    projectile: NukeProjectile


class Explosion
    constructor: (@x, @y, @steps=6) ->
        @radius = 2
        @brightness = 1

    tick: ->
        @radius++
        # TODO: damage
        @brightness -= 1 / @steps
        if @brightness <= 0
            rmObject @

    draw: (ctx) ->
        ctx.save()
        ctx.translate(@x, @y)

        ctx.beginPath()
        ctx.arc 0, 0, @radius, 0, 2 * Math.PI
        r = Math.ceil(Math.sin(@brightness * Math.PI / 2) * 255)
        g = Math.ceil(@brightness * 255)
        ctx.fillStyle = "rgb(#{r}, #{g}, 0)"
        globalAlpha = ctx.globalAlpha
        ctx.globalAlpha = Math.sin(@brightness * Math.PI / 2)
        ctx.fill()

        ctx.globalAlpha = globalAlpha
        ctx.restore()

class Enemy
    constructor: ->
        @x = W + 2
        @y = Math.ceil(Math.random() * H - 2) + 1
        @health = 10
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
            player.y > @y - 2 and
            player.y < @y + 2
        for weapon in @weapons
            weapon.active = canHitPlayer
            weapon.tick()

    damage: (amount, attacker) ->
        @health -= amount
        # Blink:
        @brightness = 16

        if @health < 1
            rmObject @
            objects.push new Explosion @x, @y
            attacker.award? 100
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


class Player
    constructor: (@name, @x, @y, @color) ->
        @destX = @x
        @destY = @y
        @health = 100
        @score = 0
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
        @brightness = 16
        @health -= energy
        if @health < 1
            @award -1000
            objects.push new Explosion @x, @y, 10

            @health = 100
            @x = 3

        attacker.award? -10

    award: (score) ->
        @score += score

    draw: (ctx) ->
        ctx.save()
        ctx.translate(@x, @y)

        ctx.beginPath()
        ctx.moveTo(1, 0)
        ctx.lineTo(-2, 2)
        ctx.lineTo(-1, 0)
        ctx.lineTo(-2, -2)
        ctx.fillStyle = "rgb(#{@brightness}, #{@brightness}, #{@brightness})"
        ctx.fill()

        ctx.restore()

    drawHUD: (ctx) ->
        ctx.save()
        ctx.translate(@x, @y)

        ctx.font = "8px TratexSvart"
        ctx.fillStyle = @color
        putText = (s, x, y) ->
            m = ctx.measureText(s)
            ctx.fillText(s, x - m.width, y)

        putText "#{@name}", -1, 0
        putText "#{@score}", -1, 8

        # Health bar
        ctx.beginPath()
        ctx.moveTo -1, 0
        ctx.lineTo -1 - (8 * @health / 100), 0
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
    new Player("P1", 10, 8, '#f00')
    new Player("P2", 10, 24, '#00f')
]

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
        if object?.constructor is Enemy
            enemies++
        object?.tick()
    if enemies < 2
        objects.push new Enemy
    console.log("objects", objects.length)

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
    tick()
    ctx = g3d2.ctx
    drawScene ctx

updateCeiling = (n, rgb) ->
    #console.log "updateCeiling", n, r, g, b
    maxColor = Math.max(rgb...)
    rgb = rgb.map (color) ->
        if color is maxColor
            color
        else
            Math.ceil(Math.pow(color / 255, 4) * 255)
    renderer.output.putCeiling n, rgb...

pentawallHD = new Renderer 'bender.hq.c3d2.de', 1340

pentawallHD.on_drain = ->
    ctx = pentawallHD.ctx
    ctx.save()
    ctx.translate pentawallHD.output.width / 2 - players[0].x, pentawallHD.output.height / 2 - players[0].y
    drawScene ctx

    # Draw scores
    for player in players
        player.drawHUD(ctx)

    ctx.restore()

pentawallHD.output.on 'slider', (id, value) ->
    console.log "slider", id, value
    switch id
        when 1
            players[0].destX = value * (W - 2) + 1
        when 2
            players[0].destY = (1 - value) * (H - 2) + 1
        when 8
            players[1].destX = value * (W - 2) + 1
        when 9
            players[1].destY = (1 - value) * (H - 2) + 1
pentawallHD.output.on 'button', (id, value) ->
    console.log "button", id, value
    switch id
        when '1a'
            players[0].weapons[0].active = value
        when '2a'
            players[0].weapons[1].active = value
        when '8a'
            players[1].weapons[0].active = value
        when '9a'
            players[1].weapons[1].active = value
