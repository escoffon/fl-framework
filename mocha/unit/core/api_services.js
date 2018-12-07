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
    .onGet('/my/models.json').reply(200, JSON.stringify({
	models: [ MODEL_1, MODEL_2 ],
	_pg: { _c: 2, _s:20 , _p: 2}
    }))

    .onGet('/my/models/1.json').reply(200, JSON.stringify({ model: MODEL_1 }))

    .onGet('/my/models/10.json').reply(404, JSON.stringify({
	_error: { status: "not_found", message: "No user with id 10", details:null }
    }))

    .onPost('/my/models.json').reply(function(cfg) {
	let j = JSON.parse(cfg.data);
	let m = _.merge({}, MODEL_1, j.my_model);

	return [ 200, JSON.stringify({ model: m }) ];
    })

    .onPatch('/my/models/1.json').reply(function(cfg) {
	let j = JSON.parse(cfg.data);
	let m = _.merge({}, MODEL_1, j.my_model);

	return [ 200, JSON.stringify({ model: m }) ];
    })

    .onPatch('/my/models/10.json').reply(function(cfg) {
	let j = JSON.parse(cfg.data);
	let m = _.merge({}, MODEL_1, j.my_model);

	return [ 404, JSON.stringify({
	    _error: { status: "not_found", message: "No user with id 10", details:null }
	}) ];
    })
