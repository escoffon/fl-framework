const _ = require('lodash');

/**
 * @ngdoc module
 * @name fl.object_system
 * @module fl
 * @description
 *  The Fl object system manages class definitions and object instantiation.
 */

/**
 * @ngdoc module
 * @name FlExtensions
 * @module fl.object_system
 * @description
 * Namespace for class extension functionality.
 * A class extension is an object that contains information about how to extend the functionality of
 * another object (typically, a class).
 * 
 * An extension has up to four components:
 * - *instance_methods* are functions to be installed in the object's prototype, if one is present.
 * - *class_methods* are functions to be installed in the object itself.
 * - *methods* acts as an alias for *instance_methods*, and also is used to provide dynamic method
 *   definitions, as described in {@sref FlExtensions.register}.
 * - the *initializer* is a function called during object construction, and used to initialize
 *   properties related to the extension.
 *
 * All properties are optional, although an extension that defines none is obviously not very useful.
 * 
 * The *methods* component can be implemented as either an object (hash), or as a function; the extension
 * utilities install it differently, depending on its type; see {@sref FlExtensions.register}.
 * The *class_methods* and *instance_methods* components are always objects.
 *
 * For example, this extension defines a method `_append` that appends two values to a common prefix,
 * and an initializer that load the value of the prefix in the `_$scope` property.
 * (It assumes that `this` has defined a `_$cope` property.)
 * ```
 *    let MyExtension = FlExtensions.named('MyExtension', {
 *      methods: {
 *        _append: function(one, two) {
 *          returns this._$scope._prefix + one + ':' + two;
 *        }
 *      },
 *      initializer: function(pass) {
 *        if (pass == 'post')
 *        {
 *          this._$scope._prefix = 'my prefix: ';
 *        }
 *      }
 *    });
 * ```
 */

let FlExtensions = { };

FlExtensions._named_registry = { };
FlExtensions.AlreadyRegistered = function AlreadyRegistered(message) {
    this.message = message;
    this.name = 'AlreadyRegistered';
};
FlExtensions.AlreadyRegistered.prototype.constructor = FlExtensions.AlreadyRegistered;

FlExtensions.NotRegistered = function NotRegistered(message) {
    this.message = message;
    this.name = 'NotRegistered';
};
FlExtensions.NotRegistered.prototype.constructor = FlExtensions.NotRegistered;

/**
 * @ngdoc function
 * @name FlExtensions.named
 * @module fl.object_system.FlExtensions
 * @description
 * Create a named extension, which clients can then find by name.
 * 
 * @param {string} name The extension name.
 * @param {object} ext The extension.
 * @param {boolean} overwrite If `true` and an extension by this name is already registered, overwrite
 *  the current value. Otherwise, throw an exception.
 * 
 * @return {object} Returns _ext_.
 * 
 * @throws Throws an exception if _name_ is already registered.
 */

FlExtensions.named = function(name, ext, overwrite) {
    let xo = FlExtensions._named_registry[name];
    if (_.isObject(xo))
    {
	if (overwrite === true)
	{
	    xo.extension = ext;
	}
	else
	{
	    throw new FlExtensions.AlreadyRegistered('extension :' + name + ' is already registered');
	}
    }
    else
    {
	FlExtensions._named_registry[name] = { name: name, extension: ext };
    }

    return ext;
};

/**
 * @ngdoc function
 * @name FlExtensions.list
 * @module fl.object_system.FlExtensions
 * @description
 * List the registered extensions.
 * 
 * @param {boolean} full If `true`, the element in the returned array are objects containing two
 *  property: *name* is the extension name, and *extension* the extension object. Otherwise,
 *  the returned array contains just the registered names for the extensions.
 *
 * @return {array} Returns an array containing all registered extensions.
 */

FlExtensions.list = function(full) {
    let xf = (full === true) ? true : false;
    
    return _.reduce(FlExtensions._named_registry, function(acc, ev, ek) {
	acc.push((xf) ? ev : ek);
	return acc;
    }, [ ]);
};

