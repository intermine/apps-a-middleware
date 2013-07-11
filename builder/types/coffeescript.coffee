#!/usr/bin/env coffee
fs = require 'fs'
cs = require 'coffee-script'

module.exports = (path, file, cb) ->
    fs.readFile path + '/' + file, 'utf8', (err, src) ->
        try
            js = cs.compile src, 'bare': 'on'
            cb null, js
        catch err
            cb err