<% clean = (input) => %><%- input.replace(/\.[^/.]+$/, '') %><% end %>

// <%= @path.split('/').pop() %>
define('<%- clean @path %>', function(exports, require) {
<%- @script %>
});
