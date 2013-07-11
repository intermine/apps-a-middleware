#!/usr/bin/env coffee
fs    = require 'fs'
async = require 'async'
hogan = require 'hogan.js'

module.exports = (path, file, cb) ->
    async.waterfall [ (cb) ->
        fs.readFile path + '/' + file, 'utf8', cb

    (src, cb) ->
        try
            template = hogan.compile src, { asString: yes }
            return cb null, template
        catch err
            return cb err
    
    ], cb