@ngdoc content
@name The Fl Framework API
@id content.api.main
@isindex
@description

## The Fl Framework API

The API is broken down into a collection of modules, which are essentially just namespaces.

#### Core functionality

These are all namespaces; they are not packaged as Angular modules, and therefore are available
outside the realm of an AngularJS application.

- {@sref fl.object_system} is the core module for Floopstreet JS code. It includes functions
  and objects for managing class hierarchies and object instantiation:
  - {@sref FlClassManager} is used to manage the class hierarchy
    ({@sref FlClassManager.make_class}) and create instances of registered classes
    ({@sref FlClassManager.instance_factory} and {@sref FlClassManager.modelize}).

  The root of the class hierarchy, {@sref FlRoot}, is also described in this module, although
  technically it does not reside in this namespace.
  - {@sref FlExtensions} contains code to support the mix-in (extension) features
    of classes defined via {@sref FlClassManager.make_class}.
- {@sref fl.model_factory} is the module to manage data model services. These are classes that
  encapsulate a data object returned by (Rails) API calls.
  It includes the following entities:
  - {@sref FlModelBase} is the base class for model services.
  - {@sref FlModelCache} is a service that manages a cache of model instances.
  - {@sref FlModelFactory} is a service that manages creation of model instances from model data.
    It also defines the global model factory service {@sref FlGlobalModelFactory}.
