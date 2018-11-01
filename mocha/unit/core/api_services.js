const _ = require('lodash');
const chai = require('chai');
const { FlExtensions, FlClassManager } = require('fl/framework/object_system');
const {
    FlModelBase, FlModelCache, FlModelFactory, FlGlobalModelFactory
} = require('fl/framework/model_factory');
const {
    FlAPIService, FlAPIServiceRegistry, FlGlobalAPIServiceRegistry
} = require('fl/framework/api_services');
const th = require('test_helpers');
const axios = require('axios');
const AxiosMockAdapter = require('axios-mock-adapter');

const expect = chai.expect;

const MY_MODEL_DESC = {
    name: 'MyModel',
    superclass: 'FlModelBase',
    initializer: function(data) {
	this.__super_init('FlModelBase', data);
    },
    instance_methods: {
	refresh: function(data) {
	    this.__super('FlModelBase', 'refresh', data);
	}
    }
};

const MODEL_1 = {
    type: "My::Model",
    api_root: "/my/models",
    url_path: "my/models/1",
    fingerprint: "My::Model/1",
    id: 1,
    created_at: 'Thu, 13 Sep 2018 21:57:27 UTC +00:00',
    updated_at: 'Thu, 13 Sep 2018 21:57:27 UTC +00:00',
    value1: 'model1 - value1'
};

const MODEL_2 = {
    type: "My::Model",
    api_root: "/my/models",
    url_path: "my/models/2",
    fingerprint: "My::Model/2",
    id: 2,
    created_at: 'Thu, 13 Sep 2018 22:57:27 UTC +00:00',
    updated_at: 'Thu, 13 Sep 2028 22:57:27 UTC +00:00',
    value1: 'model2 - value1'
};

const API_CFG = {
    root_url: '/my/models',
    namespace: 'my_model',
    data_names: [ 'model', 'models' ]
};

const axmock = new AxiosMockAdapter(axios);

axmock
    .onGet('/my/models.json').reply(200, {
	models: [ MODEL_1, MODEL_2 ],
	_pg: { _c: 2, _s:20 , _p: 2}
    })
    .onGet('/my/models/1.json').reply(200, {
	model: MODEL_1
    })
    .onGet('/my/models/10.json').reply(404, {
	_error: { status: "not_found", message: "No user with id 10", details:null }
    })
    .onPost('/my/models.json').reply(function(cfg) {
	let j = JSON.parse(cfg.data);
	let m = _.merge({}, MODEL_1, j.my_model);

	return [ 200, {
	    model: m
	} ];
    })
    .onPatch('/my/models/1.json').reply(function(cfg) {
	let j = JSON.parse(cfg.data);
	let m = _.merge({}, MODEL_1, j.my_model);

	return [ 200, {
	    model: m
	} ];
    })
;

const SRV_CFG = {
    axios: axios
};

const MY_SERVICE_DESC = {
    name: 'MyAPIService',
    superclass: 'FlAPIService',
    initializer: function(srv_cfg) {
	this.__super_init('FlAPIService', API_CFG, srv_cfg);
    }
};