/**
 * @ngdoc function
 * @name FlExtensions.lookup
 * @module fl.object_system.FlExtensions
 * @description
 * Look up a named extension.
 * 
 * @param {string|object} name The extension name or descriptor.
 *  If the value is an object, it must contain one of the properties **methods** or **initializer**,
 *  or both, and **methods** must be an object or a function and **initializer** a function.
 *  In this case, the method returns _name_.
 * @param {boolean} raise Controls the behavior on a lookup failure.
 * 
 * @return {object} Returns the extension. If _name_ is not the name of a registered extension, it
 *  returns `undefined` if _raise_ is `false`, and throws an exception if _raise_ is `true`.
 * 
 * @throws Throws an exception if _name_ is not registered.
 */

FlExtensions.lookup = function(name, raise) {
    if (_.isObject(name))
    {
	if (!(_.isObject(name.methods) || _.isFunction(name.methods)) && !_.isFunction(name.initializer))
	{
	    throw new FlExtensions.NotRegistered('lookup of extension by object must include either :methods or :initializer');
	}
	
	return name;
    }
    else
    {
	if (FlExtensions._named_registry[name]) return FlExtensions._named_registry[name].extension;
    }
    
    if (raise === false) return undefined;

    throw new FlExtensions.NotRegistered('extension :' + name + ' is not registered');
};

/**
 * @ngdoc function
 * @name FlExtensions.register
 * @module fl.object_system.FlExtensions
 * @description
 * Register the method component of an extension with an object.
 * 
 * If _ex_**.class_methods** is present, the function iterates over all properties defined in
 * _ex_**.class_methods**, and assigns their value to a property by the same name in _obj_.
 * 
 * If _ex_**.instance_methods** is present, the function iterates over all properties defined in
 * _ex_**.instance_methods**, and assigns their value to a property by the same name in _obj_'s prototpye
 * (if one is defined).
 * 
 * If _ex_**.methods** is an object, it behaves as for the _ex_.**instance_methods** property; in other
 * it acts as an alias for _ex_.**instance_methods**.
 * 
 * If _ex_**.methods** is a function, it calls it using _obj_ as the **this** for the call; the assumption is
 * that the extension function then proceeds to define properties in _obj_ as needed. This makes it possible
 * to set methods in _obj_ dynamically.
 * 
 * @param {Object|String} ex The extension to add to _obj_; if passed as a string, the value is looked up
 *  in the extension registry.
 * @param {Object} obj The object to extend with the contents of _ex_**.methods**.
 *
 * @return {Object} Returns _obj_.
 */

FlExtensions.register = function(ex, obj) {
    ex = FlExtensions.lookup(ex, false);

    if (!_.isNil(obj) && !_.isNil(ex))
    {
	let proto = obj.prototype;

	if (_.isObject(ex.class_methods))
	{
	    _.forEach(ex.class_methods, function(mv, mk) {
		obj[mk] = mv;
	    });
	}

	if (_.isObject(ex.instance_methods) && !_.isUndefined(proto))
	{
	    _.forEach(ex.instance_methods, function(mv, mk) {
		proto[mk] = mv;
	    });
	}
	
	if (_.isFunction(ex.methods))
	{
	    ex.methods.call(obj);
	}
	else if (_.isObject(ex.methods) && !_.isUndefined(proto))
	{
	    _.forEach(ex.methods, function(mv, mk) {
		proto[mk] = mv;
	    });
	}
    }

    return obj;
};

