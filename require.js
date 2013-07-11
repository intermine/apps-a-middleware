(function(root) {

    var modules = {};
    var callbacks = {};

    // An array of elements in `a` that are not in `b`.
    var difference = function(a, b) {
        var out = [];
        a.forEach(function(el) {
            if (b.indexOf(el) < 0) {
                out.push(el);
            }
        });
        return out;
    };

    // Checking if an object has a given property directly on itself (in other words, not on a prototype).
    var has = function(obj, key) {
        return Object.prototype.hasOwnProperty.call(obj, key);
    };

    // Rename a module name (case insensitivity).
    var rename = function(name) {
        return name.toLowerCase();
    };

    // Callback once all modules are resolved.
    var once = function(modules, cb) {
        console.log('waiting for', modules);

        // Goes down when one of my modules is resolved.
        var i = modules.length,
            exited = false;
        var me = function() {
            i -= 1;
            // All done? Call back then.
            if (!i && !exited) {
                exited = true;
                cb();
            };
        }

        // For each module, listen for it being loaded.
        modules.forEach(function(module) {
            // Does this callback exist already?
            if (has(callbacks, module)) {
                // Add me to the queue.
                callbacks[module].push(me);
            } else {
                // Ok init the stack.
                callbacks[module] = [ me ];
            }
        });
    };

    // These require calls are done once we have resolved everything.
    var require = function(name) {
        // Capitalize.
        name = name[0].toUpperCase() + name.slice(1);
        
        console.log('require', name);

        // Are we present in modules? Saved under their real name...
        if (has(modules, name)) return modules[name];

        throw 'Cannot find module `' + name + '`';
    };

    // Anonymous modules support.
    var define = function(bundle, fn) {
        // The leading args to the function.
        var args = [ require, modules ];

        // Load a module once all its deps are solved and return new exported modules.
        var load = function() {
            // What did you have?
            var before = Object.keys(modules).map(rename);
            // Run this module.
            fn.apply(this, args); // `this` is not important
            // What do you have now?
            var after = Object.keys(modules).map(rename);
            // Anything new?
            difference(after, before).forEach(function(module) {
                console.log('loaded', module);
                // Call any callbacks if they were waiting for me.
                if (has(callbacks, module)) {
                    callbacks[module].forEach(function(fn) {
                        fn();
                    })
                }
            });
        };

        // These are our dependencies?
        var deps;
        if (!!(deps = bundle.slice(2)).length) {
            // Once all of these deps are resolved, load myself.
            once(deps, function() {
                console.log('deps met');
                // Convert deps into actual modules as already loaded and add them to args.
                args = args.concat(deps.map(function(name) {
                    return require(name);
                }));
                // Now load this module.
                load();
            });
        } else {
            // Load immediately.
            load();
        }
    };

    // Expose.
    root.require = require;
    root.define = define;

})(this);