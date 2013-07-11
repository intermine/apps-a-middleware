// Define require here so we can use it in our callback.
var require;

(function() {
    // Require (Common.js) implementation.
    var modules = {};
    var cache = {};

    var has = function(object, name) {
        return Object.hasOwnProperty.call(object, name);
    };

    require = function(name) {
        var initModule = function(name, definition) {
            var localRequire = function(path) {
                return function(name) {
                    var dirname = function(path) {
                        return path.split('/').slice(0, -1).join('/');
                    };

                    var dir = dirname(path);
                    var absolute = expand(dir, name);
                    return require(absolute);
                };
            };

            var module = { id: name, exports: {} };
            definition(module.exports, localRequire(name), module);
            var exports = cache[name] = module.exports;
            return exports;
        };

        var expand = function(root, name) {
            var results = [], parts, part;
            if (/^\.\.?(\/|$)/.test(name)) {
                parts = [root, name].join('/').split('/');
            } else {
                parts = name.split('/');
            }
            for (var i = 0, length = parts.length; i < length; i++) {
                part = parts[i];
                if (part === '..') {
                    results.pop();
                } else if (part !== '.' && part !== '') {
                    results.push(part);
                }
            }
            return results.join('/');
        };

        var path = expand(name, '.');

        if (has(cache, path)) return cache[path];
        if (has(modules, path)) return initModule(path, modules[path]);

        var dirIndex = expand(path, './index');
        if (has(cache, dirIndex)) return cache[dirIndex];
        if (has(modules, dirIndex)) return initModule(dirIndex, modules[dirIndex]);

        throw new Error('Cannot find module "' + name + '"');
    };

    var define = function(bundle, fn) {
        if (typeof bundle === 'object') {
            for (var key in bundle) {
                if (has(bundle, key)) {
                    modules[key] = bundle[key];
                }
            }
        } else {
            modules[bundle] = fn;
        }
    };

    // All our modules belong to us.
    (function() {
        <%- @modules.join('\n') %>
    })();

})();