/**
 * @ngdoc function
 * @name FlExtensions.initialize
 * @module fl.object_system.FlExtensions
 * @description
 * Call the extension initializer on an object.
 * 
 * If _ex_**.initializer** is a function, it calls it using _obj_ as the **this** for the call; the assumption
 * is that the extension function then proceeds to define properties in _obj_ as needed.
 * 
 * @param {Object} ex The extension to initialize in _obj_; if passed as a string, the value is looked up
 *  in the extension registry.
 * @param {Object} obj The object to extend by _ex_**.initializer**; this is typically an object or a function.
 * @param {String} pass The initialization pass:
 *  - **pre** The initializer is being called before the object state is constructed: this is used to set up
 *    state that the object's initializer may need.
 *  - **post** The initializer is being called after the object state is constructed.
 *  The value of _pass_ is passed to the initializer.
 *
 * @return {Object} Returns _obj_.
 */

FlExtensions.initialize = function(ex, obj, pass) {
    ex = FlExtensions.lookup(ex, false);
    if (!_.isNil(obj) && !_.isNil(ex) && _.isFunction(ex.initializer))
    {
	ex.initializer.call(obj, pass);
    }

    return obj;
};

/**
 * @ngdoc type
 * @name FlRoot
 * @module fl.object_system
 * @description
 * The root class for all Fl classes.
 * This is the root of the Fl class hierarchy; {@sref FlClassManager.make_class} uses it as the superclass if
 * one is not defined in the options.
 * 
 * @class FlRoot
 */

const FlRoot = function FlRoot() {
    this.prototype.__init.call(this);
};

FlRoot.prototype = Object.create({ });
FlRoot.__name = 'FlRoot';
FlRoot.__superclass = null;
FlRoot.prototype.__class = FlRoot;
FlRoot.prototype.__superclass = null;
FlRoot.prototype.constructor = FlRoot;

/**
 * @ngdoc method
 * @name FlRoot#__init
 * @module fl.object_system
 * @description
 * This is the initializer for the FlRoot class.
 */

FlRoot.prototype.__init = function() {
};
FlRoot.prototype.__init.__name = '__init';

/**
 * @ngdoc method
 * @name FlRoot#__init_extensions
 * @module fl.object_system
 * @description
 * Load the **initializer** component of a set of extensions.
 * If _ext_ is an object, it iterates over all its elements and registers each
 * extension's **initializer** component with **this**, using {@sref FlExtensions.initialize}.
 * This initializes all the listed extension properties in the object.
 * 
 * The class builder {@sref FlClassManager.make_class} automatically generates a call to this method
 * in each class initializer, passing the extensions in the class options' **extensions** property.
 * 
 * @param {Object} ext A hash of extension descriptors; the keys are extension names, and the values the
 *  corresponding descriptors.
 * @param {String} pass The initialization pass; see {@sref FlExtensions.initialize}.
 */

FlRoot.prototype.__init_extensions = function(ext, pass) {
    for (var k in ext)
    {
	FlExtensions.initialize(ext[k], this, pass);
    }
};
FlRoot.prototype.__init_extensions.__name = '__init_extensions';

/**
 * @ngdoc module
 * @name FlClassManager
 * @module fl.object_system
 * @description
 * A service to manage class hierarchies and create class instances.
 */

const FlClassManager = {
    _class_registry: {
	'FlRoot': FlRoot
    }
};

FlClassManager.MissingClass = function MissingClass(message) {
    this.message = message;
    this.name = 'MissingClass';
};
FlClassManager.MissingClass.prototype.constructor = FlClassManager.MissingClass;

FlClassManager.AlreadyDefinedClass = function AlreadyDefinedClass(message) {
    this.message = message;
    this.name = 'AlreadyDefinedClass';
};
FlClassManager.AlreadyDefinedClass.prototype.constructor = FlClassManager.AlreadyDefinedClass;

