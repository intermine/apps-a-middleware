#!/usr/bin/env coffee

# All the handlers we know about.
rules = [
    [ /^(presenter|app)((\.coffee)|(\/(.*)\.coffee))/g, 'module', 'coffeescript' ]
    [ /^(presenter|app)((\.js)|(\/(.*)\.js))/g, 'module', 'generic' ]
    [ /^(presenter|app)((\.ls)|(\/(.*)\.ls))/g, 'module', 'livescript' ]
    [ /^(presenter|app)((\.ts)|(\/(.*)\.ts))/g, 'module', 'typescript' ]
    [ /^(.*)\.css/g, 'style', 'generic' ]
    [ /^(.*)\.styl/g, 'style', 'stylus' ]
    [ /^(.*)\.eco/g, 'template', 'eco' ]
    [ /^(.*)\.hogan/g, 'template', 'hogan' ]
]

# Can we handle this file?
module.exports = (path, file, cb) ->
    for entry in rules
        [ rule, type, handler ] = entry
        if file.match rule
            # Process it...
            return require("#{__dirname}/types/#{handler}.coffee") path, file, (err, output) ->
                return cb err if err
                # ...adding our type and filename.
                cb null, [ type, file, output ]

    # Don't know this.
    return cb null, [ null, null ]