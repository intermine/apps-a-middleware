# This is my widget definition
class Widget

    # Have access to config and templates compiled in.
    constructor: (@config, @templates) ->

    # Render simply returns a string to be returned to the target.
    render: (target) ->
        $(target).html @templates.layout
            'rows': [
                    'title':  'ßibli'
                    'author': 'Jeebus'
                ,
                    'title':  'Book of Spaghetti'
                    'author': 'His holiness Ramen'
            ]