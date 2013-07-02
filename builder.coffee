#!/usr/bin/env coffee
async     = require 'async'
winston   = require 'winston'
{ exec }  = require 'child_process'
{ _ }     = require 'lodash'
fs        = _.extend require('fs-extra'), require('fs')

# Templating.
eco       = require 'eco'
hogan     = require 'hogan.js'

# Logic.
cs        = require 'coffee-script'
uglify    = require 'uglify-js'

# Style.
stylus    = require 'stylus'
cleanCss  = require 'clean-css'
prefix    = require 'prefix-css-node'

winston.cli()

# We are here.
dir = __dirname

###
Precompile a single app.
@param {string} path A URL-valid appId.
@param {string} callback A string used to tell client that THIS app has arrived.
@param {dict} config Configuration to be injected into the app.
@param {fn} cb Expects two parameters, 1. error string 2. JS string with the precompiled app.
###
exports.app = (path, callback, config, cb) ->
    winston.info 'Precompiling ' + path.bold

    # Use the placeholders?
    config = config or
        'title':       '#@+TITLE'
        'author':      '#@+AUTHOR'
        'description': '#@+DESCRIPTION'
        'version':     '#@+VERSION'
        'config':      '#@+CONFIG'
        'classExpr':   '#@+CLASSEXPR'
    callback = callback or '#@+CALLBACK'

    # Does the dir actually exist?
    async.waterfall [ (cb) ->
        fs.stat path, cb

    # Read all the files in the directory and categorize them.
    (stats, cb) ->
        return cb '#Is not a directory' unless stats.isDirectory()

        fs.readdir path, (err, list) ->
            return cb err if err

            winston.data 'Reading source files'

            # Check each entry.
            check = (entry) ->
                (cb) ->
                    fs.stat path + '/' + entry, (err, stats) ->
                        return cb err if err or not stats
                        cb null, entry

            # Check them all at once.
            async.parallel ( check entry for entry in list ), (err, files) ->
                return cb err if err

                # Patterns for matching types.
                patterns = [ /^presenter\.(coffee|js|ls|ts)$/, /^style\.(styl|css)$/, /\.(eco|hogan)$/ ]

                # Which is it?
                results = []
                for file in files then do (file) ->
                    for i, pattern of patterns
                        if file.match pattern
                            results[i] ?= []
                            return results[i].push file

                cb null, results

    # Compile the files.
    ([ presenter, style, templates ], cb) ->
        # Handle the presenter.
        async.parallel [ (cb) ->
            return cb 'Presenter either not provided or provided more than once' if not presenter or presenter.length isnt 1

            winston.data 'Processing presenter'

            fs.readFile path + '/' + (file = presenter[0]), 'utf-8', (err, src) ->
                return cb err if err

                # Which filetype?
                switch file.split('.').pop()
                    # A JavaScript presenter.
                    when 'js'
                        cb null, [ 'presenter', src ]
                    
                    # A CoffeeScript presenter needs to be bare-ly compiled first.
                    when 'coffee'
                        try
                            js = cs.compile src, 'bare': 'on'
                            cb null, [ 'presenter', js ]
                        catch err
                            cb err

                    # LiveScript then.
                    when 'ls'
                        exec "#{dir}/node_modules/.bin/lsc -bpc < #{path}/#{file}", (err, stdout, stderr) ->
                            return cb (''+err).replace('\n', '') if err
                            return cb stderr if stderr
                            cb null, [ 'presenter', stdout ]

                    # Use the latest vanilla TypeScript compiler available.
                    when 'ts'
                        exec "#{dir}/node_modules/.bin/tsc #{path}/#{file} --target ES5", (err, stdout, stderr) ->
                            return cb err if err
                            return cb stderr if stderr
                            # Need to read it now.
                            fs.readFile path + '/' + file.replace('.ts', '.js'), 'utf-8', (err, data) ->
                                return cb err if err
                                cb null, [ 'presenter', data ]

        # The stylesheet.
        (cb) ->
            return cb null, [ 'style', null ] unless style
            return cb 'Only one stylesheet has to be defined' if style.length isnt 1

            winston.data 'Processing stylesheet'

            fs.readFile path + '/' + (file = style[0]), 'utf-8', (err, src) ->
                return cb err if err

                pack = (css) ->
                    # Prefix CSS selectors with a callback id.
                    css = prefix.css css, "div#a#{callback}"
                    # Escape all single quotes, minify & return.
                    css = cleanCss.process css.replace /\'/g, "\\'"
                    cb null, [ 'style', css ]

                # Which filetype?
                switch file.split('.').pop()
                    # A CSS file.
                    when 'css'
                        pack src
                    
                    # A Stylus file.
                    when 'styl'
                        stylus.render src, (err, css) ->
                            return cb err if err
                            pack css

        # Them templates.
        (cb) ->
            return cb null, [ 'templates', null ] unless templates

            winston.data 'Processing templates'

            process = (file) ->
                (cb) ->
                    # Read the file.
                    fs.readFile path + '/' + file, 'utf-8', (err, src) ->
                        return cb err if err

                        # Get the name and suffix.
                        [ name, suffix ] = file.split('.')

                        # Which filetype?
                        switch suffix
                            # Eco.
                            when 'eco'
                                template = eco.precompile src
                                # Minify.
                                cb null, (uglify.minify(("templates['#{name}'] = #{template}") + ';', 'fromString': yes)).code

                            # Mustache through Hogan.
                            when 'hogan'
                                # Make into a string.
                                template = hogan.compile src, { asString: yes }
                                # Already minified.
                                cb null, "templates['#{name}'] = #{template};"

            # Process all templates in parallel.
            async.parallel ( process file for file in templates  ), (err, results) ->
                return cb err if err
                cb null, [ 'templates', results ]

        ], (err, results) ->
            return cb err if err
            
            # Expand the data on us.
            ( @[key] = value for [ key, value ] in results )

            js = []

            # The signature.
            js.push """
                /**
                 *      _/_/_/  _/      _/   
                 *       _/    _/_/  _/_/     App/A
                 *      _/    _/  _/  _/      (C) 2013 InterMine, University of Cambridge.
                 *     _/    _/      _/       http://intermine.org
                 *  _/_/_/  _/      _/
                 *
                 *  Name: #{config.title}
                 *  Author: #{config.author}
                 *  Description: #{config.description}
                 *  Version: #{config.version}
                 *  Generated: #{(new Date()).toUTCString()}
                 */
                (function() {
                  var root = this; // reference to the root

                  /**#@+ the presenter */\n
                """

            # The presenter.
            js.push ("  #{line}" for line in @presenter.split('\n') ).join('\n')

            # Tack on any config.
            winston.data 'Appending config'
            cfg = JSON.stringify(config.config) or '{}'
            # Leave out the quotes around the config (from stringify...).
            if cfg[0] is '"' and cfg[cfg.length - 1] is '"' then cfg = cfg[1...-1]
            js.push "  /**#@+ the config */\n  var config = #{cfg};\n"

            # Add on the templates.
            if @templates and @templates.length isnt 0
                tml = [ "  /**#@+ the templates */\n  var templates = {};" ]
                js.push (tml.concat ( "  #{line}" for line in @templates )).join '\n'

            # Embed the stylesheet.
            if @style
                js.push """
                    \n  /**#@+ css */
                      var style = document.createElement('style');
                      style.type = 'text/css';
                      style.innerHTML = '#{@style}';
                      document.head.appendChild(style);
                    """

            # How are we loading the app? Default to an `App` class.
            appFn = config.classExpr or 'App'

            # Finally add us to the browser `cache` under the callback id.
            js.push """
                \n  /**#@+ callback */
                  (function() {
                    var parent, part, _i, _len, _ref;
                    parent = this;
                    _ref = 'intermine.temp.apps'.split('.');
                    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
                      part = _ref[_i];
                      parent = parent[part] = parent[part] || {};
                    }
                  }).call(root);
                  // Client will be getting these properties from us so we can be instantiated and rendered.
                  root.intermine.temp.apps['#{callback}'] = [ #{appFn}, config, templates ];
                \n\n}).call(this);
                """

            cb null, js.join '\n'

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
        winston.error (''+err) if err
        cb()