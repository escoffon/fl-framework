const _ = require('lodash');
const chai = require('chai');
const { FlExtensions, FlClassManager } = require('fl/framework/object_system');
const {
    FlModelBase, FlModelCache, FlModelFactory, FlGlobalModelFactory
} = require('fl/framework/model_factory');
const {
    FlAPIService, FlAPIServiceRegistry, FlGlobalAPIServiceRegistry
} = require('fl/framework/api_services');
const { TestActor } = require('../../utils/test_models');
const { FlFrameworkListAPIService } = require('fl/framework/list_api_services');

const axios = require('axios');
const AxiosMockAdapter = require('axios-mock-adapter');

const myaxios = axios.create();
const expect = chai.expect;

const LIST_1 = {
    type: "Fl::Framework::List::List",
    api_root: "/fl/framework/list/lists",
    url_path: "fl_framework_list_list_path/1",
    fingerprint: "Fl::Framework::List::List/1",
    id: 1,
    created_at: "2019-03-04T03:08:46.133Z",
    updated_at: "2019-03-04T03:08:46.154Z",
    caption: "list caption - 1",
    title: "list title - 1",
    owner: {
	type: "TestActor",
	api_root: "/test_actors",
	url_path: "testactor_path/1",
	fingerprint: "TestActor/1",
	id: 1,
	created_at: "2019-03-04T03:08:46.119Z",
	updated_at: "2019-03-04T03:08:46.119Z",
	name: "actor.1"
    },
    default_readonly_state: true,
    list_display_preferences: null
};

