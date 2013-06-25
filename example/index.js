#!/usr/bin/env node
var app, connect, http, middleware, builder;

require('coffee-script');
http = require('http');
connect = require('connect');
middleware = require('../middleware.coffee');
builder = require('../builder.coffee');

// Do the client first.
builder.client(function() {
    // Setup the Connect middleware.
    app = connect().use(middleware({
        'apps': ['git://github.com/intermine/intermine-apps-a.git'],
        //'apps': ['file:///home/radek/dev/intermine-apps-a/'],
        //'config': __dirname + '/config.json'
        'config': {}
    })).use(connect["static"](__dirname + '/public'));

    // Serve.
    http.createServer(app).listen(process.env.PORT);
});