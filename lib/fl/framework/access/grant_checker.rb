module Fl::Framework::Access
  # A permission checker based on the grants data.
  # This checker uses the grants data from {Fl::Framework::Access::Grant} to control access to objects.
  
  class GrantChecker < Checker
    # Initializer.

    def initialize()
      super()
    end

    # Configure the including class.
    # The method includes {Fl::Framework::Access::Target} in *base*.
    #
    # @param base [Class] The class object in whose context the `has_access_control` macro is executed.
    
    def configure(base)
      unless base.included_modules.include?(Fl::Framework::Access::Target)
        base.send(:include, Fl::Framework::Access::Target)
      end
    end

    # Run an access check.
    # The access check is based on the {Fl::Framework::Asset::AccessGrant} database: it finds all grants
    # to *actor* containing the permission mask for `permission`; if at least one grant is returned,
    # the permission is granted, otherwise it is denied.
    #
    # @param permission [Symbol,String,Fl::Framework::Access::Permission] The requested permission;
    #  this is usually the name of a permission registered with the permission registry, but it could
    #  also be passed as a permission instance.
    # @param actor [Object] The actor requesting *permission*.
    # @param asset [Object] The target of the request (the asset for which *permission* is requested).
    # @param context [any] The context in which to do the check; this is arbitrary data to pass to the
    #  checker parameter.
    #
    # @return [Boolean,nil] Returns `true` if granted, `false` if not granted.

    def access_check(permission, actor, asset, context = nil)
      g = Fl::Framework::Access::Grant.find_grant(actor, asset)
      if g.nil?
        false
      elsif (g.grants & Fl::Framework::Access::Permission::Owner::BIT) != 0
        # *actor* has ownership, so grant permission unconditionally
        true
      else
        pm = Fl::Framework::Access::Permission.permission_mask(permission)
        ((g.grants & pm) == pm) ? true : false
      end
    end
    
    # The instance methods injected into the including class by {#configure}.

    module InstanceMethods
    end
  end
end