/**
 * @ngdoc function
 * @name FlClassManager.make_class
 * @module fl.object_system
 * @description
 * Build a class object.
 * The class is built as follows:
 * 1. Define a constructor function with the following behavior:
 *    - If **opts.initializer** is not defined, the initializer defaults to the following function:
 *      `function() { this.__super(); }`. Note that, if an initializer is provided, it should
 *      make a call to `__super` in order to initialize the superclass; in this case,
 *      the argument list for the `__super` method is defined by the initializer code.
 *    - The initializer is wrapped by a function that performs the following steps:
 *      1. Initializes the registered extensions from **opts.extensions**, setting the pass name to `pre`.
 *      2. Calls the initializer from the previous step.
 *      3. Initializes the registered extensions from **opts.extensions**, setting the pass name to `post`.
 *    - The constructor body sets the class name in the **__class_name** property, and then calls the wrapped
 *      initializer, passing the constructor arguments (the call is set up as an `apply` call using `this`
 *      and the constructor's *arguments*). The  initializer is called in the context of `this`.
 * 2. If **opts.superclass** is not present, or if it is not a function, set the superclass to {@sref FlRoot}.
 * 3. The constructor's prototype is created as a copy of the superclass prototype.
 * 4. A number of properties are set in the prototype:
 *    - The **__class** property is set to the constructor.
 *    - The **__superclass** property is set to the superclass.
 *    - The **constructor** property is set to the constructor.
 * 5. A number of properties are set in the constructor:
 *    - The **__name** property is set to the class name.
 *    - The **__superclass** property is set to the superclass.
 * 6. The wrapped intializer is copied to the **__init** property of the prototype, and is set up for the 
 *    `__super` method.
 * 7. A default **factory** method is defined that creates an instance object. This method takes the
 *    same parameters as the contructor, and is dfined early enough that it can be overridden by a
 *    **factory** method defined in **class_methods**.
 * 8. If **opts.extensions** is an object, iterate over all its elements and register each extension's
 *    **methods** property with the prototype, using {@sref FlExtensions.register}. 
 *    This loads all the listed extension methods in the prototype.
 *  9. If **opts.instance_methods** is an object, copy all its key/value pairs to the prototype.
 * 10. If **opts.class_methods** is an object, copy all its key/value pairs to the constructor.
 * 11. Define the special method `__super`, which is used to call the superclass implementation of a method.
 *     To call the superclass implementation of a method, use the form `this.__super(...);`.
 *     For example:
 *         instance_methods: {
 *    	       my_method: function(msg) {
 *                 this.__super(msg);
 *                 this._my_field = msg;
 *    	       }
 *    	   }
 *     Note that there is no requirement to make the `__super` call; however, initializers should call the
 *     superclass implementation in order to initialize the object fully.
 *     If you don't call the `__super` method, you completely override the superclass implementation;
 *     if you do call it, you extend it instead.
 *     The `__super` call can be made from the initializer as well (and it *should* be made if one is
 *     defined).
 * 12. Register the constructor under the given class name; {@sref FlClassManager.get_class} can be used
 *     to fetch class constructors by name, and {@sref FlClassManager.instance_factory} to create
 *     instances of a given class.
 * 
 * Note that the order in which actions are performed implies that instance methods by the same name as those
 * loaded in the extensions will override the extension implementations.
 * 
 * The `__super` implementation was copied from
 * [this blog](http://blog.salsify.com/engineering/super-methods-in-javascript).
 *
 * Here is sample usage:
 *
 *     SuperTestBase = FlClassManager.make_class({
 *       name: 'SuperTestBase',
 *       initializer: function(m) {
 *         console.log("SuperTestBase init IN");
 *         this.__super();
 *         this._m = m;
 *     	  console.log("SuperTestBase init OUT");
 *     	},
 *     	instance_methods: {
 *     	  my_method: function(msg) {
 *     	    console.log("---------- IN");
 *     	    console.log("SuperTestBase : " + msg + ' - ' + this._m);
 *     	    console.log("---------- OUT");
 *     	  }
 *     	}
 *     });
 *     
 *     SuperTestBase2 = FlClassManager.make_class({
 *       name: 'SuperTestBase2',
 *     	instance_methods: {
 *     	  my_method: function(msg) {
 *     	    console.log("---------- IN");
 *     	    console.log("SuperTestBase2 : " + msg);
 *     	    console.log("---------- OUT");
 *     	  }
 *     	}
 *     });
 *     
 *     SuperTestSub = FlClassManager.make_class({
 *       name: 'SuperTestSub',
 *     	superclass: SuperTestBase,
 *     	initializer: function(m) {
 *     	  console.log("SuperTestSub init IN");
 *     	  this.__super(m);
 *     	  console.log("SuperTestSub init OUT");
 *     	},
 *     	instance_methods: {
 *     	  my_method: function(msg) {
 *     	    console.log("---------- IN");
 *     	    console.log("SuperTestSub: " + msg + ' - ' + this._m);
 *     	    this.__super(msg);
 *     	    console.log("---------- OUT");
 *     	  }
 *     	}
 *     });
 *     
 *     SuperTestSub2 = FlClassManager.make_class({
 *       name: 'SuperTestSub',
 *     	superclass: SuperTestBase2,
 *     	instance_methods: {
 *     	  my_method: function(msg) {
 *     	    console.log("---------- IN");
 *     	    console.log("SuperTestSub2: " + msg);
 *     	    this.__super(msg);
 *     	    console.log("---------- OUT");
 *     	  }
 *     	}
 *     });
 *     
 *     SuperTestSubSub = FlClassManager.make_class({
 *       name: 'SuperTestSubSub',
 *       superclass: SuperTestSub,
 *     	initializer: function(m) {
 *     	  console.log("SuperTestSubSub init IN");
 *     	  this.__super(m*2);
 *     	  console.log("SuperTestSubSub init OUT");
 *     	},
 *       instance_methods: {
 *         my_method: function(msg) {
 *           console.log("---------- IN");
 *           console.log("SuperTestSubSub: " + msg  + ' - ' + this._m);
 *           this.__super('(' + msg + ')');
 *           console.log("---------- OUT");
 *         }
 *       }
 *     });
 *
 *  And a log from a Chrome console session:
 *
 *     > sub = new SuperTestSub(10);
 *       SuperTestSub init IN
 *       SuperTestBase init IN
 *       FlRoot init IN
 *       FlRoot init OUT
 *       SuperTestBase init OUT
 *       SuperTestSub init OUT
 *     < SuperTestSub {_m: 10}
 *     > sub.my_method('sub');
 *       ---------- IN
 *       SuperTestSub: sub - 10
 *       ---------- IN
 *       SuperTestBase : sub - 10
 *       ---------- OUT
 *       ---------- OUT
 *     < undefined
 *     > subsub = new SuperTestSubSub(15);
 *       SuperTestSubSub init IN
 *       SuperTestSub init IN
 *       SuperTestBase init IN
 *       FlRoot init IN
 *       FlRoot init OUT
 *       SuperTestBase init OUT
 *       SuperTestSub init OUT
 *       SuperTestSubSub init OUT
 *     < SuperTestSubSub {_m: 30}
 *     > subsub.my_method('subsub');
 *       ---------- IN
 *       SuperTestSubSub: subsub - 30
 *       ---------- IN
 *       SuperTestSub: (subsub) - 30
 *       ---------- IN
 *       SuperTestBase : (subsub) - 30
 *       ---------- OUT
 *       ---------- OUT
 *       ---------- OUT
 *     < undefined
 *     > sub2 = new SuperTestSub2(10);
 *       FlRoot init IN
 *       FlRoot init OUT
 *     < SuperTestSub {}
 *     > sub2.my_method('sub2');
 *       ---------- IN
 *       SuperTestSub2: sub2
 *       ---------- IN
 *       SuperTestBase2 : sub2
 *       ---------- OUT
 *       ---------- OUT
 *     < undefined
 *
 * @param {Object} opts A hash containing the class description.
 * @property {String} opts.name The name of the constructor function for the class; this function is
 *  generated as described above. It is duplicated (via a call to **new**) to generate instance objects.
 * @property {Function|String} opts.superclass If the class inherits form a superclass, this is the superclass
 *  constructor, or a the name of the superclass.
 *  If this property is not given, the class will inherit from {@sref FlRoot}.
 * @property {Function} opts.initializer The function called by the constructor to initialize the object.
 *  It should include a call to **__super**.
 *  If the option is not present, an initializer containing a call to **__super** is created.
 * @property {Object} opts.instance_methods A hash containing the instance methods for the class.
 *  The values for the object's properties are functions; the contents of the hash are placed in the
 *  constructor's prototype.
 * @property {Object} opts.class_methods A hash containing the class methods for the class.
 *  The values for the object's properties are functions; the contents of the hash are placed in the
 *  constructor.
 * @property {Object} opts.extensions A hash containing the list of extensions for the class. The keys are
 *  identifiers for the extensions, and the values are extension descriptors. See {@sref FlExtensions}.
 * 
 * @return {Function} Returns the value of the constructor that was created.
 *
 * @throws Throws an exception if _name_ is already registered.
 */

