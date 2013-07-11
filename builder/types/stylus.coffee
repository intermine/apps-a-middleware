#!/usr/bin/env coffee
fs     = require 'fs'
async  = require 'async'
stylus = require 'stylus'

module.exports = (path, file, cb) ->
    async.waterfall [ (cb) ->
        fs.readFile path + '/' + file, 'utf8', cb

    (src, cb) ->
        stylus.render src, cb
    
    ], cb