const LIST_2 = {
    type: "Fl::Framework::List::List",
    api_root: "/fl/framework/list/lists",
    url_path: "fl_framework_list_list_path/1",
    fingerprint: "Fl::Framework::List::List/1",
    id: 1,
    created_at: "2019-03-04T03:08:46.133Z",
    updated_at: "2019-03-04T03:08:46.154Z",
    caption: "list caption - 1",
    title: "list title - 1",
    owner: {
	type: "TestActor",
	api_root: "/test_actors",
	url_path: "testactor_path/1",
	fingerprint: "TestActor/1",
	id: 1,
	created_at: "2019-03-04T03:08:46.119Z",
	updated_at: "2019-03-04T03:08:46.119Z",
	name: "actor.1"
    },
    default_readonly_state: true,
    list_display_preferences: null,
    list_items: [
	{
	    type: "Fl::Framework::List::ListItem",
	    api_root: "/fl/framework/list/list_items",
	    url_path: "fl_framework_list_listitem_path/2021",
	    fingerprint: "Fl::Framework::List::ListItem/2021",
	    id: 2021,
	    created_at: "2019-03-04T05:27:18.937Z",
	    updated_at: "2019-03-04T05:27:18.937Z",
	    owner: {
		type: "TestActor",
		api_root: "/test_actors",
		url_path: "testactor_path/1",
		fingerprint: "TestActor/1",
		id: 1,
		created_at: "2019-03-04T05:27:18.922Z",
		updated_at: "2019-03-04T05:27:18.922Z",
		name: "actor.1"
	    },
	    list: {
		type: "Fl::Framework::List::List",
		api_root: "/fl/framework/list/lists",
		url_path: "fl_framework_list_list_path/2",
		fingerprint: "Fl::Framework::List::List/2",
		id: 2,
		created_at: "2019-03-04T05:27:18.936Z",
		updated_at: "2019-03-04T05:27:18.955Z",
		caption: "list caption - 2",
		title: "list title - 2",
		owner: {
		    type: "TestActor",
		    api_root: "/test_actors",
		    url_path: "testactor_path/1",
		    fingerprint: "TestActor/1",
		    id: 1,
		    created_at: "2019-03-04T05:27:18.922Z",
		    updated_at: "2019-03-04T05:27:18.922Z",
		    name: "actor.1"
		},
		default_readonly_state: true,
		list_display_preferences: null
	    },
	    listed_object: {
		type: "TestDatumTwo",
		api_root: "/test_datum_twos",
		url_path: "testdatumtwo_path/1021",
		fingerprint: "TestDatumTwo/1021",
		id: 1021,
		created_at: "2019-03-04T05:27:18.924Z",
		updated_at: "2019-03-04T05:27:18.924Z",
		permissions: { read: "public", write: "public", destroy: "public" },
		owner: {
		    type: "TestActor",
		    api_root: "/test_actors",
		    url_path: "testactor_path/1",
		    fingerprint: "TestActor/1",
		    id: 6277,
		    created_at: "2019-03-04T05:27:18.922Z",
		    updated_at: "2019-03-04T05:27:18.922Z",
		    name: "actor.1"
		},
		title: "datum_two title.21",
		value: "v21"
	    },
	    readonly_state: null,
	    state: "selected",
	    sort_order: 0,
	    item_summary: "my title: datum_two title.21",
	    name: "d21"
	},
	{
	    type: "Fl::Framework::List::ListItem",
	    api_root: "/fl/framework/list/list_items",
	    url_path: "fl_framework_list_listitem_path/2010",
	    fingerprint: "Fl::Framework::List::ListItem/2010",
	    id: 2010,
	    created_at: "2019-03-04T05:27:18.946Z",
	    updated_at: "2019-03-04T05:27:18.946Z",
	    owner: {
		type: "TestActor",
		api_root: "/test_actors",
		url_path: "testactor_path/1",
		fingerprint: "TestActor/1",
		id: 1,
		created_at: "2019-03-04T05:27:18.922Z",
		updated_at: "2019-03-04T05:27:18.922Z",
		name: "actor.1"
	    },
	    list: {
		type: "Fl::Framework::List::List",
		api_root: "/fl/framework/list/lists",
		url_path: "fl_framework_list_list_path/2",
		fingerprint: "Fl::Framework::List::List/2",
		id: 2,
		created_at: "2019-03-04T05:27:18.936Z",
		updated_at: "2019-03-04T05:27:18.955Z",
		caption: "list caption - 2",
		title: "list title - 2",
		owner: {
		    type: "TestActor",
		    api_root: "/test_actors",
		    url_path: "testactor_path/1",
		    fingerprint: "TestActor/1",
		    id: 6277,
		    created_at: "2019-03-04T05:27:18.922Z",
		    updated_at: "2019-03-04T05:27:18.922Z",
		    name: "actor.1"
		},
		default_readonly_state: true,
		list_display_preferences: null
	    },
	    listed_object: {
		type: "TestDatumOne",
		api_root: "/test_datum_ones",
		url_path: "testdatumone_path/1010",
		fingerprint: "TestDatumOne/1010",
		id: 1010,
		created_at: "2019-03-04T05:27:18.927Z",
		updated_at: "2019-03-04T05:27:18.927Z",
		permissions: { read: "public", write: "public", destroy: "public" },
		owner: {
		    type: "TestActor",
		    api_root: "/test_actors",
		    url_path: "testactor_path/1",
		    fingerprint: "TestActor/1",
		    id: 1,
		    created_at: "2019-03-04T05:27:18.922Z",
		    updated_at: "2019-03-04T05:27:18.922Z",
		    name: "actor.1"
		},
		title: "datum_one title.10",
		value: 10
	    },
	    readonly_state: null,
	    state: "selected",
	    sort_order: 1,
	    item_summary: "datum_one title.10",
	    name: "d10"
	}
    ]
};

const axmock = new AxiosMockAdapter(myaxios);
axmock
    .onGet('/fl/framework/lists/1.json').reply(function(cfg) {
	return new Promise(function(resolve, reject) {
	    resolve([ 200, JSON.stringify({ list: LIST_1 }) ]);
	});
    })

    .onGet('/fl/framework/lists/2.json').reply(function(cfg) {
	return new Promise(function(resolve, reject) {
	    resolve([ 200, JSON.stringify({ list: LIST_2 }) ]);
	});
    })

    .onPatch('/fl/framework/lists/1.json').reply(function(cfg) {
	let jdata = JSON.parse(cfg.data);
	let l = _.merge({}, LIST_1, jdata.fl_framework_list);
	return new Promise(function(resolve, reject) {
	    resolve([ 200, JSON.stringify({ list: l }) ]);
	});
    })

;

const SRV_CFG = {
    axios: myaxios
};

