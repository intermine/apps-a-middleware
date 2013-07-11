#!/usr/bin/env coffee
fs    = require 'fs'
async = require 'async'
eco   = require 'eco'

module.exports = (path, file, cb) ->
    async.waterfall [ (cb) ->
        fs.readFile path + '/' + file, 'utf8', cb

    (src, cb) ->
        try
            template = eco.precompile src
            return cb null, template
        catch err
            return cb err
    
    ], cb