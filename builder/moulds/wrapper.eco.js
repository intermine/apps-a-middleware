<% clean = (input) => %><%- input.replace(/\n\s*\n/g, '\n') %><% end %>
/**
 *      _/_/_/  _/      _/   
 *       _/    _/_/  _/_/     App/A
 *      _/    _/  _/  _/      (C) 2013 InterMine, University of Cambridge.
 *     _/    _/      _/       http://intermine.org
 *  _/_/_/  _/      _/
 *
 *  Name: <%= @config.title %>
 *  Author: <%= @config.author %>
 *  Description: <%= @config.description %>
 *  Version: <%= @config.version %>
 *  Generated: <%= (new Date()).toUTCString() %>
 */
(function() {
    /**#@+ the app */
    <%- clean @content %>
    // Expose the app for what it is.
    intermine.temp.apps['<%= @callback %>'] = [ require('<%= @config.appRoot %>'), config, templates ];
})();