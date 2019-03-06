const _ = require('lodash');
const chai = require('chai');
const { FlExtensions, FlClassManager } = require('fl/framework/object_system');
const {
    FlModelBase, FlModelCache, FlModelFactory, FlGlobalModelFactory
} = require('fl/framework/model_factory');
const {
    FlAPIService, FlAPIServiceRegistry, FlGlobalAPIServiceRegistry
} = require('fl/framework/api_services');
const { TestActor, TestDatumOne, TestDatumTwo } = require('../../utils/test_models');
const { FlFrameworkListItemAPIService } = require('fl/framework/list_api_services');

const axios = require('axios');
const AxiosMockAdapter = require('axios-mock-adapter');

const myaxios = axios.create();
const expect = chai.expect;

const LIST_2 = {
    type: "Fl::Framework::List::List",
    api_root: "/fl/framework/list/lists",
    url_path: "fl_framework_list_list_path/2",
    fingerprint: "Fl::Framework::List::List/2",
    id: 2,
    created_at: "2019-03-04T03:08:46.133Z",
    updated_at: "2019-03-04T03:08:46.154Z",
    caption: "list caption - 2",
    title: "list title - 2",
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

const LIST_ITEM_21 = {
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
};

const LIST_ITEM_10 = {
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
};

const axmock = new AxiosMockAdapter(myaxios);
axmock
    .onGet('/fl/framework/lists/2/list_items.json').reply(function(cfg) {
	return new Promise(function(resolve, reject) {
	    resolve([ 200,
		      JSON.stringify({
			  list_items: [ LIST_ITEM_21, LIST_ITEM_10 ],
			  _pg: { _s: 20, _c: 2, _p: 2 }
		      })
		    ]);
	});
    })

    .onGet(`/fl/framework/list_items/${LIST_ITEM_21.id}.json`).reply(function(cfg) {
	return new Promise(function(resolve, reject) {
	    resolve([ 200, JSON.stringify({ list_item: LIST_ITEM_21 }) ]);
	});
    })

    .onGet(`/fl/framework/list_items/${LIST_ITEM_10.id}.json`).reply(function(cfg) {
	return new Promise(function(resolve, reject) {
	    resolve([ 200, JSON.stringify({ list_item: LIST_ITEM_10 }) ]);
	});
    })

    .onPatch(`/fl/framework/list_items/${LIST_ITEM_21.id}.json`).reply(function(cfg) {
	return new Promise(function(resolve, reject) {
	    let jdata = JSON.parse(cfg.data);
	    let li = _.merge({}, LIST_ITEM_21, jdata.fl_framework_list_item);
	    resolve([ 200, JSON.stringify({ list_item: li }) ]);
	});
    })

;

const SRV_CFG = {
    axios: myaxios
};

describe('FlFrameworkListItemAPIService', function() {
    it('should be registered with FlClassManager', function() {
	expect(FlClassManager.get_class('FlFrameworkListItemAPIService')).to.not.be.null;
    });

    it('should be registered with FlGlobalAPIServiceRegistry', function() {
	expect(FlGlobalAPIServiceRegistry.service_info('Fl::Framework::List::ListItem')).to.be.an.instanceof(Object);

	let FlFrameworkListItemAPIService = FlClassManager.get_class('FlFrameworkListItemAPIService');
	let FlFrameworkListList = FlClassManager.get_class('FlFrameworkListList');
	let list = new FlFrameworkListList(LIST_2);
	let srv = FlGlobalAPIServiceRegistry.create('Fl::Framework::List::ListItem', list, SRV_CFG);

	expect(srv).to.be.an.instanceof(FlFrameworkListItemAPIService);
	expect(srv.list).to.be.an.instanceof(FlFrameworkListList);
	expect(srv.list.id).to.eql(LIST_2.id);
    });

    context(':index', function() {
	it('should return a list of objects', function() {
	    let FlFrameworkListItemAPIService = FlClassManager.get_class('FlFrameworkListItemAPIService');
	    let FlFrameworkListList = FlClassManager.get_class('FlFrameworkListList');
	    let FlFrameworkListListItem = FlClassManager.get_class('FlFrameworkListListItem');
	    let list = new FlFrameworkListList(LIST_2);
	    let srv = FlGlobalAPIServiceRegistry.create('Fl::Framework::List::ListItem', list, SRV_CFG);

	    return srv.index()
		.then(function(data) {
		    expect(data).to.be.an.instanceof(Array);
		    expect(data.length).to.eql(2);
		    expect(data[0].id).to.eql(LIST_ITEM_21.id);
		    expect(data[1].id).to.eql(LIST_ITEM_10.id);

		    FlModelFactory.defaultFactory().cache().remove(data);
		    
		    return Promise.resolve(true);
		});
	});
    });
    
    context(':show', function() {
	it('should return a known object', function() {
	    let FlFrameworkListItemAPIService = FlClassManager.get_class('FlFrameworkListItemAPIService');
	    let FlFrameworkListList = FlClassManager.get_class('FlFrameworkListList');
	    let FlFrameworkListListItem = FlClassManager.get_class('FlFrameworkListListItem');
	    let list = new FlFrameworkListList(LIST_2);
	    let srv = FlGlobalAPIServiceRegistry.create('Fl::Framework::List::ListItem', list, SRV_CFG);

	    return srv.show(LIST_ITEM_21.id)
		.then(function(data) {
		    expect(data).to.be.an.instanceof(FlFrameworkListListItem);
		    expect(data.id).to.eql(LIST_ITEM_21.id);

		    FlModelFactory.defaultFactory().cache().remove(data);
		    
		    return Promise.resolve(true);
		});
	});

	it('should not need a list resource', function() {
	    let FlFrameworkListItemAPIService = FlClassManager.get_class('FlFrameworkListItemAPIService');
	    let FlFrameworkListListItem = FlClassManager.get_class('FlFrameworkListListItem');
	    let srv = FlGlobalAPIServiceRegistry.create('Fl::Framework::List::ListItem', null, SRV_CFG);

	    return srv.show(LIST_ITEM_10.id)
		.then(function(data) {
		    expect(data).to.be.an.instanceof(FlFrameworkListListItem);
		    expect(data.id).to.eql(LIST_ITEM_10.id);

		    FlModelFactory.defaultFactory().cache().remove(data);
		    
		    return Promise.resolve(true);
		});
	});

	it('should support model instances as id', function() {
	    let FlFrameworkListItemAPIService = FlClassManager.get_class('FlFrameworkListItemAPIService');
	    let FlFrameworkListList = FlClassManager.get_class('FlFrameworkListList');
	    let FlFrameworkListListItem = FlClassManager.get_class('FlFrameworkListListItem');
	    let list = new FlFrameworkListList(LIST_2);
	    let srv = FlGlobalAPIServiceRegistry.create('Fl::Framework::List::ListItem', list, SRV_CFG);
	    let li = new FlFrameworkListListItem(LIST_ITEM_21);

	    return srv.show(li)
		.then(function(data) {
		    expect(data).to.be.an.instanceof(FlFrameworkListListItem);
		    expect(data.id).to.eql(LIST_ITEM_21.id);

		    FlModelFactory.defaultFactory().cache().remove(data);
		    
		    return Promise.resolve(true);
		});
	});

	it('should convert owner, list, and listed object data to objects', function() {
	    let FlFrameworkListItemAPIService = FlClassManager.get_class('FlFrameworkListItemAPIService');
	    let FlFrameworkListList = FlClassManager.get_class('FlFrameworkListList');
	    let FlFrameworkListListItem = FlClassManager.get_class('FlFrameworkListListItem');
	    let srv = FlGlobalAPIServiceRegistry.create('Fl::Framework::List::ListItem', null, SRV_CFG);

	    return srv.show(LIST_ITEM_10.id)
		.then(function(data) {
		    expect(data).to.be.an.instanceof(FlFrameworkListListItem);
		    expect(data.id).to.eql(LIST_ITEM_10.id);
		    expect(data.owner).to.not.be.null;
		    expect(data.owner).to.be.an.instanceof(TestActor);
		    expect(data.list).to.not.be.null;
		    expect(data.list).to.be.an.instanceof(FlFrameworkListList);
		    expect(data.listed_object).to.not.be.null;
		    expect(data.listed_object).to.be.an.instanceof(TestDatumOne);

		    return srv.show(LIST_ITEM_21.id);
		})
		.then(function(data) {
		    expect(data).to.be.an.instanceof(FlFrameworkListListItem);
		    expect(data.id).to.eql(LIST_ITEM_21.id);
		    expect(data.owner).to.not.be.null;
		    expect(data.owner).to.be.an.instanceof(TestActor);
		    expect(data.list).to.not.be.null;
		    expect(data.list).to.be.an.instanceof(FlFrameworkListList);
		    expect(data.listed_object).to.not.be.null;
		    expect(data.listed_object).to.be.an.instanceof(TestDatumTwo);

		    FlModelFactory.defaultFactory().cache().remove(data);
		    
		    return Promise.resolve(true);
		});
	});
    });

    context(':update', function() {
	it('should return an updated object', function() {
	    let FlFrameworkListItemAPIService = FlClassManager.get_class('FlFrameworkListItemAPIService');
	    let FlFrameworkListList = FlClassManager.get_class('FlFrameworkListList');
	    let FlFrameworkListListItem = FlClassManager.get_class('FlFrameworkListListItem');
	    let list = new FlFrameworkListList(LIST_2);
	    let srv = FlGlobalAPIServiceRegistry.create('Fl::Framework::List::ListItem', list, SRV_CFG);

	    return srv.update(LIST_ITEM_21.id, { wrapped: { name: 'new.name' } })
		.then(function(data) {
		    expect(data).to.be.an.instanceof(FlFrameworkListListItem);
		    expect(data.id).to.eql(LIST_ITEM_21.id);
		    expect(data.name).to.eql('new.name');

		    FlModelFactory.defaultFactory().cache().remove(data);
		    
		    return Promise.resolve(true);
		});
	});

	it('should support model instances as id', function() {
	    let FlFrameworkListItemAPIService = FlClassManager.get_class('FlFrameworkListItemAPIService');
	    let FlFrameworkListList = FlClassManager.get_class('FlFrameworkListList');
	    let FlFrameworkListListItem = FlClassManager.get_class('FlFrameworkListListItem');
	    let list = new FlFrameworkListList(LIST_2);
	    let srv = FlGlobalAPIServiceRegistry.create('Fl::Framework::List::ListItem', list, SRV_CFG);
	    let li = new FlFrameworkListListItem(LIST_ITEM_21);

	    return srv.update(li, { wrapped: { name: 'new.name' } })
		.then(function(data) {
		    expect(data).to.be.an.instanceof(FlFrameworkListListItem);
		    expect(data.id).to.eql(LIST_ITEM_21.id);
		    expect(data.name).to.eql('new.name');

		    FlModelFactory.defaultFactory().cache().remove(data);
		    
		    return Promise.resolve(true);
		});
	});
    });
});
