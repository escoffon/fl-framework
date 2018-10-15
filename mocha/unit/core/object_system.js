const _ = require('lodash');
const chai = require('chai');
const { FlExtensions, FlClassManager } = require('fl/framework/object_system');
const th = require('test_helpers');

const expect = chai.expect;

const EXT1 = {
    methods: {
	f1: function(s) { return 'f1: ' + s; }
    }
};

const EXT2 = {
    methods: {
	f1: function(s) { return 'f10: ' + s; },
	f2: function(s) { return 'f20: ' + s; }
    }
};

const EXT3 = {
    class_methods: {
	c1: function(s) { return 'c100: ' + s; }
    },
    instance_methods: {
	f1: function(s) { return 'f100: ' + s; },
	f2: function(s) { return 'f200: ' + s; }
    }
};

const EXT_WITH_INIT = {
    methods: {
	f1: function(s) { return 'f10: ' + s; },
	f2: function(s) { return 'f20: ' + s; },
	passes: function() { return this._passes; }
    },
    initializer: function(pass) {
	if (pass == 'pre') this._passes = [ ];
	this._passes.push('pass1: ' + pass);
    }
};

const EXT_ONLY_INIT = {
    initializer: function(pass) {
	if (pass == 'pre') this._passes = [ ];
	this._passes.push('pass2: ' + pass);
    }
};

const EXT_FUNCTION_METHODS = {
    methods: function() {
	this.c4 = function(s) { return 'c4: ' + s; };
	this.prototype.f4 = function(s) { return 'f4: ' + s; };
    },
    initializer: function(pass) {
	if (pass == 'pre') this._passes = [ ];
	this._passes.push('pass3: ' + pass);
    }
};

const MY_BASE_DESC = {
    name: 'MyBase',
    initializer: function(a1, a2) {
	this.__super();
	this._a1 = a1;
	this._a2 = a2;
	this._ctx = { };
    },
    instance_methods: {
	set_msg: function(msg) {
	    this._ctx.msg = msg;
	},
	ctx: function() {
	    return this._ctx;
	},
	a1: function() { return this._a1; },
	a2: function() { return this._a2; }
    }
};

const MY_CLASS_DESC = {
    name: 'MyClass',
    superclass: 'MyBase',
    initializer: function(a1) {
	this.__super(a1, 'MyClass - a2');
    },
    instance_methods: {
	set_msg: function(msg) {
	    this.__super(msg + ' - MyClass');
	},
	my_method: function(msg) {
	    this._ctx.msg = msg;
	}
    }
};

const MY_CLASS1_DESC = {
    name: 'MyClass1',
    superclass: 'MyBase',
    initializer: function(a1) {
	this.__super(a1, 'MyClass1 - a2');
    },
    instance_methods: {
	set_msg: function(msg) {
	    this.__super(msg + ' - MyClass1');
	},
	my_method: function(msg) {
	    this._ctx.msg = msg;
	}
    },
    extensions: {
	c1: 'ExtWithInit'
    }
};

const MY_CLASS2_DESC = {
    name: 'MyClass2',
    superclass: 'MyBase',
    initializer: function(a1) {
	this.__super(a1, 'MyClass2 - a2');
    },
    instance_methods: {
	set_msg: function(msg) {
	    this.__super(msg + ' - MyClass2');
	},
	my_method: function(msg) {
	    this._ctx.msg = msg;
	}
    },
    extensions: {
	c1: 'ExtFunc'
    }
};

const MY_MODEL_BASE = {
    name: 'MyModelBase',
    initializer: function(data) {
	this.__super();
	this.refresh(data);
    },
    instance_methods: {
	refresh: function(data) {
	    if (_.isObject(data))
	    {
		let self = this;
		
		_.forEach(data, function(dv, dk) {
		    self[dk] = dv;
		});
	    }
	}
    }
};

const MY_MODEL_CLASS = {
    name: 'MyModelClass',
    superclass: 'MyModelBase',
    initializer: function(data) {
	this.__super(data);
    },
    instance_methods: {
	refresh: function(data) {
	    this.__super(data);

	    if (_.isObject(data) && _.isString(data.doubler))
	    {
		this.doubler = data.doubler + ' - ' + data.doubler;
	    }
	}
    }
};

