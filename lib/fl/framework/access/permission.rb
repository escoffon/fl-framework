module Fl::Framework::Access
  # The base class for permissions.
  # This class contains the core functionality for permission descriptors; subclasses, when used,
  # are typically just namespaces and don't add or modify functionality.
  # For example:
  #
  # ```
  # class MyPermission < Fl::Framework::Access::Permission
  #  NAME = :my_permission
  #  GRANTS = [ Fl::Framework::Access::Permission::Read::NAME ]
  #
  #  def initialize(ext)
  #    @ext = ext
  #    super(NAME, GRANTS)
  #  end
  #
  #  attr_reader :ext
  # end
  #
  # myp = MyPermission.new('additional data')
  # ```
  # The `MyPermission.new` call registers `MyPermission` with the permission registry.
  #
  # #### Cumulative (forwarded) permissions
  #
  # A permission can grant other permissions by listing them in the constructor's *grants* argument.
  # Access checkers need to consider this "forwarding" of grants when determining if an actor has
  # access to a given asset.
  # For example, the standard {Permission::Edit} permission defines *grants* to have value
  # `[ :read, :write ]`; an access checker for the **:write** permission should grant access if
  # **:edit** is granted.
  #
  # Use the class methods {.permission_grantors} and {.grantors_for_permission} to support forwarded access
  # checks.
  #
  # #### Standard permission classes
  #
  # The following permission classes are registered:
  #
  # - {Permission::Read} grants read only access.
  # - {Permission::Write} grants write only access.
  # - {Permission::Delete} grants delete only access.
  # - {Permission::Edit} grants read and write access to assets.
  # - {Permission::Manage} grants read, write, and delete access to assets.

  class Permission
    # Exception raised when a permission name is doubly registered.

    class Duplicate < RuntimeError
      # Initializer.
      #
      # @param permission [Fl::Framework::Access::Permission] The duplicate permission.
      # @param msg [String] Message to pass to the superclass implementation.
      #  If `nil`, a standard message is created from the permission name.

      def initialize(permission, msg = nil)
        @permission = permission
        msg = I18n.tx('fl.framework.access.permission.duplicate',
                      name: permission.name, class_name: permission.class.name) unless msg.is_a?(String)
        super(msg)
      end

      # The duplicate permission.
      # @return [Fl::Framework::Access::Permission] Returns the *permission* argument to the constructor.

      attr_reader :permission
    end

    # Exception raised when a permission name is not registered.

    class Missing < RuntimeError
      # Initializer.
      #
      # @param name [Symbol,String] The missing permission name.
      # @param msg [String] Message to pass to the superclass implementation.
      #  If `nil`, a standard message is created from the permission name.

      def initialize(name, msg = nil)
        @name = name.to_sym
        msg = I18n.tx('fl.framework.access.permission.missing', name: name) unless msg.is_a?(String)
        super(msg)
      end

      # The name of the permission.
      # @return [Symbol] Returns the name of the permission.

      attr_reader :name
    end
    
    @_permission_registry = {}
    @_permission_grants = nil

    # Get the permission name for this class.
    #
    # @return [Symbol] Returns the name of the permission implemented by this class.

    def self.name()
      @_permission_name
    end
    
    # Register a permission object.
    # There is no real need to call this method, since {#initialize} does this automatically.
    #
    # @param permission [Fl::Framework::Access::Permission] The permission to register.
    #
    # @raise [Fl::Framework::Access::Permission::Duplicate] Raised if *name* is already registered.

    def self.register(permission)
      k = permission.name.to_sym
      raise Fl::Framework::Access::Permission::Duplicate.new(permission) if @_permission_registry.has_key?(k)
      @_permission_registry[k] = permission

      # A registration invalidates the permission grants registry
      _invalidate_permission_grants()
    end

    # Look up a permission in the registry.
    #
    # @param name [Symbol,String] The permission name.
    #
    # @return [Fl::Framework::Access:Permission] Returns an instance of (a subclass of)
    #  {Fl::Framework::Access:Permission} if *name* is registered, `nil` otherwise.
      
    def self.lookup(name)
      @_permission_registry[name.to_sym]
    end

    # Remove a permission from the registry.
    #
    # @param name [Symbol,String] The permission name.

    def self.unregister(name)
      n = name.to_sym
      if @_permission_registry.has_key?(n)
        p = @_permission_registry.delete(n)
      end

      # A deregistration invalidates the permission grants registry
      _invalidate_permission_grants()
    end

    # Return the names of all permissions in the registry.
    #
    # @return [Array<Symbol>] Returns an array containing the names of all currently registered
    #  permissions.
      
    def self.registered()
      @_permission_registry.map { |k, v| k.to_sym }
    end

    # Return the grantors for permissions in the registry.
    # Compound permissions (those with a nonempty {Permission#grants} array) include other permissions.
    # This method returns a map of the permissions that grant another one.
    #
    # @return [Hash] Returns a hash where the keys are permission names, and the values are arrays that
    #  list the other permissions that grant it.
      
    def self.permission_grantors()
      _permission_grants()
    end

    # Return the grantorss for a given permission in the registry.
    #
    # @param permission [Symbol,String,Fl::Framework::Access::Permission,Class] The permission whose grants
    #  to get. The value of this parameter is described in {Fl::Framework::Access::Helper.permission_name}.
    #
    # @return [Array<Symbol>] Returns an array that lists the permission that grant *name*.
      
    def self.grantors_for_permission(permission)
      # g = class_variable_get(:@_permission_grants)
      # k = name.to_sym
      # (g.has_key?(k)) ? g[k] : [ ]

      k = Fl::Framework::Access::Helper.permission_name(permission)
      g = _permission_grants
      (g.has_key?(k)) ? g[k] : [ ]
    end
      
    # Initializer.
    # The initializer registers the instance with the permission registry.
    #
    # Note that, because the initializer calls {.register}, which in turn calls {#grants},
    # any permissions listed in *grants* must have already been registered.
    #
    # @param name [Symbol,String] The name of the permission; this value must be unique for all
    #  permission instances.
    # @param grants [Array<Symbol,String,Fl::Framework::Access::Permission,Class>] An array containing
    #  the list other permissions that are also granted by *name*. For example, a **:manage** permission
    #  may grant **:read**, **:write**, and **:delete**.
    #  The element values are as described in {Fl::Framework::Access::Helper.permission_name}.
    #
    # @raise [Fl::Framework::Access::Permission::Duplicate] Raised if *name* is already registered.
    #
    # @raise [Fl::Framework::Access::Permission::Missing] Raised if any of the permissions listed
    #  in *grants* are not yet registered.

    def initialize(name, grants = [ ])
      @name = name.to_sym