FlClassManager.make_class = function(opts) {
    let cname = opts.name;
    if (_.isNil(cname)) throw new FlClassManager.MissingClass('missing :name property');
    if (!_.isNil(FlClassManager.get_class(cname))) throw new FlClassManager.AlreadyDefinedClass('class already defined: ' + cname);

    let init = (_.isFunction(opts.initializer)) ? opts.initializer : function() { this.__super(); };

    let extensions = { };
    if (_.isObject(opts.extensions))
    {
	extensions = _.reduce(opts.extensions, function(acc, ev, ek) {
	    acc[ek] = FlExtensions.lookup(ev);
	    return acc;
	}, { });
    }

    let ctor = (function() {
	return function() {
	    this.__init.apply(this, arguments);
	    return this;
	};
    })();

    // If no superclass is defined, we extend the root class
    // And, we trigger an exception if the superclass is given, but not registered

    let sname = (_.isNil(opts.superclass)) ? 'FlRoot' : opts.superclass;
    let superclass = FlClassManager.get_class(sname);
    if (!_.isFunction(superclass))
    {
	throw new FlClassManager.MissingClass('superclass not found: ' + sname);
    }

    ctor.prototype = Object.create(superclass.prototype);
    ctor.__name = cname;
    ctor.__superclass = superclass;
    ctor.prototype.constructor = ctor;

    let init_wrapper = (function(_ctor, _superclass, _extensions, _init) {
	return function() {
	    this.__init_extensions(_extensions, 'pre');
	    _init.apply(this, arguments);
	    this.__init_extensions(_extensions, 'post');

	    // we need to set this after the call to _init, so that nested calls to __super do not
	    // set the wrong values for these properties
	    
	    this.__class = _ctor;
	    this.__superclass = _superclass;
	};
    })(ctor, superclass, extensions, init);

    ctor.prototype.__init = init_wrapper;
    ctor.prototype.__init.__name = '__init';
    init.__name = '__init';

    // the factory method is defined before we load the class methods to give clients a chance to
    // override it

    let args = [ ];
    let iarg;
    for (iarg=1 ; iarg <= init.length ; iarg++)
    {
	args.push('arg' + iarg);
    }

    ctor.factory = (function(_opts, _ctor) {
	function __factory(args) {
	    return _ctor.apply(this, args);
	}
	__factory.prototype = Object.create(_ctor.prototype);

	return function() {
	    return new __factory(arguments);
	};
    })(opts, ctor);

    _.forEach(extensions, function(ev, ek) { FlExtensions.register(ev, ctor); });

    if (_.isObject(opts.instance_methods))
    {
	_.forEach(opts.instance_methods, function(mv, mk) {
	    ctor.prototype[mk] = mv;
	    ctor.prototype[mk].__name = mk;
	});
    }

    if (_.isObject(opts.class_methods))
    {
	_.forEach(opts.class_methods, function(mv, mk) {
	    ctor[mk] = mv;
	});
    }

    Object.defineProperty(ctor.prototype, "__super", {
	get: function get() {
	    // Note that we climb up one more stack level when super is called from
	    // the initializer, since the initializer is wrapped and we want the wrapper instead

	    let impl = get.caller;
	    let name = impl.__name;
	    if (name == '__init')
	    {
		impl = impl.caller;
	    }
	    let foundImpl = (this[name] === impl);
	    let proto = Object.getPrototypeOf(this);
 
	    while (proto)
	    {
		if (!proto[name])
		{
		    break;
		}
		else if (proto[name] === impl)
		{
		    foundImpl = true;
		}
		else if (foundImpl)
		{
		    return proto[name];
		}

		proto = Object.getPrototypeOf(proto);
	    }
 
	    if (!foundImpl) throw "no `super` implementation for :" + name;
	}
    });

    FlClassManager._class_registry[cname] = ctor;

    return ctor;
};

