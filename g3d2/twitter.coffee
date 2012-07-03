{ Renderer, Compositor, DrawText } = require './render'
{ getNow, pick_randomly } = require './util'

renderer = new Renderer
compositor = new Compositor renderer.width, renderer.height

renderer.on_drain = ->
    console.log "on_drain"
    ctx = renderer.ctx

    ctx.fillStyle = '#000'
    ctx.fillRect 0, 0, renderer.width, renderer.height
    ctx.antialias = 'none'

    compositor.tick()
    compositor.draw renderer.ctx

NTwitter = require('ntwitter');

twitter = new NTwitter
    consumer_key: "toq8i4Hf5GX8D6tmj9WXxQ"
    consumer_secret: "ul1T7WC3NnoMMGpf2ddmoYPlZ2Vlxbe7w8QFinxw",
    access_token_key: "61287780-DAB4VkNZRkBwhnQPTCCRRedbax9xR8jDa2xAsCtfR",
    access_token_secret: "xn969zVJq6Idn5I6WnGwl5EHZo4gj5vqqVuyd2wGg4"

twitter.stream 'user',
    track: [#"hacker", "ccc"
              "c3d2"
              "pentaradio", "pentacast"
              "dresden", "chaos computer club"
              "Gauck", "Schramm", "Wulff"
              "nodejs", "coffeescript", "buddycloud", "arduino", "ipv6"
            ]
    , (stream) ->
        stream.on 'data', (tweet) ->
            console.log('tweet', tweet)
            if tweet.text
                compositor.add new DrawText("#{new Date(tweet.created_at).toLocaleTimeString()} @#{tweet.user?.screen_name}\n#{tweet.text}")

