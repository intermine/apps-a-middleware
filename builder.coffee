#!/usr/bin/env coffee
log       = require 'node-logging'
async     = require 'async'
{ exec }  = require 'child_process'
{ _ }     = require 'lodash'
fs        = _.extend require('fs-extra'), require('fs')
wrench    = require 'wrench'
cs        = require 'coffee-script'
eco       = require 'eco'
uglify    = require 'uglify-js'
cleanCss  = require 'clean-css'
prefix    = require('prefix-css-node').css

rules     = require './builder/rules.coffee'

# We are here.
dir = __dirname

# Are we ready? Usually we will...
callbacks = []
whenReady = (callback) -> if ready then callback() else callbacks.push callback

# Here be our moulds loaded.
moulds = {} ; ready = no
async.waterfall [ (cb) ->
    fs.readdir dir + '/builder/moulds', cb

, (files, cb) ->
    async.each files, (file, cb) ->
        fs.readFile dir + '/builder/moulds/' + file, 'utf8', (err, data) ->
            return cb err if err
            moulds[file.split('.')[0]] = data
            cb null
    , cb

], (err) ->
    log.bad err if err
    return process.exit(1) if err
    ready = yes
    # Call any queued callbacks.
    ( callback() for callback in callbacks )

###
Precompile a single app.
@param {string} path A URL-valid appId.
@param {string} callback A string used to tell client that THIS app has arrived.
@param {dict} config Configuration to be injected into the app.
@param {fn} cb Expects two parameters, 1. error string 2. JS string with the precompiled app.
###
exports.app = (path, callback, config, cb) ->
    # Use the placeholders?
    config = config or
        'title':       '#@+TITLE'
        'author':      '#@+AUTHOR'
        'description': '#@+DESCRIPTION'
        'version':     '#@+VERSION'
        'config':      '#@+CONFIG'
        'appRoot':     '#@+APPROOT'
    config.config ?= {}
    config.appRoot ?= 'presenter' # `/presenter.ts` etc.
    callback = callback or '#@+CALLBACK'

    # Does the dir actually exist?
    async.waterfall [ (cb) ->
        fs.stat path, cb

    # Read all the files in the directory and categorize them.
    (stats, cb) ->
        return cb 'Is not a directory' unless stats.isDirectory()

        # Deal with each file in parallel.
        async.map wrench.readdirSyncRecursive(path)
        , _.partial(rules, path)
        , (err=null, results=null) ->
            processed = { module: [], style: [], template: [] }
            # Trouble?
            return cb err if err
            # Save it?
            for entry in results
                [ type, path, output ] = entry
                continue if not type
                # Add it.
                processed[type].push [ path, output ]
            
            # Exit?
            cb null, processed

    # Continue when ready.
    (processed, cb) ->
        whenReady _.partial cb, null, processed

    # Put it all together.
    (p, cb) ->
        js = []

        # The app classes.
        js.push eco.render moulds.require,
            'modules': p.module.map (entry) ->
                [ path, output ] = entry
                # Wrap each entry into a module loader/exporter.
                return eco.render moulds.lines,
                    'spaces': 8
                    'lines': eco.render moulds.module,
                        'script': eco.render moulds.lines,
                            'spaces': 4
                            'lines': output
                        'path': path

        # Add on the templates.
        js.push eco.render moulds.templates, { 'templates': p.template }

        # Embed the stylesheets.
        if !!p.style.length            
            js.push eco.render moulds.styles,
                'styles': p.style.map (entry) ->
                    [ path, output ] = entry
                    # Prefix CSS selectors with our callback id.
                    css = prefix output, "div#a#{callback}"
                    # Escape all single quotes, minify & return.
                    return cleanCss.process css.replace /\'/g, "\\'"

        # Tack on any config.
        cfg = JSON.stringify config.config
        # Leave out the quotes around the config (from stringify...).
        if cfg[0] is '"' and cfg[cfg.length - 1] is '"' then cfg = cfg[1...-1]

        js.push eco.render moulds.config, { 'config': cfg }

        # Wrap it.
        cb null, eco.render moulds.wrapper,
            'callback': callback
            'config': config
            'content': eco.render moulds.lines,
                'spaces': 4
                'lines': js.join('\n')

    ], cb

# Compile the client. Done when running the example.
exports.client = (cb = ->) ->
    async.waterfall [ (cb) ->
        compile = (f) ->
            (cb) ->
                # Remember to use absolute paths.
                fs.readFile dir + f, 'utf-8', (err, data) ->
                    return cb err if err
                    cb null, [ f, data ]

        # Run checks in parallel.
        async.parallel ( compile f for f in [ '/client/client.coffee', '/client/client.deps.coffee' ] ), (err, results) ->
            return cb err if err

            # Swap?
            [ a, b ] = results
            ( a[0] is '/client/client.coffee' and [ b, a ] = [ a, b ] )

            # Add paths and join.
            merged = [ a[1], b[1] ].join('\n')

            # Compile please, with closure.
            try
                js = cs.compile merged
            catch err
                return cb err

            # Merge the files into one and wrap in closure.
            cb null, js

    # Write it.
    , (js, cb) ->
        process = (path, compress=no) ->
            (cb) ->
                # Compress?
                try
                    data = if compress then (uglify.minify(js, 'fromString': yes)).code else js
                catch err
                    return cb err

                # Actually write, prefix with absolute path.
                fs.outputFile dir + path, data, cb

        async.parallel [
            process('/example/public/js/intermine.apps-a.js')
            process('/example/public/js/intermine.apps-a.min.js', yes)
        ], cb

    ], (err) ->
        log.bad err if err
        process.exit(1) if err
        cb null