describe('fl.object_system module', function() {
    describe('FlExtensions', function() {
	afterEach(function() {
	    th.clear_ext();
	});
	
	context('named', function() {
	    it('should register an extension', function() {
		let x = FlExtensions.named('Ext1', EXT1);
		expect(x.methods.f1('a')).to.equal('f1: a');
	    });

	    it('should throw on duplicate registration', function() {
		let x = FlExtensions.named('Ext1', EXT1);
		expect(x.methods.f1('a')).to.equal('f1: a');
		expect(function() { FlExtensions.named('Ext1', EXT2); }).to.throw();
	    });

	    it('should overwrite on duplicate registration if instructed', function() {
		let x = FlExtensions.named('Ext1', EXT1);
		expect(x.methods.f1('a')).to.equal('f1: a');
		expect(function() { FlExtensions.named('Ext1', EXT2, true); }).to.not.throw();
		let y = FlExtensions.lookup('Ext1');
		expect(y.methods.f1('a')).to.equal('f10: a');
		expect(y.methods.f2('a')).to.equal('f20: a');
	    });
	});

	context('list', function() {
	    it('should list names', function() {
		let e1 = FlExtensions.named('Ext1', EXT1);
		let e2 = FlExtensions.named('Ext2', EXT2);

		expect(FlExtensions.list()).to.have.members([ 'Ext1', 'Ext2' ]);
	    });

	    it('should list descriptors', function() {
		let e1 = FlExtensions.named('Ext1', EXT1);
		let e2 = FlExtensions.named('Ext2', EXT2);
		let el = FlExtensions.list(true);

		let x = _.map(el, function(e) { return _.isObject(e) && _.isString(e.name); });
		expect(x).to.have.members([ true, true ]);
		
		x = _.map(el, function(e) { return e.name; });
		expect(x).to.have.members([ 'Ext1', 'Ext2' ]);
	    });
	});
	
	context('lookup', function() {
	    it('should find a registered extension by name', function() {
		let x = FlExtensions.named('Ext1', EXT1);
		let y = FlExtensions.lookup('Ext1');
		expect(y.methods.f1('a')).to.equal(x.methods.f1('a'));
	    });

	    it('should throw on an unregistered extension by name', function() {
		expect(function() { return FlExtensions.lookup('NoExt'); }).to.throw();
	    });

	    it('should return an unregistered extension by descriptor', function() {
		expect(FlExtensions.lookup(EXT1).methods.f1('a')).to.equal('f1: a');
		expect(FlExtensions.lookup(EXT2).methods.f2('a')).to.equal('f20: a');
		expect(function() { return FlExtensions.lookup(EXT_ONLY_INIT); }).to.not.throw();
		expect(function() { return FlExtensions.lookup(EXT_FUNCTION_METHODS); }).to.not.throw();
	    });

	    it('should return undefined on an unregistered extension by name if instructed', function() {
		expect(FlExtensions.lookup('NoExt', false)).to.be.undefined;
	    });

	    it('should throw on an unregistered extension by bad descriptor', function() {
		expect(function() { return FlExtensions.lookup({ }); }).to.throw();
	    });
	});

	context('register', function() {
	    it('should inject a simple extension by name', function() {
		let x = FlExtensions.named('Ext1', EXT1);

		let ctor = function() { };
		let p = FlExtensions.register('Ext1', ctor);
		let f = new ctor();
		expect(f.f1('a')).to.equal('f1: a');
	    });

	    it('should inject a simple extension by descriptor', function() {
		let ctor = function() { };
		let p = FlExtensions.register(EXT2, ctor);
		let f = new ctor();
		expect(f.f1('a')).to.equal('f10: a');
	    });

	    it('should inject class and instance methods', function() {
		let x = FlExtensions.named('Ext3', EXT3);

		let ctor = function() { };
		let p = FlExtensions.register('Ext3', ctor);
		let f = new ctor();
		expect(f.f1('a')).to.equal('f100: a');
		expect(f.f2('a')).to.equal('f200: a');
		expect(function() { return f.c1('a'); }).to.throw();
		expect(ctor.c1('a')).to.equal('c100: a');
	    });

	    it('should inject a function methods extension by name', function() {
		let x = FlExtensions.named('FExt', EXT_FUNCTION_METHODS);

		let ctor = function() { };
		let p = FlExtensions.register('FExt', ctor);
		let f = new ctor();
		expect(f.f4('a')).to.equal('f4: a');
		expect(function() { return f.c4('a'); }).to.throw();
		expect(ctor.c4('a')).to.equal('c4: a');
	    });

	    it('should inject a function methods extension by descriptor', function() {
		let ctor = function() { };
		let p = FlExtensions.register(EXT_FUNCTION_METHODS, ctor);
		let f = new ctor();
		expect(f.f4('a')).to.equal('f4: a');
		expect(function() { return f.c4('a'); }).to.throw();
		expect(ctor.c4('a')).to.equal('c4: a');
	    });
	    
	    it('should no-op an undefined extension', function() {
		expect(function() { FlExtensions.register('NoExt', { }); }).to.not.throw();
	    });
	});

	context('initialize', function() {
	    it('should no-op an extension without initializer ', function() {
		let x = FlExtensions.named('Ext1', EXT1);

		expect(function() { FlExtensions.initialize('Ext1', { }, 'pre'); }).to.not.throw();
		expect(function() { FlExtensions.initialize(x, { }, 'pre'); }).to.not.throw();
	    });

	    it('should no-op an unknown extension ', function() {
		expect(function() { FlExtensions.initialize('NoExt', { }, 'pre'); }).to.not.throw();
	    });

	    it('should execute for an extension with initializer', function() {
		let x = FlExtensions.named('ExtInit', EXT_WITH_INIT);

		let ctor = function() { };
		let p = FlExtensions.register('ExtInit', ctor);
		let f = new ctor();
		expect(f.f1('a')).to.equal('f10: a');
		expect(function() { FlExtensions.initialize('ExtInit', f, 'pre'); }).to.not.throw();
		expect(f.passes()).to.have.members([ 'pass1: pre' ]);
		expect(function() { FlExtensions.initialize('ExtInit', f, 'post'); }).to.not.throw();
		expect(f.passes()).to.have.members([ 'pass1: pre', 'pass1: post' ]);
	    });
	});
    });

    describe('FlClassManager', function() {
	afterEach(function() {
	    th.clear_class();
	});
	
	context('make_class', function() {
	    it('should create a simple class', function() {
		let MyBase = FlClassManager.make_class(MY_BASE_DESC);

		expect(MyBase.__name).to.equal('MyBase');
		expect(MyBase.__superclass.__name).to.equal('FlRoot');
		
		let my1 = new MyBase('A1', 'A2');

		expect(my1.__class.__name).to.equal('MyBase');
		expect(my1.__superclass.__name).to.equal('FlRoot');

		expect(_.isFunction(my1.set_msg)).to.be.true;
		expect(_.isFunction(my1.ctx)).to.be.true;
		
		my1.set_msg('my1 msg');
		expect(my1.ctx().msg).to.equal('my1 msg');
	    });

	    it('should create a class with superclass', function() {
		let MyBase = FlClassManager.make_class(MY_BASE_DESC);
		let MyClass = FlClassManager.make_class(MY_CLASS_DESC);

		expect(MyBase.__name).to.equal('MyBase');
		expect(MyClass.__name).to.equal('MyClass');
		expect(MyClass.__superclass.__name).to.equal('MyBase');
		
		let my1 = new MyClass('A1');

		expect(my1.__class.__name).to.equal('MyClass');
		expect(my1.__superclass.__name).to.equal('MyBase');

		expect(_.isFunction(my1.set_msg)).to.be.true;
		expect(_.isFunction(my1.ctx)).to.be.true;
		expect(_.isFunction(my1.my_method)).to.be.true;

		expect(my1.a1()).to.equal('A1');
		expect(my1.a2()).to.equal('MyClass - a2');
		
		my1.set_msg('my1 msg');
		expect(my1.ctx().msg).to.equal('my1 msg - MyClass');

		my1.my_method('my1 msg 2');
		expect(my1.ctx().msg).to.equal('my1 msg 2');
	    });

	    it('should throw on a missing :name property', function() {
		expect(function() {
		    		return FlClassManager.make_class({
				    initializer: function() {
					this.__super();
				    },
     				    instance_methods: {
     				    }
				});
		}).to.throw();
	    });

	    it('should throw if a class is multiply defined', function() {
		let MyBase = FlClassManager.make_class(MY_BASE_DESC);

		expect(function() {
		    		return FlClassManager.make_class({
				    name: 'MyBase',
				    initializer: function() {
					this.__super();
				    },
     				    instance_methods: {
     				    }
				});
		}).to.throw();
	    });

	    it('should throw if a superclass is not defined', function() {
		expect(function() {
		    let MyClass = FlClassManager.make_class(MY_CLASS_DESC);
		}).to.throw();
	    });

	    it('should throw if an extension is not defined', function() {
		let MyBase = FlClassManager.make_class(MY_BASE_DESC);

		expect(function() {
		    return FlClassManager.make_class(MY_CLASS1_DESC);
		}).to.throw();
	    });

	    it('should create a class with extensions', function() {
		let x = FlExtensions.named('ExtWithInit', EXT_WITH_INIT);
		let MyBase = FlClassManager.make_class(MY_BASE_DESC);
		let MyClass1 = FlClassManager.make_class(MY_CLASS1_DESC);

		let my1 = new MyClass1('A1');

		expect(_.isFunction(my1.set_msg)).to.be.true;
		expect(_.isFunction(my1.ctx)).to.be.true;
		expect(_.isFunction(my1.my_method)).to.be.true;
		expect(_.isFunction(my1.f1)).to.be.true;
		expect(_.isFunction(my1.f2)).to.be.true;
		expect(_.isFunction(my1.passes)).to.be.true;

		expect(my1.a1()).to.equal('A1');
		expect(my1.a2()).to.equal('MyClass1 - a2');

		expect(my1.passes()).to.have.members([ 'pass1: pre', 'pass1: post' ]);
	    });

	    it('should create a class with an extension with function methods', function() {
		let x = FlExtensions.named('ExtFunc', EXT_FUNCTION_METHODS);
		let MyBase = FlClassManager.make_class(MY_BASE_DESC);
		let MyClass2 = FlClassManager.make_class(MY_CLASS2_DESC);

		let my2 = new MyClass2('A1');

		expect(_.isFunction(my2.set_msg)).to.be.true;
		expect(_.isFunction(my2.ctx)).to.be.true;
		expect(_.isFunction(my2.my_method)).to.be.true;
		expect(_.isFunction(my2.f4)).to.be.true;
		expect(_.isFunction(my2.f4)).to.be.true;
		expect(_.isFunction(my2.c4)).to.be.false;
		expect(_.isFunction(MyClass2.c4)).to.be.true;

		expect(my2.a1()).to.equal('A1');
		expect(my2.a2()).to.equal('MyClass2 - a2');
	    });
	});
	
	context('get_class', function() {
	    it('should find an existing class', function() {
		let MyBase = FlClassManager.make_class(MY_BASE_DESC);
		let MyClass = FlClassManager.make_class(MY_CLASS_DESC);

		let c = FlClassManager.get_class('MyBase');
		expect(c).to.be.a('function');
		expect(c.__name).to.equal('MyBase');

		c = FlClassManager.get_class('MyClass');
		expect(c).to.be.a('function');
		expect(c.__name).to.equal('MyClass');
	    });

	    it('should return a class if it looks like one', function() {
		let MyBase = FlClassManager.make_class(MY_BASE_DESC);
		
		let c = FlClassManager.get_class(MyBase);
		expect(c).to.be.a('function');
		expect(c.__name).to.equal('MyBase');
	    });

	    it('should return undefined on an unknown class', function() {
		let c = FlClassManager.get_class('NoClass');
		expect(c).to.be.undefined;
	    });

	    it('should return undefined if it does not look like a class', function() {
		let c = FlClassManager.get_class({ });
		expect(c).to.be.undefined;

	    	c = FlClassManager.get_class(function() { });
		expect(c).to.be.undefined;
	    });
	});
	
	context('instance_factory', function() {
	    it('should create instance for an existing class', function() {
		let MyBase = FlClassManager.make_class(MY_BASE_DESC);
		let MyClass = FlClassManager.make_class(MY_CLASS_DESC);

		let my1 = FlClassManager.instance_factory('MyClass', 'A100');

		expect(my1.__class.__name).to.equal('MyClass');
		expect(my1.__superclass.__name).to.equal('MyBase');

		expect(_.isFunction(my1.set_msg)).to.be.true;
		expect(_.isFunction(my1.ctx)).to.be.true;
		expect(_.isFunction(my1.my_method)).to.be.true;

		expect(my1.a1()).to.equal('A100');
		expect(my1.a2()).to.equal('MyClass - a2');

		my1.set_msg('my1 msg');
		expect(my1.ctx().msg).to.equal('my1 msg - MyClass');

		my1.my_method('my1 msg 2');
		expect(my1.ctx().msg).to.equal('my1 msg 2');
	    });

	    it('should fail for an unregistered class', function() {
		let MyBase = FlClassManager.make_class(MY_BASE_DESC);

		let my1 = FlClassManager.instance_factory('MyClass', 'A1');

		expect(my1).to.be.null;
	    });
	});
	
	context('modelize', function() {
	    beforeEach(function() {
		FlClassManager.make_class(MY_MODEL_BASE);
		FlClassManager.make_class(MY_MODEL_CLASS);
	    });

	    it('should return null or undefined for null or undefined input', function() {
		expect(FlClassManager.modelize('MyModelClass', null)).to.be.null;
		expect(FlClassManager.modelize('MyModelClass', undefined)).to.be.undefined;
	    });

	    it('should raise on an unregistered class', function() {
		expect(function() { return FlClassManager.modelize('NotAClass', { }); }).to.throw();
	    });
	    
	    it('should return a single object on single input', function() {
		let m1 = FlClassManager.modelize('MyModelClass', {
		    v1: 'v1',
		    doubler: 'd1'
		});

		expect(_.isObject(m1)).to.be.true;
		expect(m1.v1).to.equal('v1');
		expect(m1.doubler).to.equal('d1 - d1');
	    });
	    
	    it('should return a single object on single input (with explicit ctor)', function() {
		let MyModelClass = FlClassManager.get_class('MyModelClass');
		let m1 = FlClassManager.modelize(MyModelClass, {
		    v1: 'v1',
		    doubler: 'd1'
		});

		expect(_.isObject(m1)).to.be.true;
		expect(m1.v1).to.equal('v1');
		expect(m1.doubler).to.equal('d1 - d1');
	    });
	    
	    it('should return an an object array on array input', function() {
		let m1 = FlClassManager.modelize('MyModelClass', [
		    {
			v1: 'v1-1',
			doubler: 'd1-1'
		    },
		    {
			v1: 'v1-2',
			doubler: 'd1-2'
		    },
		]);

		expect(_.isArray(m1)).to.be.true;

		let v1 = _.map(m1, function(o, idx) { return o.v1; });
		expect(v1).to.have.members([ 'v1-1', 'v1-2' ]);

		let doubler = _.map(m1, function(o, idx) { return o.doubler; });
		expect(doubler).to.have.members([ 'd1-1 - d1-1', 'd1-2 - d1-2' ]);
	    });
	    
	    it('should return an an object array on array input (with explicit ctor)', function() {
		let MyModelClass = FlClassManager.get_class('MyModelClass');
		let m1 = FlClassManager.modelize(MyModelClass, [
		    {
			v1: 'v1-1',
			doubler: 'd1-1'
		    },
		    {
			v1: 'v1-2',
			doubler: 'd1-2'
		    },
		]);

		expect(_.isArray(m1)).to.be.true;

		let v1 = _.map(m1, function(o, idx) { return o.v1; });
		expect(v1).to.have.members([ 'v1-1', 'v1-2' ]);

		let doubler = _.map(m1, function(o, idx) { return o.doubler; });
		expect(doubler).to.have.members([ 'd1-1 - d1-1', 'd1-2 - d1-2' ]);
	    });
	});
    });
});
