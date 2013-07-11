#!/usr/bin/env coffee
path     = require 'path'
{ exec } = require 'child_process'

root = path.resolve __dirname + '/../../'

module.exports = (path, file, cb) ->
    # Execute `lsc` command.
    exec "#{root}/node_modules/.bin/lsc -bpc < #{path}/#{file}", (err, stdout, stderr) ->
        return cb err if err
        return cb stderr if stderr
        cb null, stdout