/**
 * @ngdoc function
 * @name FlClassManager.get_class
 * @module fl.object_system
 * @description
 * Get a registered class constructor.
 * 
 * @param {String|Function} name The name of the class to look up; as a convenience, if the value is a
 *  function that looks like a class created by {@sref FlClassManager.make_class}, it is returned as-is.
 * 
 * @return {Function|undefined} Returns the constructor registered under _name_ if one is available;
 *  otherwise, returns **undefined**.
 */

FlClassManager.get_class = function(name) {
    if (_.isString(name)) return FlClassManager._class_registry[name];
    if (_.isFunction(name) && _.isString(name.__name) && _.isFunction(name.__superclass)) return name;

    return undefined;
};

/**
 * @ngdoc function
 * @name FlClassManager.instance_factory
 * @module fl.object_system
 * @description
 * Factory function for registered classes.
 * This function calls {@sref FlClassManager.get_class} to obtain a constructor, and if one is found
 * it returns an instance of the class (using the **new** operator). Any arguments following _name_ 
 * are passed to the constructor.
 * 
 * @param {String|Function} name The name of the class to look up; as a convenience, you may pass a
 *  class object as well.
 * 
 * @return Returns an instance of the class registered under _name_ if one is available;
 *  otherwise, returns **null**.
 */

