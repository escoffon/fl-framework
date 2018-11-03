/**
 * @ngdoc module
 * @name fl.api_services
 * @requires fl.model_factory
 * @description
 * Floopstreet API service base functionality.
 * This module exports the following functionality:
 */

const _ = require('lodash');
const axios = require('axios');
const { FlExtensions, FlClassManager } = require('fl/framework/object_system');
const {
    FlModelBase, FlModelCache, FlModelFactory, FlGlobalModelFactory
} = require('fl/framework/model_factory');

/**
 * @ngdoc type
 * @name FlAPIService
 * @module fl.api_services
 * @requires FlModelFactory
 * @description FlAPIService is the base class for API services.
 *  This class implements the common functionality for communicating with a standard Rails resource
 *  API: it defines methods to trigger the standard actions **index**, **show**, **update**, and
 *  **destroy**. Clients then provide a configuration that customizes this generic implementation.
 *
 *  There are two ways to use this service:
 *  1. Create an instance of FlAPIService with appropriate configuration.
 *  2. Define a subclass that encapsulates the configuration and optionally also adds API-specific
 *     entry points.
 *
 * For example, say there is a server API at `/my/data` that manages instances
 *  of `My::Datum`; this API is a standard CRUD RESTful API as generated by Rails.
 *  The API returns data as a JSON object containing the keys `data` or `datum`
 *  (the former when collections are returned as by the :index action, the latter
 *  when single items are returned). Sumbission parameters are encapsulated in the
 *  `my_datum` key. You can create a service to communicate with this API like this:
 *  ```
 *  let srv = new FlAPIService({
 *    root_url: '/my/data',
 *    namespace: 'my_datum',
 *    data_names: [ 'data', 'datum' ]
 *  });
 *  ```
 *  Alternatively, you can define a subclass of FlAPIService:
 *  ```
 *  let MyAPIService = FlClassManager.make_class({
 *    name: 'MyAPIService',
 *    superclass: 'FlAPIService',
 *    initializer: function(srv_cfg) {
 *      this.__super_init('FlAPIService', {
 *        root_url: '/my/data',
 *        namespace: 'my_datum',
 *        data_names: [ 'data', 'datum' ]
 *      }, srv_cfg);
 *    }
 *  });
 *
 *  let srv = new MyAPIService();
 *  ```
 *  The second approach lets you define additional methods that implement triggering of
 *  custom APIs. It also makes it possible to register service classes with {@sref FlAPIServiceRegistry}.
 *
 *  To get a list of data:
 *  ```
 *  let srv = new MyDatumAPIService();
 *  srv.index().then(function(data) {
 *    // do something with the returned data
 *  },
 *  function(r) {
 *     // report error
 *  });
 *  ```
 *  Or to update an item:
 *  ```
 *  let id = getItemId();
 *  let srv = new MyDatumAPIService();
 *  srv.update(id, { prop1: 'prop1 value' }).then(function(data) {
 *    // do something with the returned data
 *  },
 *  function(r) {
 *    // report error
 *  });
 *  ```
 *  Note that the submission data are *not* wrapped in the namespace: this step is
 *  left to the service object.
 *
 *  #### Automatic generation of data model instances
 *
 *  FlAPIService assumes that the API returns data objects as JSON representations; for example, it
 *  assumes that the response for the **index** action looks something like this:
 *  ```
 *  {
 *    "data":[
 *      {"type":"My::Datum","api_root":"/my/data","url_path":"/my/data/1","fingerprint":"My::Datum/1","id":1,"created_at":"...","updated_at":"..","value1":"...","value2":"..."},
 *      {"type":"My::Datum","api_root":"/my/data","url_path":"/my/data/2","fingerprint":"My::Datum/2","id":2,"created_at":"...","updated_at":"..","value1":"...","value2":"..."}
 *    ],
 *    "_pg":{"_c":2,"_s":20,"_p":2}
 *  }
 *  ```
 *  The **index** code uses {@sref FlModelFactory} to instantiate an array of model objects from the array
 *  of JSON structures returned in the **data** property, and therefore a model class should have been
 *  registered for the `My::Model` type. (If no such class has been registered, `null` is placed in
 *  the array.)
 *
 * #### The API protocol
 *
 * This service assumes that the server implements a specific API behavior. For successful responses,
 * the body of the response is a JSON object that contains at least one property, the data being
 * returned. The name of this property is API-dependent, and the value depends on the request action.
 * For **index**, it is an array of JSON representation of data objects; for **create** and **update**,
 * it is a single JSON representation of a data object; and for **delete** it is a status as described
 * below. Additional properties *may* be present; for example, **index** also returns pagination
 * controls in the **_pg** property.
 *
 * On error, the response returns an status code in the 400 or 500 range, and the body is a JSON
 * representation of the error.
 *
 * ##### The status object
 *
 * The status object as returned by the methods contains the following properties:
 * - If the repsonse body contains a status object:
 *   - **status** is the status identifier as returned by the API.
 *   - **message** is a message associated with the status.
 *   - **details** is an optional object containing additional status information.
 * - Otherwise:
 *   - **status** is the status code from the response (typically in the 200 range, but could be in the
 *     300s).
 *   - **message** is the message associated with the HTTP status code.
 *
 * ##### The error object
 *
 * - If the repsonse body contains an error object:
 *   - **status** is the status identifier as returned by the API.
 *   - **message** is a message associated with the status.
 *   - **details** is an optional object containing additional error information.
 * - Otherwise:
 *   - **status** is the status code from the response, which should be in the 400 or 500 range.
 *   - **message** is the message associated with the HTTP status code.
 *
 * ##### The pagination info
 *
 * Pagination info is an object that tracks the current state of a multipage query.
 * It contains the following properties:
 * - **_s** How many results to return per page.
 * - **_p** The next page to fetch, starting at 1 for the first page.
 * - **_c** How many results were returned by the last query. Note that, if `_c < _s`, then
 *   no more results are available.
 *
 * #### Webpack
 *
 * API service code relies on registered data model classes to generate model instances of the
 * appropriate type. Unfortunately, {@sref Webpack} does not add a source file if its exports
 * are nowhere imported by the other files in the package. As a consequence, the data model class
 * associated with a given API service is not registered, and the data returned by **index** and
 * **show** is `null`. For example, the `MyAPIService` class listed above expects to retrieve
 * instances of the `My::Model` type, via the `MyModel` data model class:
 * ```
 * FlGlobalAPIServiceRegistry.register('my.services', { MyAPIService: 'My::Model' });
 * ```
 * If no other sources import `MyModel`, then a call to {@sref FlAPIService#show} attempts to
 * load the model class for `My::Model`, finds none, and returns `null`.
 *
 * Typically, the source file for a data model includes registration code like this:
 * ```
 * FlGlobalModelFactory.register('my.models', [
 *   { service: MyModel, class_name: 'My::Model' }
 * ]);
 * ```
 * To ensure that the source file is packed (and therefore the class is registered), add the
 * following statement in the source for `MyAPIService`:
 * ```
 * const { MyModel } = require('my/models/my_model');
 * ```
 * (or equivalent).
 */

