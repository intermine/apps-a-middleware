#!/usr/bin/env coffee
fs = require 'fs'

module.exports = (path, file, cb) ->
    fs.readFile path + '/' + file, 'utf8', cb