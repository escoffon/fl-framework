/**
 * @ngdoc module
 * @name fl.lists
 * @requires fl.model_factory
 * @description
 * Support for framework list models.
 */

const _ = require('lodash');
const { FlExtensions, FlClassManager } = require('./object_system');
const {
    FlModelBase, FlModelCache, FlModelFactory, FlGlobalModelFactory
} = require('./model_factory');

/**
 * @ngdoc type
 * @name FlFrameworkListList
 * @module fl.lists
 * @requires FlModelBase
 * @description Model class for `Fl::Framework::List::List`.
 *  This model encapsulate an instance of a framework list object.
 */

let FlFrameworkListList = FlClassManager.make_class({
    name: 'FlFrameworkListList',
    superclass: 'FlModelBase',
    /**
     * @ngdoc method
     * @name FlFrameworkListList#constructor
     * @description The constructor; called during `new` creation.
     *  Calls the superclass implementation, passing the value of *data*.
     *
     * @param {Object} data Model data.
     */

    initializer: function(data) {
	this.__super_init('FlModelBase', data);
    },
    instance_properties: {
    },
    instance_methods: {
	/**
	 * @ngdoc method
	 * @name FlFrameworkListList#refresh
	 * @description
	 *  Refresh the state of the instance based on the contents
	 *  of the hash representation of a list object.
	 * 
	 * @param {Object} data An object containing a representation of the 
	 *  list object. This representation may be partial.
	 */

	refresh: function(data) {
	    this.__super('FlModelBase', 'refresh', data);

	    if (_.isObject(data.owner))
	    {
	    	this.owner = FlModelFactory.defaultFactory().create(data.owner);
	    }

	    if (_.isArray(data.list_items))
	    {
	    	this.list_items = FlModelFactory.defaultFactory().create(data.list_items);
	    }
	}
    },
    class_methods: {
	/**
	 * @ngdoc method
	 * @name FlFrameworkListList#create
	 * @classmethod
	 * @description
	 *  Factory for a list object.
	 * 
	 * @param {Object} data The representation of the list object.
	 * 
	 * @return {FlFrameworkListList} Returns an instance of {@sref FlFrameworkListList}.
	 */

	create: function(data) {
	    return FlClassManager.modelize('FlFrameworkListList', data);
	}
    },
    extensions: [ ]
});

/**
 * @ngdoc type
 * @name FlFrameworkListListItem
 * @module fl.lists
 * @requires FlModelBase
 * @description Model class for `Fl::Framework::List::ListItem`
 *  This model encapsulate an instance of a list item.
 */

let FlFrameworkListListItem = FlClassManager.make_class({
    name: 'FlFrameworkListListItem',
    superclass: 'FlModelBase',
    /**
     * @ngdoc method
     * @name FlFrameworkListListItem#constructor
     * @description The constructor; called during `new` creation.
     *  Calls the superclass implementation, passing the value of *data*.
     *
     * @param {Object} data Model data.
     */

    initializer: function(data) {
	this.__super_init('FlModelBase', data);
    },
    instance_properties: {
    },
    instance_methods: {
	/**
	 * @ngdoc method
	 * @name FlFrameworkListListItem#refresh
	 * @description
	 *  Refresh the state of the instance based on the contents
	 *  of the hash representation of a Fl::Framework::List::ListItem object.
	 * 
	 * @param {Object} data An object containing a representation of the 
	 *  list item object. This representation may be partial.
	 */

	refresh: function(data) {
	    this.__super('FlModelBase', 'refresh', data);

	    if (_.isObject(data.list))
	    {
	    	this.list = FlModelFactory.defaultFactory().create(data.list);
	    }

	    if (_.isObject(data.listed_object))
	    {
	    	this.listed_object = FlModelFactory.defaultFactory().create(data.listed_object);
	    }

	    if (_.isObject(data.owner))
	    {
	    	this.owner = FlModelFactory.defaultFactory().create(data.owner);
	    }

	    if (_.isObject(data.state_updated_by))
	    {
	    	this.state_updated_by = FlModelFactory.defaultFactory().create(data.state_updated_by);
	    }
	}
    },
    class_methods: {
	/**
	 * @ngdoc method
	 * @name FlFrameworkListListItem#create
	 * @classmethod
	 * @description
	 *  Factory for a list item object.
	 * 
	 * @param {Object} data The representation of the list item object.
	 * 
	 * @return {FlFrameworkListListItem} Returns an instance of {@sref FlFrameworkListListItem}.
	 */

	create: function(data) {
	    return FlClassManager.modelize('FlFrameworkListListItem', data);
	}
    },
    extensions: [ ]
});

FlGlobalModelFactory.register('fl.active_storage', [
    { service: FlFrameworkListList, class_name: 'Fl::Framework::List::List' },
    { service: FlFrameworkListListItem, class_name: 'Fl::Framework::List::ListItem' }
]);

module.exports = { FlFrameworkListList, FlFrameworkListListItem };
