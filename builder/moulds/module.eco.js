<% clean = (input) => %><%- input.replace(/\.[^/.]+$/, '') %><% end %>

// <%= @path.split('/').pop() %>
require.register('<%- clean @path %>', function(exports, require) {
<%- @script %>
});
