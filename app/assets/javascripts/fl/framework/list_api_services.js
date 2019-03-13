/**
 * @ngdoc module
 * @name fl.list_api_services
 * @requires fl.api_services
 * @description
 * API services for list models.
 */

const _ = require('lodash');
const { FlExtensions, FlClassManager } = require('fl/framework/object_system');
const {
    FlModelBase, FlModelCache, FlModelFactory, FlGlobalModelFactory
} = require('fl/framework/model_factory');
const {
    FlAPIService, FlAPIServiceRegistry, FlGlobalAPIServiceRegistry
} = require('fl/framework/api_services');

// This is imported so that webpack pulls in the sources, or we run the risk of not loading it
const { FlFrameworkListList, FlFrameworkListListItem } = require('fl/framework/list_models');

const LIST_API_CFG = {
    root_url_template: '/fl/framework/lists',
    namespace: 'fl_framework_list',
    data_names: [ 'list', 'lists', 'list_item' ]
};

const LIST_ITEM_API_CFG = {
    root_url_template: '/fl/framework/lists/${list.id}/list_items',
    shallow_root_url_template: '/fl/framework/list_items',
    namespace: 'fl_framework_list_item',
    data_names: [ 'list_item', 'list_items' ]
};

/**
 * @ngdoc type
 * @name FlFrameworkListAPIService
 * @module fl.list_api_services
 * @requires FlAPIService
 * @description API service class for communicationg with the list API.
 *  This API service manages interactions with the API for `Fl::Framework::List::List` objects.
 */

let FlFrameworkListAPIService = FlClassManager.make_class({
    name: 'FlFrameworkListAPIService',
    superclass: 'FlAPIService',
    /**
     * @ngdoc method
     * @name FlFrameworkListAPIService#constructor
     * @description The constructor; called during `new` creation.
     *  Calls the superclass implementation, passing the following API configuration:
     *  ```
     *  {
     *    root_url_template: '/fl/framework/lists',
     *    namespace: 'fl_framework_list',
     *    data_names: [ 'list', 'lists' ]
     *  }
     *  ```
     *  and passing *srv_cfg* as the second argument.
     *
     * @param {Object} srv_cfg Configuration for the service.
     */

    initializer: function(srv_cfg) {
	this.__super_init('FlAPIService', LIST_API_CFG, srv_cfg);
    },
    instance_properties: {
    },
    instance_methods: {
	/**
	 * @ngdoc method
	 * @name FlFrameworkListAPIService#add_object
	 * @description Adds an object to a list. Calling `axios.post` against the **add_object** URL.
	 *
	 * @param {Integer|String|Object} id A string or integer containing the identifier to insert in
	 *  the request URL. You can also pass an instance of {@sref FlFrameworkListList} whose `id` property
	 *  will be used for the identifier.
	 * @param {Object} data The data to submit to the server. The object contains two properties,
	 *  **wrapped** and **unwrapped**. See {@sref FlAPIService#_wrap_data} for details.
	 * @param {Object} [config] Configuration object to pass to `axios.get`; this object is
	 *  merged into the default HTTP configuration object.
	 *
	 * @property {Integer} data.wrapped.listed_object The listable to add.
	 *  The value is a string containing an object fingerprint, or an object whose **fingerprint**
	 *  property is used as the value. This parameter is mandatory.
	 * @property {Integer} data.wrapped.name A string containing the name of the corresponding list item.
	 *  This parameter is optional.
	 * @property {Integer} data.unwrapped.to_hash An object containing configuration parameters for
	 *  the server method that generates the hash representation of returned models.
	 *
	 * @return On success, returns a promise containing the list item object.
	 *  On error, returns a promise that rejects with the response object.
	 */

	add_object: function(id, data, config) {
	    let self = this;
	    let api_data = (_.isObject(data)) ? data : { };

	    return this.post(this.url_path_for('add_object', id), this._wrap_data(api_data), config)
		.then(function(r) {
		    return Promise.resolve(self.modelFactory.create(self._response_data(r)));
		})
		.catch(function(e) {
		    return Promise.reject(_.isObject(e.response) ? e.response : e);
		});
	},

	/**
	 * @ngdoc method
	 * @name OpoAdvisorSessionAPIService#url_path_for
	 * @description Overrides the base implementation to add support for the `add_object` action.
	 *  It forwards to the superclass for the standard Rails actions `index`, `create`, `show`,
	 *  `update`, and `destroy`.
	 *
	 * @param {String} action The name of the action.
	 * @param {Object|Integer} [target] Some actions need a target object whose identifier to place
	 *  in the path. The value is either an object that contains a **id** property, or the
	 *  identifier itself.
	 * 
	 * @return {String|null} Returns the URL path for the action; if *action* is not supported,
	 *  returns `null`.
	 */

	url_path_for: function(action, target) {
	    let root_path = this._expand_url_template(this.root_url_template);
	    
	    if (action == 'add_object')
	    {
		return root_path + '/add_object.json';
	    }
	    else
	    {
		return this.__super('FlAPIService', 'url_path_for', action, target);
	    }
	}
    },
    class_methods: {
    },
    extensions: [ ]
});

/**
 * @ngdoc type
 * @name FlFrameworkListItemAPIService
 * @module fl.list_api_services
 * @requires FlNestedAPIService
 * @description API service class for communicationg with the list item API.
 *  This API service manages interactions with the API for `Fl::Framework::List::ListItem` objects.
 */

let FlFrameworkListItemAPIService = FlClassManager.make_class({
    name: 'FlFrameworkListItemAPIService',
    superclass: 'FlNestedAPIService',
    /**
     * @ngdoc method
     * @name FlFrameworkListItemAPIService#constructor
     * @description The constructor; called during `new` creation.
     *  Calls the superclass implementation, passing the following API configuration:
     *  ```
     *  {
     *    root_url_template: '/fl/framework/lists/${list.id}/list_items',
     *    shallow_root_url_template: '/fl/framework/list_items',
     *    namespace: 'fl_framework_list',
     *    data_names: [ 'list', 'lists' ]
     *  }
     *  ```
     *  and passing *srv_cfg* as the second argument.
     *
     * @param {Integer|FlFrameworkListList} list The object or object identifier for the list that
     *  defines the nesting resource for the API.
     * @param {Object} srv_cfg Configuration for the service.
     */

    initializer: function(list, srv_cfg) {
	this.__super_init('FlNestedAPIService', LIST_ITEM_API_CFG, srv_cfg);

	this.list = list;
    },
    instance_properties: {
    },
    instance_methods: {
    },
    class_methods: {
    },
    extensions: [ ]
});

FlGlobalAPIServiceRegistry.register('fl.list_api_services', {
    FlFrameworkListAPIService: 'Fl::Framework::List::List',
    FlFrameworkListItemAPIService: 'Fl::Framework::List::ListItem'
});

module.exports = { FlFrameworkListAPIService, FlFrameworkListItemAPIService };
