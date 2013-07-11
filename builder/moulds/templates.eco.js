/**#@+ the templates */
var templates = {};
<% for tml in @templates: %>
templates['<%= tml[0] %>'] = <%- tml[1] %>;
<% end %>