describe('fl.api_services module', function() {
    before(function() {
	let MyModel = FlClassManager.make_class(MY_MODEL_DESC);

	FlGlobalModelFactory.register('api_services_tester', [
	    { service: MyModel, class_name: 'My::Model' }
	]);

	let MyAPIService = FlClassManager.make_class(MY_SERVICE_DESC);
    });
    
    after(function() {
	th.clear_model_services();
	th.clear_ext();
	th.clear_class();
    });

    describe('FlAPIService', function() {
	context(':index', function() {
	    it('should return objects', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let srv = new FlAPIService(API_CFG, SRV_CFG);
		
		return srv.index()
		    .then(function(data) {
			expect(data).to.be.an('array');
			expect(data.length).to.eq(2);
			expect(data[0]).to.be.an.instanceof(MyModel);
			expect(data[0].value1).to.eq('model1 - value1');
			expect(data[1]).to.be.an.instanceof(MyModel);
			expect(data[1].value1).to.eq('model2 - value1');
			return Promise.resolve(true);
		    });
	    });
	});

	context(':show', function() {
	    it('should return a known object', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let srv = new FlAPIService(API_CFG, SRV_CFG);
		
		return srv.show(1)
		    .then(function(data) {
			expect(data).to.be.an.instanceof(MyModel);
			expect(data.value1).to.eq('model1 - value1');

			return Promise.resolve(true);
		    });
	    });

	    it.skip('should error on an unknown object', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let srv = new FlAPIService(API_CFG, SRV_CFG);
		
		return srv.show(10)
		    .then(function(data) {
			return Promise.reject('should not have reached this');
		    })
		    .catch(function(e) {
			console.log(">>>>>>>>>> e"); console.log(e); console.log("<<<<<<<<<<");
			return Promise.resolve(true);
		    });
	    });
	});

	context(':create', function() {
	    it('should return a new object', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let srv = new FlAPIService(API_CFG, SRV_CFG);
		
		return srv.create({ value1: 'new value1' })
		    .then(function(data) {
			expect(data).to.be.an.instanceof(MyModel);
			expect(data.value1).to.eq('new value1');

			return Promise.resolve(true);
		    });
	    });
	});

	context(':update', function() {
	    it('should return the edited object', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let srv = new FlAPIService(API_CFG, SRV_CFG);
		
		return srv.update(1, { value1: 'new value1' })
		    .then(function(data) {
			expect(data).to.be.an.instanceof(MyModel);
			expect(data.id).to.eq(1);
			expect(data.value1).to.eq('new value1');

			return Promise.resolve(true);
		    });
	    });
	});
    });

    describe('FlAPIService subclass', function() {
	context(':index', function() {
	    it('should return objects', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService(SRV_CFG);
		
		return srv.index()
		    .then(function(data) {
			expect(data).to.be.an('array');
			expect(data.length).to.eq(2);
			expect(data[0]).to.be.an.instanceof(MyModel);
			expect(data[0].value1).to.eq('model1 - value1');
			expect(data[1]).to.be.an.instanceof(MyModel);
			expect(data[1].value1).to.eq('model2 - value1');
			return Promise.resolve(true);
		    });
	    });
	});

	context(':show', function() {
	    it('should return a known object', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService(SRV_CFG);
		
		return srv.show(1)
		    .then(function(data) {
			expect(data).to.be.an.instanceof(MyModel);
			expect(data.value1).to.eq('model1 - value1');

			return Promise.resolve(true);
		    });
	    });

	    it.skip('should error on an unknown object', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService(SRV_CFG);
		
		return srv.show(10)
		    .then(function(data) {
			return Promise.reject('should not have reached this');
		    })
		    .catch(function(e) {
			console.log(">>>>>>>>>> e"); console.log(e); console.log("<<<<<<<<<<");
			return Promise.resolve(true);
		    });
	    });
	});

	context(':create', function() {
	    it('should return a new object', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService(SRV_CFG);
		
		return srv.create({ value1: 'new value1' })
		    .then(function(data) {
			expect(data).to.be.an.instanceof(MyModel);
			expect(data.value1).to.eq('new value1');

			return Promise.resolve(true);
		    });
	    });
	});

	context(':update', function() {
	    it('should return the edited object', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService(SRV_CFG);
		
		return srv.update(1, { value1: 'new value1' })
		    .then(function(data) {
			expect(data).to.be.an.instanceof(MyModel);
			expect(data.id).to.eq(1);
			expect(data.value1).to.eq('new value1');

			return Promise.resolve(true);
		    });
	    });
	});
    });

    describe('FlAPIServiceRegistry', function() {
	afterEach(function() {
	    th.clear_api_services();
	});
	
	context('#register', function() {
	    it('should register a service', function() {
		expect(FlGlobalAPIServiceRegistry.service_info('My::Other')).to.be.null;
		expect(FlGlobalAPIServiceRegistry.service_info('MyOther')).to.be.null;
	    
		FlGlobalAPIServiceRegistry.register('test_model', {
		    MyOtherAPIService: 'My::Other'
		});

		expect(FlGlobalAPIServiceRegistry.service_info('My::Other')).to.not.be.null;
		expect(FlGlobalAPIServiceRegistry.service_info('MyOther')).to.not.be.null;
	    });

	    it('should override a registered service', function() {
		FlGlobalAPIServiceRegistry.register('test_model', {
		    MyOtherAPIService: 'My::Other'
		});

		let info = FlGlobalAPIServiceRegistry.service_info('My::Other');
		expect(info).to.be.an.instanceof(Object);
		expect(info.api_service).to.eq('MyOtherAPIService');
		
		FlGlobalAPIServiceRegistry.register('test_model', {
		    MyOther2APIService: 'My::Other'
		});
		info = FlGlobalAPIServiceRegistry.service_info('My::Other');
		expect(info).to.be.an.instanceof(Object);
		expect(info.api_service).to.eq('MyOther2APIService');
	    });
	});
	
	context('#service_info', function() {
	    it('should find a registered service', function() {
		FlGlobalAPIServiceRegistry.register('test_model', {
		    MyOtherAPIService: 'My::Other'
		});

		expect(FlGlobalAPIServiceRegistry.service_info('My::Other')).to.not.be.null;
		expect(FlGlobalAPIServiceRegistry.service_info('MyOther')).to.not.be.null;
	    });

	    it('should return null for an unregistered service', function() {
		expect(FlGlobalAPIServiceRegistry.service_info('My::Not::Registered')).to.be.null;
	    });
	});
	
	context('#create', function() {
	    it('should create a registered service', function() {
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		expect(MyAPIService).to.not.be.undefined;
		
		FlGlobalAPIServiceRegistry.register('api_services_tester', {
		    'MyAPIService': 'My::Model'
		});

		let srv = FlGlobalAPIServiceRegistry.create('My::Model', { prop1: 1 });
		expect(srv).to.be.an.instanceof(MyAPIService);
		expect(srv._srv_cfg.prop1).to.eq(1);

		srv = FlGlobalAPIServiceRegistry.create('My::Model', { prop1: 2 });
		expect(srv).to.be.an.instanceof(MyAPIService);
		expect(srv._srv_cfg.prop1).to.eq(2);
	    });

	    it('should return null for an unregistered service', function() {
		expect(FlGlobalAPIServiceRegistry.create('Not::Registered', { prop1: 1 })).to.be.null;
	    });
	});
    });
});
