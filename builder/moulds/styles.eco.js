/**#@+ css */
<% for style in @styles: %>
var style = document.createElement('style');
style.type = 'text/css';
style.innerHTML = '<%- style %>';
document.head.appendChild(style);
<% end %>