;

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
	context('default (global) configuration', function() {
	    it('should include the XSRF token names', function() {
		let cfg = FlAPIService.getServiceConfig();
		expect(cfg).to.be.an.instanceof(Object);
		expect(cfg).to.include.all.keys('xsrfCookieName', 'xsrfHeaderName');
	    });

	    it('should merge values', function() {
		let orig = FlAPIService.getServiceConfig();
		expect(orig).to.include.all.keys('xsrfCookieName', 'xsrfHeaderName');

		FlAPIService.setServiceConfig({ c1: 'c1', xsrfCookieName: 'NEW_NAME' });
		let cfg = FlAPIService.getServiceConfig();
		expect(cfg).to.include.all.keys('xsrfCookieName', 'xsrfHeaderName', 'c1');
		expect(cfg.xsrfCookieName).to.eq('NEW_NAME');
		expect(cfg.xsrfHeaderName).to.eq(orig.xsrfHeaderName);
		expect(cfg.c1).to.eq('c1');
		
		FlAPIService.setServiceConfig(orig, true);
	    });

	    it('should replace values', function() {
		let orig = FlAPIService.getServiceConfig();

		FlAPIService.setServiceConfig({ c1: 'c1' }, true);
		let cfg = FlAPIService.getServiceConfig();
		expect(cfg).to.include.all.keys('c1');

		FlAPIService.setServiceConfig(orig, true);
	    });

	    it('should support config properties', function() {
		let orig = FlAPIService.getServiceConfig();

		expect(FlAPIService.xsrfCookieName).to.eq(orig.xsrfCookieName);
		FlAPIService.xsrfCookieName = 'NEW-NAME';
		expect(FlAPIService.xsrfCookieName).to.eq('NEW-NAME');

		expect(FlAPIService.xsrfHeaderName).to.eq(orig.xsrfHeaderName);
		FlAPIService.xsrfHeaderName = 'NEW-NAME';
		expect(FlAPIService.xsrfHeaderName).to.eq('NEW-NAME');

		expect(FlAPIService.xsrfToken).to.be.undefined;
		FlAPIService.xsrfToken = 'MY-TOKEN';
		expect(FlAPIService.xsrfToken).to.eq('MY-TOKEN');
		
		FlAPIService.setServiceConfig(orig, true);
	    });
	});
	
	context('service (local) configuration', function() {
	    it('should inherit from global defaults', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let srv = new FlAPIService(API_CFG);

		expect(srv.getConfig()).to.include(FlAPIService.getServiceConfig());
	    });

	    it('should include the XSRF token names', function() {
		let srv = new FlAPIService(API_CFG);
		let cfg = srv.getConfig();
	       
		expect(cfg).to.be.an.instanceof(Object);
		expect(cfg).to.include.all.keys('xsrfCookieName', 'xsrfHeaderName');
	    });

	    it('should include the XSRF token value', function() {
		let srv = new FlAPIService(API_CFG, { xsrfToken: 'MY-TOKEN' });
		let cfg = srv.getConfig();
	       
		expect(cfg).to.be.an.instanceof(Object);
		expect(cfg.xsrfToken).to.eq('MY-TOKEN');
	    });

	    it('should merge values in the constructor', function() {
		let srv = new FlAPIService(API_CFG, { c1: 'c1', xsrfCookieName: 'NEW_NAME' });
		let cfg = srv.getConfig();

		expect(cfg).to.include.all.keys('xsrfCookieName', 'xsrfHeaderName', 'c1');
		expect(cfg.xsrfCookieName).to.eq('NEW_NAME');
		expect(cfg.xsrfHeaderName).to.eq(FlAPIService.getServiceConfig().xsrfHeaderName);
		expect(cfg.c1).to.eq('c1');
	    });

	    it('should merge values in the setter', function() {
		let srv = new FlAPIService(API_CFG);
		let cfg = srv.getConfig();

		expect(cfg).to.include.all.keys('xsrfCookieName', 'xsrfHeaderName');
		srv.setConfig({ c1: 'c1', xsrfCookieName: 'NEW_NAME' });
		cfg = srv.getConfig();
		expect(cfg).to.include.all.keys('xsrfCookieName', 'xsrfHeaderName', 'c1');
		expect(cfg.xsrfCookieName).to.eq('NEW_NAME');
		expect(cfg.xsrfHeaderName).to.eq(FlAPIService.getServiceConfig().xsrfHeaderName);
		expect(cfg.c1).to.eq('c1');
	    });

	    it('should replace values in the setter', function() {
		let srv = new FlAPIService(API_CFG, { c1: 'c1', xsrfCookieName: 'NEW_NAME' });
		let cfg = srv.getConfig();
	       
		expect(cfg).to.be.an.instanceof(Object);
		expect(cfg).to.include.all.keys('xsrfCookieName', 'xsrfHeaderName', 'c1');
		srv.setConfig({ c1: 'c1', xsrfCookieName: 'NEW_NAME' }, true);
		cfg = srv.getConfig();
		expect(cfg).to.include.all.keys('xsrfCookieName', 'c1');
		expect(cfg.xsrfCookieName).to.eq('NEW_NAME');
		expect(cfg.c1).to.eq('c1');
	    });

	    it('should support config properties', function() {
		let defs = FlAPIService.getServiceConfig();
		let srv = new FlAPIService(API_CFG);

		expect(srv.xsrfCookieName).to.eq(defs.xsrfCookieName);
		srv.xsrfCookieName = 'NEW-NAME';
		expect(srv.xsrfCookieName).to.eq('NEW-NAME');

		expect(srv.xsrfHeaderName).to.eq(defs.xsrfHeaderName);
		srv.xsrfHeaderName = 'NEW-NAME';
		expect(srv.xsrfHeaderName).to.eq('NEW-NAME');

		expect(srv.xsrfToken).to.be.undefined;
		srv.xsrfToken = 'MY-TOKEN';
		expect(srv.xsrfToken).to.eq('MY-TOKEN');
	    });
	});
	
	context(':index', function() {
	    it('should return objects', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let srv = new FlAPIService(API_CFG);

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

	    it('should pick up the local configuration', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let srv = new FlAPIService(API_CFG, { xsrfCookieName: 'NEW-COOKIE-NAME' });

		return srv.index()
		    .then(function(data) {
			let r = srv.response;

			expect(r.config.xsrfCookieName).to.eq('NEW-COOKIE-NAME');
			
			return Promise.resolve(true);
		    });
	    });

	    it('should pick up the configuration argument', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let srv = new FlAPIService(API_CFG, { xsrfCookieName: 'NEW-COOKIE-NAME' });

		return srv.index({ xsrfCookieName: 'YET-COOKIE-NAME' })
		    .then(function(data) {
			let r = srv.response;

			expect(r.config.xsrfCookieName).to.eq('YET-COOKIE-NAME');
			
			return Promise.resolve(true);
		    });
	    });

	    it('should set response on success', function() {
		let srv = new FlAPIService(API_CFG);

		expect(srv.response).to.be.undefined;
		
		return srv.index()
		    .then(function(data) {
			expect(srv.response).to.be.an.instanceof(Object);
			expect(srv.response).to.have.keys('status', 'data', 'headers', 'config');
			return Promise.resolve(true);
		    });
	    });
	});

	context(':show', function() {
	    it('should return a known object', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let srv = new FlAPIService(API_CFG);
		
		return srv.show(1)
		    .then(function(data) {
			expect(data).to.be.an.instanceof(MyModel);
			expect(data.value1).to.eq('model1 - value1');

			return Promise.resolve(true);
		    });
	    });

	    it('should accept a model instance', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let srv = new FlAPIService(API_CFG);
		let my1 = new MyModel(MODEL_1);
		
		return srv.show(my1)
		    .then(function(data) {
			expect(data).to.be.an.instanceof(MyModel);
			expect(data.value1).to.eq('model1 - value1');

			return Promise.resolve(true);
		    });
	    });

	    it('should error on an unknown object', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let srv = new FlAPIService(API_CFG);
		
		return srv.show(10)
		    .then(function(data) {
			return Promise.reject('should not have reached this');
		    })
		    .catch(function(r) {
			expect(r.status).to.eq(404);
			let err = srv.response_error(r);
			expect(err.status).to.eq('not_found');
			
			return Promise.resolve(true);
		    });
	    });

	    it('should pick up the local configuration', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let srv = new FlAPIService(API_CFG, { xsrfCookieName: 'NEW-COOKIE-NAME' });

		return srv.show(1)
		    .then(function(data) {
			let r = srv.response;

			expect(r.config.xsrfCookieName).to.eq('NEW-COOKIE-NAME');
			
			return Promise.resolve(true);
		    });
	    });

	    it('should pick up the configuration argument', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let srv = new FlAPIService(API_CFG, { xsrfCookieName: 'NEW-COOKIE-NAME' });

		return srv.show(1, { xsrfCookieName: 'YET-COOKIE-NAME' })
		    .then(function(data) {
			let r = srv.response;

			expect(r.config.xsrfCookieName).to.eq('YET-COOKIE-NAME');
			
			return Promise.resolve(true);
		    });
	    });

	    it('should set response on success', function() {
		let srv = new FlAPIService(API_CFG);

		expect(srv.response).to.be.undefined;
		
		return srv.show(1)
		    .then(function(data) {
			expect(srv.response).to.be.an.instanceof(Object);
			expect(srv.response).to.have.keys('status', 'data', 'headers', 'config');
			return Promise.resolve(true);
		    });
	    });

	    it('should set response on error', function() {
		let srv = new FlAPIService(API_CFG);

		expect(srv.response).to.be.undefined;
		
		return srv.show(10)
		    .catch(function(r) {
			expect(srv.response).to.be.an.instanceof(Object);
			expect(srv.response).to.have.keys('status', 'data', 'headers', 'config');
			return Promise.resolve(true);
		    });
	    });
	});

	context(':create', function() {
	    it('should return a new object', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let srv = new FlAPIService(API_CFG);
		
		return srv.create({ value1: 'new value1' })
		    .then(function(data) {
			expect(data).to.be.an.instanceof(MyModel);
			expect(data.value1).to.eq('new value1');

			return Promise.resolve(true);
		    });
	    });

	    it('should pick up the local configuration', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let srv = new FlAPIService(API_CFG, { xsrfCookieName: 'NEW-COOKIE-NAME' });

		return srv.create({ value1: 'new value1' })
		    .then(function(data) {
			let r = srv.response;

			expect(r.config.xsrfCookieName).to.eq('NEW-COOKIE-NAME');
			
			return Promise.resolve(true);
		    });
	    });

	    it('should pick up the configuration argument', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let srv = new FlAPIService(API_CFG, { xsrfCookieName: 'NEW-COOKIE-NAME' });

		return srv.create({ value1: 'new value1' }, { xsrfCookieName: 'YET-COOKIE-NAME' })
		    .then(function(data) {
			let r = srv.response;

			expect(r.config.xsrfCookieName).to.eq('YET-COOKIE-NAME');
			
			return Promise.resolve(true);
		    });
	    });

	    it('should add the XSRF header', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let srv = new FlAPIService(API_CFG, { xsrfToken: 'MY-TOKEN' });
		
		return srv.create({ value1: 'new value1' })
		    .then(function(data) {
			let r = srv.response;
			expect(r.config.headers).to.include({ [srv.xsrfHeaderName]: 'MY-TOKEN' });
			return Promise.resolve(true);
		    });
	    });

	    it('should set response on success', function() {
		let srv = new FlAPIService(API_CFG);

		expect(srv.response).to.be.undefined;
		
		return srv.create({ value1: 'new value1' })
		    .then(function(data) {
			expect(srv.response).to.be.an.instanceof(Object);
			expect(srv.response).to.have.keys('status', 'data', 'headers', 'config');
			return Promise.resolve(true);
		    });
	    });
	});

	context(':update', function() {
	    it('should return the edited object', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let srv = new FlAPIService(API_CFG);
		
		return srv.update(1, { value1: 'new value1' })
		    .then(function(data) {
			expect(data).to.be.an.instanceof(MyModel);
			expect(data.id).to.eq(1);
			expect(data.value1).to.eq('new value1');

			return Promise.resolve(true);
		    });
	    });

	    it('should accept a model instance', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let srv = new FlAPIService(API_CFG);
		let my1 = new MyModel(MODEL_1);
		
		return srv.update(my1, { value1: 'new value1' })
		    .then(function(data) {
			expect(data).to.be.an.instanceof(MyModel);
			expect(data.id).to.eq(1);
			expect(data.value1).to.eq('new value1');

			return Promise.resolve(true);
		    });
	    });

	    it('should error on an unknown object', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let srv = new FlAPIService(API_CFG);
		
		return srv.update(10, { value1: 'new value1' })
		    .then(function(data) {
			return Promise.reject('should not have reached this');
		    })
		    .catch(function(r) {
			expect(r.status).to.eq(404);
			let err = srv.response_error(r);
			expect(err.status).to.eq('not_found');
			
			return Promise.resolve(true);
		    });
	    });

	    it('should pick up the local configuration', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let srv = new FlAPIService(API_CFG, { xsrfCookieName: 'NEW-COOKIE-NAME' });

		return srv.update(1, { value1: 'new value1' })
		    .then(function(data) {
			let r = srv.response;

			expect(r.config.xsrfCookieName).to.eq('NEW-COOKIE-NAME');
			
			return Promise.resolve(true);
		    });
	    });

	    it('should pick up the configuration argument', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let srv = new FlAPIService(API_CFG, { xsrfCookieName: 'NEW-COOKIE-NAME' });

		return srv.update(1, { value1: 'new value1' }, { xsrfCookieName: 'YET-COOKIE-NAME' })
		    .then(function(data) {
			let r = srv.response;

			expect(r.config.xsrfCookieName).to.eq('YET-COOKIE-NAME');
			
			return Promise.resolve(true);
		    });
	    });

	    it('should add the XSRF header', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let srv = new FlAPIService(API_CFG, { xsrfToken: 'MY-TOKEN' });
		
		return srv.update(1, { value1: 'new value1' })
		    .then(function(data) {
			let r = srv.response;
			expect(r.config.headers).to.include({ [srv.xsrfHeaderName]: 'MY-TOKEN' });
			return Promise.resolve(true);
		    });
	    });

	    it('should set response on success', function() {
		let srv = new FlAPIService(API_CFG);

		expect(srv.response).to.be.undefined;
		
		return srv.update(1, { value1: 'new value1' })
		    .then(function(data) {
			expect(srv.response).to.be.an.instanceof(Object);
			expect(srv.response).to.have.keys('status', 'data', 'headers', 'config');
			return Promise.resolve(true);
		    });
	    });

	    it('should set response on error', function() {
		let srv = new FlAPIService(API_CFG);

		expect(srv.response).to.be.undefined;
		
		return srv.update(10, { value1: 'new value1' })
		    .catch(function(data) {
			expect(srv.response).to.be.an.instanceof(Object);
			expect(srv.response).to.have.keys('status', 'data', 'headers', 'config');
			return Promise.resolve(true);
		    });
	    });
	});

	context('response_error', function() {
	    it('should extract standard API data', function() {
		let srv = new FlAPIService(API_CFG);
		let err = srv.response_error({ status: 'test_status', data: {
		    _error: {
			status: 'error_status',
			message: 'error_message',
			details: 'error_details'
		    }}});

		expect(err).to.include({
		    status: 'error_status', message: 'error_message', details: 'error_details'
		});
	    });

	    it('should extract (almost) standard API data', function() {
		let srv = new FlAPIService(API_CFG);
		let err = srv.response_error({ data: {
		    _error: {
			status: 'error_status',
			message: 'error_message',
			details: 'error_details'
		    }}});

		expect(err).to.include({
		    status: 'error_status', message: 'error_message', details: 'error_details'
		});
	    });

	    it('should extract with missing data', function() {
		let srv = new FlAPIService(API_CFG);
		let err = srv.response_error({ status: 'test_status', message: 'test_message' });

		expect(err).to.include({
		    status: 'test_status', message: 'test_message'
		});
	    });

	    it('should extract with incomplete data', function() {
		let srv = new FlAPIService(API_CFG);
		let err = srv.response_error({ status: 'test_status', message: 'test_message', data: {
		}});

		expect(err).to.include({
		    status: 'test_status', message: 'test_message'
		});
	    });

	    it('should extract with correct priorities', function() {
		let srv = new FlAPIService(API_CFG);
		let err = srv.response_error({
		    status: 'test_status',
		    message: 'test_message',
		    data: {
			_error: {
			    status: 'error_status',
			    message: 'error_message',
			    details: 'error_details'
			}
		    }
		});

		expect(err).to.include({
		    status: 'error_status', message: 'error_message', details: 'error_details'
		});
	    });
	});
    });

    describe('FlAPIService subclass', function() {
	context(':index', function() {
	    it('should return objects', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService();
		
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

	    it('should pick up the local configuration', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService({ xsrfCookieName: 'NEW-COOKIE-NAME' });

		return srv.index()
		    .then(function(data) {
			let r = srv.response;

			expect(r.config.xsrfCookieName).to.eq('NEW-COOKIE-NAME');
			
			return Promise.resolve(true);
		    });
	    });

	    it('should pick up the configuration argument', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService({ xsrfCookieName: 'NEW-COOKIE-NAME' });

		return srv.index({ xsrfCookieName: 'YET-COOKIE-NAME' })
		    .then(function(data) {
			let r = srv.response;

			expect(r.config.xsrfCookieName).to.eq('YET-COOKIE-NAME');
			
			return Promise.resolve(true);
		    });
	    });

	    it('should set response on success', function() {
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService();

		expect(srv.response).to.be.undefined;
		
		return srv.index()
		    .then(function(data) {
			expect(srv.response).to.be.an.instanceof(Object);
			expect(srv.response).to.have.keys('status', 'data', 'headers', 'config');
			return Promise.resolve(true);
		    });
	    });
	});

	context(':show', function() {
	    it('should return a known object', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService();
		
		return srv.show(1)
		    .then(function(data) {
			expect(data).to.be.an.instanceof(MyModel);
			expect(data.value1).to.eq('model1 - value1');

			return Promise.resolve(true);
		    });
	    });

	    it('should accept a model instance', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService();
		let my1 = new MyModel(MODEL_1);
		
		return srv.show(my1)
		    .then(function(data) {
			expect(data).to.be.an.instanceof(MyModel);
			expect(data.value1).to.eq('model1 - value1');

			return Promise.resolve(true);
		    });
	    });

	    it('should error on an unknown object', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService();
		
		return srv.show(10)
		    .then(function(data) {
			return Promise.reject('should not have reached this');
		    })
		    .catch(function(e) {
			return Promise.resolve(true);
		    });
	    });

	    it('should pick up the local configuration', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService({ xsrfCookieName: 'NEW-COOKIE-NAME' });

		return srv.show(1)
		    .then(function(data) {
			let r = srv.response;

			expect(r.config.xsrfCookieName).to.eq('NEW-COOKIE-NAME');
			
			return Promise.resolve(true);
		    });
	    });

	    it('should pick up the configuration argument', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService({ xsrfCookieName: 'NEW-COOKIE-NAME' });

		return srv.show(1, { xsrfCookieName: 'YET-COOKIE-NAME' })
		    .then(function(data) {
			let r = srv.response;

			expect(r.config.xsrfCookieName).to.eq('YET-COOKIE-NAME');
			
			return Promise.resolve(true);
		    });
	    });

	    it('should set response on success', function() {
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService();

		expect(srv.response).to.be.undefined;
		
		return srv.show(1)
		    .then(function(data) {
			expect(srv.response).to.be.an.instanceof(Object);
			expect(srv.response).to.have.keys('status', 'data', 'headers', 'config');
			return Promise.resolve(true);
		    });
	    });

	    it('should set response on error', function() {
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService();

		expect(srv.response).to.be.undefined;
		
		return srv.show(10)
		    .catch(function(r) {
			expect(srv.response).to.be.an.instanceof(Object);
			expect(srv.response).to.have.keys('status', 'data', 'headers', 'config');
			return Promise.resolve(true);
		    });
	    });
	});

	context(':create', function() {
	    it('should return a new object', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService();
		
		return srv.create({ value1: 'new value1' })
		    .then(function(data) {
			expect(data).to.be.an.instanceof(MyModel);
			expect(data.value1).to.eq('new value1');

			return Promise.resolve(true);
		    });
	    });

	    it('should pick up the local configuration', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService({ xsrfCookieName: 'NEW-COOKIE-NAME' });

		return srv.create({ value1: 'new value1' })
		    .then(function(data) {
			let r = srv.response;

			expect(r.config.xsrfCookieName).to.eq('NEW-COOKIE-NAME');
			
			return Promise.resolve(true);
		    });
	    });

	    it('should pick up the configuration argument', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService({ xsrfCookieName: 'NEW-COOKIE-NAME' });

		return srv.create({ value1: 'new value1' }, { xsrfCookieName: 'YET-COOKIE-NAME' })
		    .then(function(data) {
			let r = srv.response;

			expect(r.config.xsrfCookieName).to.eq('YET-COOKIE-NAME');
			
			return Promise.resolve(true);
		    });
	    });

	    it('should add the XSRF header', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService({ xsrfHeaderName: 'NEW-HEADER-NAME', xsrfToken: 'MY-TOKEN' });
		
		return srv.create({ value1: 'new value1' })
		    .then(function(data) {
			let r = srv.response;
			expect(r.config.headers).to.include({ [srv.xsrfHeaderName]: 'MY-TOKEN' });
			return Promise.resolve(true);
		    });
	    });

	    it('should set response on success', function() {
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService();

		expect(srv.response).to.be.undefined;
		
		return srv.create({ value1: 'new value1' })
		    .then(function(data) {
			expect(srv.response).to.be.an.instanceof(Object);
			expect(srv.response).to.have.keys('status', 'data', 'headers', 'config');
			return Promise.resolve(true);
		    });
	    });
	});

	context(':update', function() {
	    it('should return the edited object', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService();
		
		return srv.update(1, { value1: 'new value1' })
		    .then(function(data) {
			expect(data).to.be.an.instanceof(MyModel);
			expect(data.id).to.eq(1);
			expect(data.value1).to.eq('new value1');

			return Promise.resolve(true);
		    });
	    });

	    it('should accept a model instance', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService();
		let my1 = new MyModel(MODEL_1);
		
		return srv.update(my1, { value1: 'new value1' })
		    .then(function(data) {
			expect(data).to.be.an.instanceof(MyModel);
			expect(data.id).to.eq(1);
			expect(data.value1).to.eq('new value1');

			return Promise.resolve(true);
		    });
	    });

	    it('should error on an unknown object', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService();
		
		return srv.update(10, { value1: 'new value1' })
		    .then(function(data) {
			return Promise.reject('should not have reached this');
		    })
		    .catch(function(r) {
			expect(r.status).to.eq(404);
			let err = srv.response_error(r);
			expect(err.status).to.eq('not_found');
			
			return Promise.resolve(true);
		    });
	    });

	    it('should pick up the local configuration', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService({ xsrfCookieName: 'NEW-COOKIE-NAME' });

		return srv.update(1, { value1: 'new value1' })
		    .then(function(data) {
			let r = srv.response;

			expect(r.config.xsrfCookieName).to.eq('NEW-COOKIE-NAME');
			
			return Promise.resolve(true);
		    });
	    });

	    it('should pick up the configuration argument', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService({ xsrfCookieName: 'NEW-COOKIE-NAME' });

		return srv.update(1, { value1: 'new value1' }, { xsrfCookieName: 'YET-COOKIE-NAME' })
		    .then(function(data) {
			let r = srv.response;

			expect(r.config.xsrfCookieName).to.eq('YET-COOKIE-NAME');
			
			return Promise.resolve(true);
		    });
	    });

	    it('should add the XSRF header', function() {
		let MyModel = FlClassManager.get_class('MyModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService({ xsrfHeaderName: 'NEW-HEADER-NAME', xsrfToken: 'MY-TOKEN' });
		
		return srv.update(1, { value1: 'new value1' })
		    .then(function(data) {
			let r = srv.response;
			expect(r.config.headers).to.include({ [srv.xsrfHeaderName]: 'MY-TOKEN' });
			return Promise.resolve(true);
		    });
	    });

	    it('should set response on success', function() {
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService();

		expect(srv.response).to.be.undefined;
		
		return srv.update(1, { value1: 'new value1' })
		    .then(function(data) {
			expect(srv.response).to.be.an.instanceof(Object);
			expect(srv.response).to.have.keys('status', 'data', 'headers', 'config');
			return Promise.resolve(true);
		    });
	    });

	    it('should set response on error', function() {
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService();

		expect(srv.response).to.be.undefined;
		
		return srv.update(10, { value1: 'new value1' })
		    .catch(function(data) {
			expect(srv.response).to.be.an.instanceof(Object);
			expect(srv.response).to.have.keys('status', 'data', 'headers', 'config');
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