let FlAPIService = FlClassManager.make_class({
    name: 'FlAPIService',
    /**
     * @ngdoc method
     * @name FlAPIService#constructor
     * @description The constructor; called during `new` creation.
     * 
     * @param {Object} api_cfg Configuration for the API object.
     * @property {String} api_cfg.root_url The root URL; see the properties section for details.
     * @property {String} api_cfg.namespace The parameter namespace for create/update calls.
     *  Parameters will be wrapped inside this namespace; for example, if the namespace is `ns`,
     *  then the submission parameters `{ p1: 1, p2: 2 }` are actually sent to the server as
     *  `{ ns: { p1: 1, p2: 2 } }`.
     * @property {Array} api_cfg.data_names An array of property names that contain
     *  response data. These are typically the singular and plural version of the
     *  object name. For the example above, use `[ 'datum', 'data' ]`; for an API that returns user
     *  objects, use `[ 'user', 'users' ]`.
     * @property {Array} api_cfg.pg_names An array of property names that contain the
     *  pagination controls. The service looks up each in the order in which they are listed
     *  in the array, and loads the first match in the pagination controls.
     *  The default value is the array `[ '_pg' ]`.
     * @param {Object} srv_cfg Configuration for the service. A few standard properties in the
     *  object are described below; various services may include additional ones.
     *  See the properties section for details.
     * @property {Object} srv_cfg.axios The underlying {@sref Axios} service to use for HTTP requests.
     *  By default, an instance of Axios is created and installed, but one can provide a custom
     *  instance if desired. This feature is often used for testing, to install a mocked version of Axios.
     * @property {Object} srv_cfg.model_factory The instance of {@sref FlModelFactory} to use to create
     *  model instances.
     *  Defaults to {@sref FlGlobalModelFactory}.
     */
    initializer: function(api_cfg, srv_cfg) {
	this._api_cfg = (_.isObject(api_cfg)) ? api_cfg : { };
	this._srv_cfg = (_.isObject(srv_cfg)) ? srv_cfg : { };

	this._http_service = (_.isNil(this._srv_cfg.axios)) ? axios : this._srv_cfg.axios;
	this._pg_names = (_.isArray(this._api_cfg.pg_names)) ? this._api_cfg.pg_names : [ '_pg' ];
	this._model_factory = (_.isNil(this._srv_cfg.model_factory)) ? FlGlobalModelFactory : this._srv_cfg.model_factory;

	this._showDidSucceed = null;
	this.pagination_controls = 'init';
    },
    instance_properties: {
	/**
	 * @ngdoc property
	 * @name FlAPIService#root_url
	 * @description Getter for *root_url* that looks into the configuration.
	 * @return {String} Returns the value of the *root_url* property in the API config object.
	 */

	root_url: {
	    get: function() {
		return this._api_cfg.root_url;
	    }
	},

	/**
	 * @ngdoc property
	 * @name FlAPIService#namespace
	 * @description Getter for *namespace* that looks into the configuration.
	 * @return {String} Returns the value of the *namespace* property in the API config object.
	 */

	namespace: {
	    get: function() {
		return this._api_cfg.namespace;
	    }
	},

	/**
	 * @ngdoc property
	 * @name FlAPIService#data_names
	 * @description Getter for *data_names* that looks into the configuration.
	 * @return {String} Returns the value of the *data_names* property in the API config object.
	 */

	data_names: {
	    get: function() {
		return this._api_cfg.data_names;
	    }
	},

	/**
	 * @ngdoc property
	 * @name FlAPIService#response
	 * @description Getter for the last response returned by the server.
	 * @return {Object} Returns the last response returned by the server.
	 */

	response: {
	    get: function() {
		return this._response;
	    }
	},

	/**
	 * @ngdoc property
	 * @name FlAPIService#pagination_controls
	 * @description Accessors for pagination_controls.
	 *  The getter returns a hash containing key/value pairs:
	 *   - *_s* is an integer containing the page size (how many results are returned by the query).
	 *   - *_p* is an integer containing the 1-based index of the _next_ page to load.
	 *     For example, a value of 3 indicates that this is the _third_ page loaded.
	 * 
	 *  The setter takes a hash with the same two key/value pairs, the string *init*, or
	 *  *null*; a value of *init* sets the default control values; any other value 
	 *  (including  *null*) disables use of the pagination controls.
	 */

	pagination_controls: {
	    get: function() {
		return this._pagination_controls;
	    },
	    set: function(pg) {
		if (_.isObject(pg))
		{
		    this._pagination_controls = pg;
		}
		else if (_.isString(pg) && (pg == 'init'))
		{
		    this._pagination_controls = this.initial_pagination_controls;
		}
		else
		{
		    this._pagination_controls = null;
		}
	    }
	},

	/**
	 * @ngdoc property
	 * @name FlAPIService#initial_pagination_controls
	 * @description Get the initial pagination_controls.
	 * 
	 * @return {Object} Returns a hash containing key/value pairs:
	 *  - *_s* is an integer containing the page size (how many results are returned by
	 *    the query). The value returned is 20.
	 *  - *_p* is an integer containing the 1-based index of the _next_ page to load.
	 *    For example, a value of 3 indicates that this is the _third_ page loaded.
	 *    The value returned is 1.
	 */

	initial_pagination_controls: {
	    get: function() {
		return { _s: 20, _p: 1 };
	    }
	}
    },
    instance_methods: {
	/**
	 * @ngdoc method
	 * @name FlAPIService#index
	 * @description Make an :index call by calling `axios.get` against the root URL.
	 *
	 * @param {Object} [config] Configuration object to pass to `axios.get`; this object is
	 *  merged into the default HTTP configuration object.
	 *
	 * @return On success, returns a promise containing the response data.
	 *  Clients will register the error handler.
	 */

	index: function(config) {
	    let self = this;

	    return this._http_service.get(this.root_url + '.json', this._make_index_config(config))
		.then(function(r) {
		    self._response = r;
		    self._set_pagination_controls(r);
		    return self._model_factory.create(self._response_data(r));
		});
	},

	/**
	 * @ngdoc method
	 * @name FlAPIService#setShowDidSucceed
	 * @description Register a callback for the :show action.
	 *  This function is called on a successful :show action; it takes one argument, the
	 *  model object created from the response from the `axios.get` call.
	 * 
	 * @param {Function} cb A function that will be installed as the :show callback.
	 *  Set it to `null` to disable it (this is the default value).
	 *  This function can modify the model object before it is returned by the :show action.
	 */

	setShowDidSucceed: function(cb) {
	    this._showDidSucceed = cb;
	},

	/**
	 * @ngdoc method
	 * @name FlAPIService#show
	 * @description Make a :show call by calling `axios.get` against the root URL/:id.
	 *
	 * @param {Integer|String} id A string or integer containing the identifier to append to
	 *  the root URL.
	 * @param {Object} [config] Configuration object to pass to `axios.get`; this object is
	 *  merged into the default HTTP configuration.
	 *
	 * @return On success, returns the response data converted to a model object.
	 *  Clients will register the error handler.
	 */

	show: function(id, config) {
	    let self = this;
	    return this._http_service.get(this.root_url + '/' + id + '.json', this._make_config(config))
		.then(function(r) {
		    self._response = r;

		    let model = self._model_factory.create(self._response_data(r));
		    if (_.isFunction(self._showDidSucceed))
		    {
			self._showDidSucceed.call(self, model);
		    }
		    return model;
		});
	},

	/**
	 * @ngdoc method
	 * @name FlAPIService#process
	 * @description Make a processing call; this is the method that the high level
	 *  processing methods (*create*, *update*, *delete*) call.
	 *  A processing call causes the state of the server to change: a :create, :update, or
	 *  :destroy call (which are executed via a *post*, *patch*, or *delete* method,
	 *  respectively).
	 * 
	 *  The method checks if the _data_ contain file objects, and if so sets up the `axios`
	 *  service to submit data in multipart form.
	 *
	 * @param {String} method The method to use: *post*, *patch* (*put*), *delete*.
	 * @param {String} url The URL of the server endpoint.
	 * @param {Object} data The data to submit to the server; see above for a discussion of
	 *  how the data are submitted.
	 * @param {Object} [config] Configuration object to pass to axios.patch; this object is
	 *  merged into the default HTTP configuration.
	 *
	 * @return On success, returns a promise containing the response data.
	 *  Clients will register the error handler.
	 *  Returns the promise returned by axios.post, axios.patch, or axios.delete.
	 */

	process: function(method, url, data, config) {
	    let self = this;
	    let api_data = data;
	    let cfg = this._make_config(config);
	    let args;

	    if (self._has_file_item(api_data))
	    {
		self._add_content_type(cfg, undefined);
		let flat = { };
		self._flatten_data(api_data, flat, '');
		api_data = self._form_data(flat);
	    }

	    let m;
	    if (method == 'post')
	    {
		m = this._http_service.post;
		args = [ url, api_data, cfg ];
	    }
	    else if (method == 'patch')
	    {
		m = this._http_service.patch;
		args = [ url, api_data, cfg ];
	    }
	    else if (method == 'put')
	    {
		m = this._http_service.put;
		args = [ url, api_data, cfg ];
	    }
	    else if (method == 'delete')
	    {
		m = this._http_service.delete;
		args = [ url, cfg ];
	    }
	    else
	    {
		m = null;
	    }

	    if (m)
	    {
		return m.apply(this._http_service, args);
	    }
	    else
	    {
		return Promise.reject('unsupported processing method: ' + method);
	    }
	},

	/**
	 * @ngdoc method
	 * @name FlAPIService#create
	 * @description Make a :create call by calling `axios.post` against the root URL.
	 *  The actual call is to {@sref FlAPIService#process}, which then dispatches to `axios.post`.
	 *
	 * @param {Object} data The data to submit to the server; these data will be placed inside
	 *  the service's namespace, so that the actual data will be in a
	 *  property named after the namespace.
	 * @param {Object} [config] Configuration object to pass to axios.post; this object is
	 *  merged into the default HTTP configuration.
	 *
	 * @return On success, returns a promise containing the response data.
	 *  Clients will register the error handler.
	 *  Returns the promise returned by `axios.post`.
	 */

	create: function(data, config) {
	    let self = this;
	    let api_data = data;
	    if (this.namespace)
	    {
		api_data = {};
		api_data[this.namespace] = data;
	    }
	    else
	    {
		api_data = data;
	    }
	    return this.process('post', this.root_url + '.json', api_data, config)
		.then(function(r) {
		    self._response = r;
		    return self._model_factory.create(self._response_data(r));
		});
	},

	/**
	 * @ngdoc method
	 * @name FlAPIService#update
	 * @description Make a :update call by calling `axios.patch` against the root URL/:id.
	 *  The actual call is to {@sref FlAPIService#process}, which then dispatches to `axios.patch`.
	 *
	 * @param {Integer|String} id An integer or string containing the identifier to append to
	 *  the root URL.
	 * @param {Object} data The data to submit to the server; these data will be placed inside
	 *  the service's namespace, so that the actual data will be in a
	 *  property named after the namespace.
	 * @param {Object} [config] Configuration object to pass to axios.patch; this object is
	 *  merged into the default HTTP configuration.
	 *
	 * @return On success, returns a promise containing the response data.
	 *  Clients will register the error handler.
	 *  Returns the promise returned by `axios.patch`.
	 */

	update: function(id, data, config) {
	    let self = this;
	    let api_data = data;
	    if (this.namespace)
	    {
		api_data = {};
		api_data[this.namespace] = data;
	    }
	    else
	    {
		api_data = data;
	    }
	    return this.process('patch', this.root_url + '/' + id + '.json', api_data, config)
		.then(function(r) {
		    self._response = r;
		    return self._model_factory.create(self._response_data(r));
		});
	},

	/**
	 * @ngdoc method
	 * @name FlAPIService#delete
	 * @description Make a :destroy call by calling `axios.delete` against the root URL/:id.
	 *  The actual call is to {@sref FlAPIService#process}, which then dispatches to `axios.delete`.
	 *
	 * @param {Integer|String} id An integer or string containing the identifier to append to
	 *  the root URL.
	 * @param {Object} [config] Configuration object to pass to axios.delete; this object is
	 *  merged into the default HTTP configuration.
	 *
	 * @return On success, returns a promise containing the response data.
	 *  Clients will register the error handler.
	 *  Returns the promise returned by `axios.delete`.
	 */

	delete: function(id, config) {
	    let self = this;
	    return this.process('delete', this.root_url + '/' + id + '.json', { }, config)
		.then(function(r) {
		    self._response = r;
		    return self.response_status(r);
		});
	},

	/**
	 * @ngdoc method
	 * @name FlAPIService#_make_config
	 * @description Build configuration parameters for a call to Axios.
	 * 
	 *  Subclasses likely won't need to override this method.
	 *
	 * @param {Object} [config] Configuration object to pass to Axios; this object is
	 *  merged into the default HTTP configuration.
	 *
	 * @return {Object} Returns a configuration object where the values in config have been
	 *  merged into this._srv_cfg.
	 */

	_make_config: function(config) {
	    if (!_.isObject(config)) config = {};

	    return _.merge({}, config);
	},

	/**
	 * @ngdoc method
	 * @name FlAPIService#_make_index_config
	 * @description Build configuration parameters for an :index call to Axios.
	 *  The method first calls *_make_config*, and then tags on the pagination
	 *  controls if they are enabled.
	 * 
	 *  Subclasses likely won't need to override this method.
	 *
	 * @param {Object} [config] Configuration object to pass to axios; this object is
	 *  merged into the default HTTP configuration.
	 *
	 * @return {Object} Returns a configuration object where the values in _config_ have been
	 *  merged into the default HTTP configuration.
	 *  Also, the pagination controls are placed in the
	 *  submission parameters if enabled. The first key name in the pagination control keys
	 *  array is used as the key.
	 */

	_make_index_config: function(config) {
	    let cfg = this._make_config(config);
	    if (this.pagination_controls)
	    {
		let k = this._pg_names[0];

		if (!_.isObject(cfg.params)) cfg.params = { };

		cfg.params[k] = this.pagination_controls;
	    }

	    return cfg;
	},

	/**
	 * @ngdoc method
	 * @name FlAPIService#_set_pagination_controls
	 * @description Look for the pagination controls in the response data and extract them.
	 *  This method looks up all registered names for pagination controls and loads them
	 *  on the first hit.
	 * 
	 * @param {Object} r The response object.
	 */

	_set_pagination_controls: function(r) {
	    let self = this;
	    let data = r.data;
	    _.forEach(this._pg_names, function(k, idx) {
		if (!_.isUndefined(data[k]))
		{
		    self.pagination_controls = data[k];
		    return;
		}
	    });
	},

	/**
	 * @ngdoc method
	 * @name FlAPIService#response_status
	 * @description Extract a status object from a successful response.
	 *
	 * @param {Object} r The response.
	 * 
	 * @return {Object} Returns an object containing a status report:
	 *  - *:status* The response status.
	 *  - *:message* A string containing a status message.
	 */
		    
	response_status: function(r) {
	    let s = {
		status: r.status
	    };

	    let rd = r.data;
	    if (_.isObject(rd) && _.isObject(rd._status))
	    {
		s = rd._status;
	    }
	    else
	    {
		s.message = r.statusText;
	    }

	    return s;
	},

	/**
	 * @ngdoc method
	 * @name FlAPIService#response_error
	 * @description Extract or generate an error object from a failed response.
	 *  The method tries to detect the type of response: a general HTTP response,
	 *  an API error status, or an exception raised.
	 *
	 * @param {Object} r The response.
	 * 
	 * @return {Object} Returns an object containing an error report:
	 *  - *:status* The response status.
	 *  - *:message* A string containing an error message.
	 */
		    
	response_error: function(r) {
	    let err = { };
	    if (r.status)
	    {
		err.status = r.status;

		let rd = r.data;
		if (_.isObject(rd) && _.isObject(rd._error))
		{
		    err = rd._error;
		}
		else
		{
		    err.message = r.statusText;
		}
	    }
	    else if (r.message)
	    {
		err.message = r.message;

		if (r.stack)
		{
		    err.details = {
			stack: r.stack.split("\n")
		    };
		}
	    }
	    else
	    {
		err.message = "response error";
	    }

	    return err;
	},

	/**
	 * @ngdoc method
	 * @name FlAPIService#_response_data
	 * @description Given a (successful) response, return the response data.
	 *  The default implementation iterates over the values in *data_names*,
	 *  looking for a property by that name in *response.data*; the first hit
	 *  is returned.
	 * 
	 *  Most subclasses won't need to override this method.
	 * 
	 * @param {Object} response The response data.
	 */

	_response_data: function(response) {
	    let ary = this._api_cfg.data_names;

	    if (ary)
	    {
		let idx;
		let len = ary.length;
		let name;

		for (idx=0 ; idx < len ; idx++)
		{
		    name = ary[idx];
		    if (response.data[name])
		    {
			return response.data[name];
		    }
		}
	    }

	    return null;
	},

	_has_file_item: function(data) {
	    let k;
	    let v;
	    let self = this;

	    for (k in data)
	    {
		v = data[k];

		// File is defined in a browser environment, but not in Node.js.
		// We skip this test if File is not defined

		try {
		    if (v instanceof(File)) return true;
		} catch (x) {
		}
		
		if (_.isObject(v))
		{
		    if (self._has_file_item(v))
		    {
			return true;
		    }
		}
	    }

	    return false;
	},

	_flatten_data: function(data, f, root) {
	    let self = this;
	    
	    _.forEach(data, function(v, k) {
		let fk = (root.length > 0) ? (root + '[' + k + ']') : k;

		if (v instanceof(File))
		{
		    f[fk] = v;
		}
		else if (_.isObject(v))
		{
		    self._flatten_data(v, f, fk);
		}
		else
		{
		    f[fk] = v;
		}
	    });
	},

	_form_data: function(data) {
	    let fd = new FormData();
	    let self = this;
	    
	    _.forEach(data, function(v, k) {
		if (v instanceof(File))
		{
		    fd.append(k, v, v.name);
		}
		else
		{
		    fd.append(k, v);
		}
	    });
	    return fd;
	},

	_add_content_type: function(cfg, ct) {
	    if (_.isObject(cfg.headers))
	    {
		cfg.headers['Content-Type'] = ct;
	    }
	    else
	    {
		cfg.headers = { 'Content-Type': ct };
	    }
	}
    },
    class_methods: {
    },
    extensions: [ ]
});

