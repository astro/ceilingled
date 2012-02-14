exports.getNow = ->
    new Date().getTime()

exports.pick_randomly = (a...) ->
    a[Math.floor(Math.random() * a.length)]