describe('FlFrameworkListAPIService', function() {
    it('should be registered with FlClassManager', function() {
	expect(FlClassManager.get_class('FlFrameworkListAPIService')).to.not.be.null;
    });

    it('should be registered with FlGlobalAPIServiceRegistry', function() {
	expect(FlGlobalAPIServiceRegistry.service_info('Fl::Framework::List::List')).to.be.an.instanceof(Object);

	let srv = FlGlobalAPIServiceRegistry.create('Fl::Framework::List::List', SRV_CFG);
	let FlFrameworkListAPIService = FlClassManager.get_class('FlFrameworkListAPIService');
	expect(srv).to.be.an.instanceof(FlFrameworkListAPIService);
    });
    
    context(':show', function() {
	it('should return a known object', function() {
	    let FlFrameworkListList = FlClassManager.get_class('FlFrameworkListList');
	    let srv = FlGlobalAPIServiceRegistry.create('Fl::Framework::List::List', SRV_CFG);

	    return srv.show(1)
		.catch(function(e) {
		    console.log(">>>>>>>>>> e"); console.log(e); console.log("<<<<<<<<<<");
		    return Promise.resolve(true);
		})
		.then(function(data) {
		    expect(data).to.be.an.instanceof(FlFrameworkListList);
		    expect(data.id).to.eql(LIST_1.id);

		    FlModelFactory.defaultFactory().cache().remove(data);
		    
		    return Promise.resolve(true);
		});
	});

	it('should support model instances as id', function() {
	    let FlFrameworkListList = FlClassManager.get_class('FlFrameworkListList');
	    let srv = FlGlobalAPIServiceRegistry.create('Fl::Framework::List::List', SRV_CFG);
	    let list = new FlFrameworkListList(LIST_1);

	    return srv.show(list)
		.then(function(data) {
		    expect(data).to.be.an.instanceof(FlFrameworkListList);
		    expect(data.id).to.eql(LIST_1.id);
		    FlModelFactory.defaultFactory().cache().remove(data);
		    
		    return Promise.resolve(true);
		});
	});

	it('should convert the owner data to an object', function() {
	    let FlFrameworkListList = FlClassManager.get_class('FlFrameworkListList');
	    let srv = FlGlobalAPIServiceRegistry.create('Fl::Framework::List::List', SRV_CFG);

	    return srv.show(1)
		.then(function(data) {
		    expect(data).to.be.an.instanceof(FlFrameworkListList);
		    expect(data.id).to.eql(LIST_1.id);
		    expect(data.owner).to.not.be.null;
		    expect(data.owner).to.be.an.instanceof(TestActor);

		    FlModelFactory.defaultFactory().cache().remove(data);
		    
		    return Promise.resolve(true);
		});
	});

	it('should convert the list item data to objects', function() {
	    let FlFrameworkListList = FlClassManager.get_class('FlFrameworkListList');
	    let FlFrameworkListListItem = FlClassManager.get_class('FlFrameworkListListItem');
	    let srv = FlGlobalAPIServiceRegistry.create('Fl::Framework::List::List', SRV_CFG);

	    return srv.show(2)
		.then(function(data) {
		    expect(data).to.be.an.instanceof(FlFrameworkListList);
		    expect(data.id).to.eql(LIST_2.id);
		    expect(data.list_items).to.not.be.null;
		    expect(data.list_items).to.be.an.instanceof(Array);
		    expect(data.list_items[0]).to.be.an.instanceof(FlFrameworkListListItem);
		    expect(data.list_items[1]).to.be.an.instanceof(FlFrameworkListListItem);

		    FlModelFactory.defaultFactory().cache().remove(data);
		    
		    return Promise.resolve(true);
		});
	});
    });

    context(':update', function() {
	it('should return an updated object', function() {
	    let FlFrameworkListList = FlClassManager.get_class('FlFrameworkListList');
	    let srv = FlGlobalAPIServiceRegistry.create('Fl::Framework::List::List', SRV_CFG);

	    return srv.update(1, { wrapped: { title: 'new.title' } })
		.then(function(data) {
		    expect(data).to.be.an.instanceof(FlFrameworkListList);
		    expect(data.id).to.eql(LIST_1.id);
		    expect(data.title).to.eql('new.title');

		    FlModelFactory.defaultFactory().cache().remove(data);
		    
		    return Promise.resolve(true);
		});
	});

	it('should support model instances as id', function() {
	    let FlFrameworkListList = FlClassManager.get_class('FlFrameworkListList');
	    let srv = FlGlobalAPIServiceRegistry.create('Fl::Framework::List::List', SRV_CFG);
	    let list = new FlFrameworkListList(LIST_1);

	    return srv.update(list, { wrapped: { title: 'new.title' } })
		.then(function(data) {
		    expect(data).to.be.an.instanceof(FlFrameworkListList);
		    expect(data.id).to.eql(LIST_1.id);
		    expect(data.title).to.eql('new.title');

		    FlModelFactory.defaultFactory().cache().remove(data);
		    
		    return Promise.resolve(true);
		});
	});
    });
});