#      @grants_raw = (grants.is_a?(Array)) ? grants.map { |g| Fl::Framework::Access::Helper.permission_name(g) } : [ ]
      @grants = (grants.is_a?(Array)) ? grants.map { |g| Fl::Framework::Access::Helper.permission_name(g) } : [ ]

      rv = super()
        
      self.class.instance_variable_set(:@_permission_name, name)
      Fl::Framework::Access::Permission.register(self)

      rv
    end

    # The permission name.
    # @return [Symbol] Returns the name of the permission.

    attr_reader :name

    # The grants list.
    # This is the normalized value of the *grants* argument to {#initialize}, and it lists the permission
    # that this permission grants.
    # @return [Array<Symbol>] Returns the list of permissions granted by this permission.

    attr_reader :grants

    # # Get the expanded grants list.
    # # The list is generated lazily, but at the time the method is first called all the permissions
    # # in the original unexpanded list must have been registered.
    # #
    # # @return [Array<Symbol>] Returns the list of permissions granted by this permission.
    # #
    # # @raise [Fl::Framework::Access::Permission::Missing] Raised if a listed permission has not been
    # #  registered.

    # def grants()
    #   self.class.grants_for_permission(self.name)
    # end

    # Get the grantor list.
    # This is the list of permission that grant this permission; it is the (global) reverse of the
    # {#grants} list.
    #
    # @return [Array<Symbol>] Returns the list of permissions that grant this permission.

    def grantors()
      Fl::Framework::Access::Permission.grantors_for_permission(self.name)
    end

    private

    def self._invalidate_permission_grants()
      @_permission_grants = nil
    end

    def self._permission_grants()
      _rebuild_permission_grants unless @_permission_grants.is_a?(Hash)
      @_permission_grants
    end

    def self._rebuild_permission_grants()
      @_permission_grants = {}
      @_permission_registry.each do |pk, pv|
        _register_grants(pv.grants, pk)
      end

      # a bit hoakey, but we need to remove spurious grants to self that may have been (well, were...)
      # introduced by _register_grants

      @_permission_grants.each { |gk, gv| gv.delete(gk) }
      
      @_permission_grants
    end

    def self._register_grants(gl, pn)
      @_permission_grants[pn] = [ ] unless @_permission_grants.has_key?(pn)
      @_permission_grants[pn] |= [ pn ]
      gl.each do |gn|
        @_permission_grants[gn] |= [ pn ]
        gp = lookup(gn)
        _register_grants(gp.grants, pn) if gp && (gp.grants.count > 0)
      end
    end
    
    # def _expand_grants()
    #   @grants_raw.reduce([ ]) do |acc, n|
    #     p = Fl::Framework::Access::Permission.lookup(n)
    #     raise Fl::Framework::Access::Permission::Missing.new(n) if p.nil?

    #     acc |= [ p.name ] | p.grants
    #     acc
    #   end
    # end
  end

  # The **:read** permission class.
  # This permission grants read only access to assets.
  
  class Permission::Read < Permission
    # The permission name.
    NAME = :read

    # dependent permissions granted by **:read**.
    GRANTS = [ ]

    # Initializer.
    def initialize()
     super(NAME, GRANTS)
    end
  end

  Permission::Read.new

  # The **:write** permission class.
  # Note that this permission grants write only access to assets; for read and write access,
  # use {#Permission::Edit}.
  
  class Permission::Write < Permission
    # The permission name.
    NAME = :write

    # dependent permissions granted by **:write**.
    GRANTS = [ ]

    # Initializer.
    def initialize()
     super(NAME, GRANTS)
    end
  end

  Permission::Write.new

  # The **:delete** permission class.
  # This permission grants delete only access to assets; for additional read and write access,
  # use {#Permission::Manage}.
  
  class Permission::Delete < Permission
    # The permission name.
    NAME = :delete

    # dependent permissions granted by **:delete**.
    GRANTS = [ ]

    # Initializer.
    def initialize()
     super(NAME, GRANTS)
    end
  end

  Permission::Delete.new

  # The **:edit** permission class.
  # This permission grants read and write access to assets.
  
  class Permission::Edit < Permission
    # The permission name.
    NAME = :edit

    # dependent permissions granted by **:edit**.
    GRANTS = [ :read, :write ]

    # Initializer.
    def initialize()
     super(NAME, GRANTS)
    end
  end

  Permission::Edit.new

  # The **:manage** permission class.
  # This permission grants read, write, and delete access to assets.
  
  class Permission::Manage < Permission
    # The permission name.
    NAME = :manage

    # dependent permissions granted by **:manage**.
    GRANTS = [ :edit, :delete ]

    # Initializer.
    def initialize()
     super(NAME, GRANTS)
    end
  end

  Permission::Manage.new
end