FlClassManager.instance_factory = function(name) {
    let ctor = FlClassManager.get_class(name);
    if (_.isFunction(ctor))
    {
	let args = Array.from(arguments);

	// The first argument is the class name

	args.shift();

	return ctor.factory.apply(ctor, args);
    }

    return null;
};

/**
 * @ngdoc function
 * @name FlClassManager.modelize
 * @module fl.object_system
 * @description
 * Modelize a hash.
 * If _data_ is `null` or `undefined`, returns _data_.
 * If _data_ is an array, calls **map** on _data_, passing a function that calls the modelize function for
 * each element of the array (and therefore returns an array of modelized elements).
 * If _data_ is not an array, calls <tt>new ctor(data)</tt> to modelize the hash.
 * 
 * The relevant part of the function consists of two steps:
 *  1. Resolve the constructor:
 *     <pre>ctor = FlClassManager.get_class(ctor);</pre>
 *     converts the *ctor* parameter into a constructor function.
 *  2. Instantiate the class:
 *     <pre>return new ctor(data);</pre>
 *     creates a new class instance.
 * 
 * @param {String|Function} ctor The constructor function to use; if passed as a string, the value is
 *  looked up in the class registry (using {@sref FlClassManager.get_class}).
 * @param {Object} data The object containing the hash to convert into a model object.
 */

FlClassManager.modelize = function(ctor, data) {
    if (_.isNil(data)) return data;

    ctor = FlClassManager.get_class(ctor);
    if (_.isArray(data))
    {
	return data.map(function(d) { return FlClassManager.modelize(ctor, d); });
    }
    else
    {
	return new ctor(data);
    }
};

module.exports = { FlExtensions, FlClassManager };
