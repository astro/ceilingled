{ Renderer, Compositor, DrawText } = require './render'
{ getNow, pick_randomly } = require './util'

renderer = new Renderer
compositor = new Compositor renderer.width, renderer.height

renderer.on_drain = ->
    console.log "on_drain"
    ctx = renderer.ctx

    ctx.fillStyle = '#000'
    ctx.fillRect 0, 0, renderer.width, renderer.height
    ctx.antialias = 'grey'

    compositor.tick()
    compositor.draw renderer.ctx

NTwitter = require('ntwitter');

twitter = new NTwitter
    consumer_key: "***"
    consumer_secret: "***",
    access_token_key: "***-***",
    access_token_secret: "***"

twitter.stream 'user',
    track: ["hacker", "ccc", "c3d2"
              "pentaradio", "pentacast"
              "dresden"
              "Gauck", "Schramm", "Wulff"
            ]
    replies: 'all'
    , (stream) ->
        stream.on 'data', (tweet) ->
            console.log('tweet', tweet)
            if tweet.text
                compositor.add new DrawText("#{new Date(tweet.created_at).toLocaleTimeString()} @#{tweet.user?.screen_name}\n#{tweet.text}")

