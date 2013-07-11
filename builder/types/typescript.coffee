#!/usr/bin/env coffee
path     = require 'path'
fs       = require 'fs'
async    = require 'async'
{ exec } = require 'child_process'

root = path.resolve __dirname + '/../../'

module.exports = (path, file, cb) ->
    # Generate unique id for our output file.
    out = file[0...-3] + '.js'

    # Execute `tsc` command.
    async.waterfall [ (cb) ->
        exec "#{root}/node_modules/.bin/tsc #{path}/#{file} --target ES5 --module commonjs", (err, stdout, stderr) ->
            return cb err if err
            return cb stderr if stderr
            cb null

    # Need to read it now.
    (cb) ->
        fs.readFile path + '/' + out, 'utf8', cb

    # Remove the generated file.
    (js, cb) ->
        fs.unlink path + '/' + out, (err) ->
            return cb err if err
            cb null, js

    ], cb