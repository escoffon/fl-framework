const _ = require('lodash');
const { FlExtensions, FlClassManager } = require('fl/framework/object_system');
const {
    FlModelBase, FlModelCache, FlModelFactory, FlGlobalModelFactory
} = require('fl/framework/model_factory');

function _clear_ext(name) {
    if (_.isString(name))
    {
	if (name != 'FlBaseModelExtension') delete FlExtensions._named_registry[name];
    }
    else
    {
	let xr = { };
	let x = FlExtensions.lookup('FlBaseModelExtension', false);
	if (!_.isNil(x)) xr.FlBaseModelExtension = x;
	FlExtensions._named_registry = xr;
    }
};
    
function _clear_class(name) {
    if (_.isString(name))
    {
	if ((name != 'FlRoot') && (name != 'FlModelBase')) delete FlClassManager._class_registry[name];
    }
    else
    {
	let r = FlClassManager.get_class('FlRoot');
	let b = FlClassManager.get_class('FlModelBase');
	let cr = { };
	if (!_.isNil(r)) cr.FlRoot = r;
	if (!_.isNil(b)) cr.FlModelBase = b;
	    
	FlClassManager._class_registry = cr;
    }
};
    
function _clear_model_services(factory, name) {
    if (_.isNil(factory)) factory = FlGlobalModelFactory;
    
    if (_.isString(name))
    {
	factory.unregister(name);
    }
    else
    {
	factory._model_services = { };
    }
};

module.exports = {
    clear_ext: _clear_ext,
    clear_class: _clear_class,
    clear_model_services: _clear_model_services
};
