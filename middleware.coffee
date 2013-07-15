#!/usr/bin/env coffee
urlib    = require 'url'
director = require 'director'
async    = require 'async'
{ exec } = require 'child_process'
{ _ }    = require 'lodash'
fs       = _.extend require('fs-extra'), require('fs')
log      = require 'node-logging'

# Require builder.
builder = require './builder.coffee'

# We are here.
dir = __dirname

# Here be our router once ready.
router = null

# Pass us the config merged from all different sources.
routes = (config) ->
    # A generic responder in the proper scope.
    respond = (res) ->
        (code, out) ->
            # Apples vs oranges.
            switch typeof out
                when 'object'
                    type = 'application/json'
                    out = JSON.stringify out
                when 'string'
                    type = 'application/javascript;charset=utf-8'

            # Warn us.
            if (''+code)[0] isnt '2' then log.err out

            # Blargh.
            res.writeHead code, 'content-type': type
            res.write out
            res.end()

    # List all available apps.
    '/middleware/apps/a':
        'get': ->
            res = respond @res

            # Do we have a callback?
            if (callback = urlib.parse(@req.url, true).query?.callback)                
                out = {}
                for app, stuff of config
                    out[app] = stuff.dependencies

                res 200, "#{callback}(#{JSON.stringify(out)});"
            else
                return res 500, { 'message': 'Provide a `callback` parameter so we can respond with JSONP' }

    # Get a single app.
    '/middleware/apps/a/:appId':
        'get': (appId) ->
            res = respond @res

            # Do we have a callback?
            if (callback = urlib.parse(@req.url, true).query?.callback)                
                # Do we know this one?
                app = config[appId]
                if app?
                    # OK we 'should' exist. Do we?
                    async.waterfall [ (cb) ->
                        fs.exists (path = [ dir, 'tmp/build', appId + '.js' ].join('/')), (exists) ->
                            return cb "`#{appId}` file missing" unless exists
                            cb null, path

                    # Read it then.
                    (path, cb) ->
                        fs.readFile path, 'utf8', cb
                    
                    # Process the file.
                    (js, cb) ->                        
                        # Make a clone for us.
                        obj = _.cloneDeep app

                        # The config can have example fns but we remove them now.
                        # Otherwise in which context are they supposed to run?
                        obj.config = JSON.stringify obj.config or {}

                        # Default app root index module thing.
                        obj.appRoot ?= 'presenter' # `/presenter.ts` etc.

                        # Not a default.
                        obj.callback = callback

                        # Replace the placeholders with actual values.
                        for key, value of obj
                            # Replace this everywhere you see it.
                            js = js.replace new RegExp("#@\\+" + key.toUpperCase(), 'gmi'), value

                        # Looking good.
                        res 200, js

                    ], (err) ->
                        return res 500, { 'message': err } if err

                else
                    res 400, { 'message': "Unknown app `#{appId}`" }
            else
                res 400, { 'message': 'Callback not provided' }

module.exports = (opts) ->
    { apps, config } = opts

    # Always have an empty one.
    config ?= {}

    # This will take a while.
    ready = no

    # Process config.
    async.waterfall [ (cb) ->
        async.waterfall [ (cb) ->
            switch typeof config
                # Assume is a path to load.
                when 'string'
                    # People will/might pass a file:// prefix.
                    config = config.replace 'file://', ''
                    # Actually read.
                    fs.readJson config, (err, json) ->
                        return cb err if err
                        config = json
                        cb null

                # OK, no processing needed here
                when 'object' then cb null
                
                else cb 'Unrecognized config input'

        , (cb) ->
            for key, value of config
                if encodeURIComponent(key) isnt key
                    return cb "App id `#{key}` is not a valid name and cannot be used, use encodeURIComponent() to check"

            cb null
        
        ], cb

    # Make sure we are clean.
    (cb) ->
        fs.remove dir + '/tmp', cb

    # Create the build folders for the apps.
    (cb) ->
        async.eachSeries [ dir + '/tmp/sources', dir + '/tmp/build' ], fs.mkdirs, cb

    # Fetch all of the apps sources.
    (cb) ->
        # Jobs to run loading all the apps sources.
        jobs = [] ; folder = 0

        process = (path, folder) ->
            (cb) ->
                async.waterfall [ (cb) ->
                    # What kind of a job is this?
                    if path.indexOf('git://') is 0
                        # Download a Git repo off the net.
                        command = "cd #{dir}/tmp/sources && git clone --depth 1 #{path} #{folder}"
                    
                    else if path.indexOf('file://') is 0
                        # Remove the file:// prefix.
                        path = path.replace 'file://', ''
                        # Copy a local path.
                        command = "cd #{dir}/tmp/sources && cp -R #{path} #{folder}"
                    
                    else
                        return cb 'Unrecognized path'

                    # Execute the command.
                    exec command, (err, stdout, stderr) ->
                        # Return the formed path.
                        cb err, "#{dir}/tmp/sources/#{folder}"

                # Read the folder.
                (path, cb) ->
                    fs.readdir path, (err, files) ->
                        return cb err if err

                        # Filter to get only folders (that are not hidden).
                        async.filter files, (one, cb) ->
                            return cb false if one[0] is '.' # starts with a dot?
                            return cb false if encodeURIComponent(one) isnt one # badly named?
                            fs.stat path + '/' + one, (err, stats) ->
                                return cb false if err # oh damned
                                cb stats.isDirectory()

                        , (results) ->
                            # Prepend the folder with the path to it.
                            cb null, ( path + '/' + folder for folder in results )

                # Validate & build.
                (paths, cb) ->
                    # Build them in series so we can debug which is which.
                    async.eachSeries paths, (path, cb) ->
                        # Read the config file maybe?
                        try
                            data = require(path + '/' + 'config.js')
                        catch err
                            return cb err

                        # What is the id of the app again?
                        id = path.split('/').pop()

                        # Extend our config with this one.
                        config[id] ?= {} # init?
                        config[id] = _.extend config[id], data

                        # Build it... and they will come.
                        builder.app path, null, null, (err, js) ->
                            return cb err if err

                            path = [ dir, 'tmp/build', id + '.js' ].join('/')
                            fs.writeFile path, js, cb
                    , cb

                ], cb

        return cb '`apps` is not an Array of paths' unless apps and apps instanceof Array
        for path in apps
            return cb '`apps` is an Array of Strings only' if typeof path isnt 'string'
            jobs.push process path, folder++

        # Run them jobs.
        async.parallel jobs, cb
    
    ], (err) ->
        # Trouble?
        throw err if err

        ready = yes
        log.inf 'Ready'

        # Init new Director.js router.
        router = new director.http.Router routes(config)

    # Make our dispatcher part of connect.
    (req, res, next) ->
        # Just skip if we do not exist yet.
        return next() unless router
        # Use our router now.
        router.dispatch req, res, (err) ->
            next() if err