/**
 * @ngdoc service
 * @name FlAPIServiceRegistry
 * @module fl.api_services
 * @requires FlModelFactory
 * @description FlAPIServiceRegistry is a service that implements a registry of API
 *  services. Use this registry to associate a given API service with the object type
 *  it manages.
 */

let FlAPIServiceRegistry = FlClassManager.make_class({
    name: 'FlAPIServiceRegistry',
    initializer: function() {
	this._services = { };
    },
    instance_properties: {
    },
    instance_methods: {
	/**
	 * @ngdoc method
	 * @name FlAPIServiceRegistry#register
	 * @description Register API services provided by a module for model factory services.
	 *  This function is typically called after an {@sref FlAPIService} subclass is defined,
	 *  to associate data types with API service classes.
	 *  For example, a module named **my_service** defines the API service `MyAPIService`,
	 *  which implements the API client for `My::Datum` resources.
	 *  The registration looks like this:
	 *  ```
	 *  let MyDatum = FlClassRegistry.make_class({
	 *    ...
	 *  });
	 *  FlGlobalModelFactory.register('my_service', [
	 *    { service: MyDatum, class_name: 'My::Datum' }
	 *  ]);
	 *
	 *  let MyAPIService = FlClassRegistry.make_class({
	 *    ...
	 *  });
	 *
	 *  FlGlobalAPIServiceRegistry.register('my_service', {
	 *    'MyAPIService': 'My::Datum'
	 *  });
	 *  ```
	 * 
	 * @param {String} module The module name.
	 * @param {Object} services A hash mapping the name of API services provided by the module
	 *  to model service names. Properties are API service names, and their values the
	 *  corresponding model service type name.
	 */

	register: function(module, services) {
	    let self = this;
	    
	    _.forEach(services, function(sv, sk) {
		let k = self._normalize_name(sv);
		if (self._services[k])
		{
		    console.log("(FlAPIServiceRegistry): model service '"
				+ sv + "' is already registered with API service '"
				+ self._services[k].api_service + "'");
		}
		self._services[k] = { module: module, api_service: sk };
	    });
	},

	/**
	 * @ngdoc method
	 * @name FlAPIServiceRegistry#unregister
	 * @description Remove an API service from the registry.
	 *
	 * @param {string} name The service name.
	 */

	unregister: function(name) {
	    let kk = null;
	    let srv = _.find(this._services, function(s, k) {
		kk = k;
		return s.api_service == name;
	    });

	    if (kk) delete this._services[kk];
	},

	/**
	 * @ngdoc method
	 * @name FlAPIServiceRegistry#service_info
	 * @description Given a model service name, return info about the corresponding API service.
	 *  Model services are subclasses of {@sref FlModelBase}.
	 *
	 * @param {String} name The model service name (for example, `MyDatum`), or the model
	 *  type name (for example, `My::Datum`) from an object's hash representation;
	 *  the colons will be stripped off.
	 *
	 * @return {Object} If *name* is registered, it returns an object
	 *  containing two properties: *module* is the module where the service resides,
	 *  and *api_service* is the name of the API service.
	 */

	service_info: function(name) {
	    let n = this._normalize_name(name);

	    return (_.isNil(this._services[n])) ? null : this._services[n];
	},

	/**
	 * @ngdoc method
	 * @name FlAPIServiceRegistry#create
	 * @description Given a model service name, return an instance of the
	 *  corresponding API service.
	 *  Model services are subclasses of {@sref FlModelBase}.
	 *  This method uses the class registry to fetch the service and return a new instance.
	 *
	 * @param {String} name The model service name (for example, `MyDatum`), or the model
	 *  type name (for example, `My::Datum`) from an object's hash representation;
	 *  the colons will be stripped off.
	 * @param {Object} [cfg] Configuration options to pass to the API service. The
	 *  contents are service specific; see the description of the *srv_cfg* argument for the
	 *  constructor in {@sref FlAPIService}.
	 *
	 * @return {Object} If *name* is registered, it returns an instance
	 *  of the corresponding API service.
	 */

	create: function(name, cfg) {
	    var info = this.service_info(name);
	    if (info)
	    {
		let srv = FlClassManager.get_class(info.api_service);
		if (_.isNil(srv))
		{
		    console.log("(FlAPIServiceRegistry): API service '" + info.api_service
				+ "' is not registered with the class manager");
		    return null;
		}

		return new srv(cfg);
	    }
	    else
	    {
		console.log("(FlAPIServiceRegistry): no API service for modelizer '" + name + "'");
		return null;
	    }
	},
	
	_normalize_name: function(s) {
	    return s.replace(/::/g, '');
	}
    },
    class_methods: {
    },
    extensions: [ ]
});

/**
 * @ngdoc service
 * @name FlGlobalAPIServiceRegistry
 * @module fl.api_services
 * @description
 * The global model factory. This is an instance of {@sref FlAPIServiceRegistry} that is globally accessible
 * and can be used as the applicationwide API service registry.
 */

const FlGlobalAPIServiceRegistry = new FlAPIServiceRegistry();

module.exports = { FlAPIService, FlAPIServiceRegistry, FlGlobalAPIServiceRegistry };
