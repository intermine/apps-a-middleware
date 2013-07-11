#!/usr/bin/env coffee
root = this

# Can we work?
throw 'An old & unsupported browser detected' unless document.querySelector

class AppsClient

    # Save the root URL of the app config
    constructor: (server) ->
        # Strip trailing slash?
        @server = server.replace /\/+$/, ''
        
        # Generate a callback.
        callback = 'appcall' + +new Date

        # A callback setting the config on us..
        root[callback] = (@config) =>

        # Load it.
        root.intermine.load [
            'path': "#{@server}/middleware/apps/a?callback=#{callback}"
            'type': 'js'
        ]
    
    # Load one app.
    #
    # 1. `appId`: id of the app as specified in its config
    # 2. `target`:   element the app will render into
    # 3. `options`:  local options to pass to us, will get merged with @config
    load: (appId, target, options = {}) =>
        # Keep checking if we have the config loaded.
        again = => @load appId, target, options
        if not @config then return _setImmediate again

        # Post dependencies loaded.
        run = (err) =>
            # Any loading problems?
            throw new Error(err) if err

            # Generate callback id.
            id = _id()

            # Get the compiled script.
            root.intermine.load [
                'path': "#{@server}/middleware/apps/a/#{appId}?callback=#{id}"
                'type': 'js'
            ], (err) =>
                # Create a wrapper for the target.
                div = document.createElement 'div'
                div.setAttribute 'class', "-im-apps-a #{appId}"
                div.setAttribute 'id', 'a' + id

                # Append it to the target, IE8+.
                document.querySelector(target).appendChild div
                
                # Do we have the temp directory to save apps under?
                throw new Error('`intermine.temp` object cache does not exist') unless root.intermine.temp

                # Get the app from there.
                throw new Error("Unknown app `#{id}`") unless app = root.intermine.temp.apps[id]

                # Get the instantiation fn, server config and templates from the app.
                [ module, config, templates ] = app
                
                # Do we have an App over here?
                throw new Error('Root module is not exporting App') unless module.App

                # Merge server and client config.
                config = _extend config, options

                # Create a new instance passing merged config and templates.
                instance = new module.App config, templates

                # Did we create anything?
                throw new Error('App failed to instantiate') unless instance and typeof instance is 'object'

                # Do we implement render function?
                throw new Error('App does not implement `render` function') unless instance.render and typeof instance.render is 'function'

                # Render.
                instance.render "#a#{id}.-im-apps-a"

        # Load dependencies?
        deps = @config[appId]

        if deps? then root.intermine.load deps, run
        else run()

# Do we have the InterMine API Loader?
if not root.intermine
    throw new Error 'You need to include the InterMine API Loader first!'
else
    # Expose class globally?
    root.intermine.appsA = root.intermine.appsA or AppsClient

# Namespace?
root.intermine.temp ?= {}
root.intermine.temp.apps ?= {}