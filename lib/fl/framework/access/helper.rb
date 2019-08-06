module Fl::Framework::Access
  # Helpers for the access module.
  
  module Helper
    # Enable access control support for a class.
    # Use this method to add access control support to an existing class:
    #
    # ```
    # class TheClass
    #   # class definition
    # end
    #
    # class MyAccessChecker < Fl::Framework::Access::Checker
    #   def access_check(permission, actor, asset, context = nil)
    #     return access_check_algorithm_value
    #   end
    # end
    #
    # Fl::Framework::Access::Helper.add_access_control(TheClass, MyAccessChecker.new, owner: :my_owner_method)
    # ```
    # If the class has already enabled access control, the operation is not performed.
    #
    # @param klass [Class] The class object where access control is enabled.
    # @param checker [Fl::Framework::Access::Checker] The checker to use for access control.
    # @param cfg [Hash] A hash containing configuration parameters. See the documentation for
    #  {Fl::Framework::Access::Access::ClassMacros.has_access_control}.

    def self.add_access_control(klass, checker, *cfg)
      unless klass.has_access_control?
        klass.send(:include, Fl::Framework::Access::Access)
        klass.send(:has_access_control, checker, *cfg)
      end
    end

    # Add support for actor (grantee) access functionality to a class.
    # Use this method to "mark" an existing class as a grantee of permissions:
    #
    # ```
    # class TheClass < ActiveRecord::Base
    #   # class definition
    # end
    #
    #
    # Fl::Framework::Access::Helper.add_access_actor(TheClass)
    # ```
    # If the class has already enabled actor support, the operation is not performed.
    #
    # @param klass [Class] The class object where actor support is enabled.

    def self.add_access_actor(klass)
      unless klass.included_modules.include?(Fl::Framework::Access::Actor)
        klass.send(:include, Fl::Framework::Access::Actor)
      end
    end

    # Add support for target (grantor) access functionality to a class.
    # Use this method to "mark" an existing class as a grantor of permissions:
    #
    # ```
    # class TheClass < ActiveRecord::Base
    #   # class definition
    # end
    #
    #
    # Fl::Framework::Access::Helper.add_access_target(TheClass)
    # ```
    # If the class has already enabled target support, the operation is not performed.
    #
    # @param klass [Class] The class object where target support is enabled.

    def self.add_access_target(klass)
      unless klass.included_modules.include?(Fl::Framework::Access::Target)
        klass.send(:include, Fl::Framework::Access::Target)
      end
    end

    # Get a permission.
    # If the *permission* argument is a string or a symbol, it is looked up in the permission registry.
    # If it is an instance of {Fl::Framework::Access::Permission}, it is returned as is.
    #
    # @param permission [Symbol,String,Fl::Framework::Access::Permission] The permission to get.
    #
    # @return [Fl::Framework::Access::Permission,nil] Returns the permission if it can resolve it;
    #  otherwise, it returns `nil`.
    
    def self.permission(permission)
      if permission.is_a?(Fl::Framework::Access::Permission)
        permission
      elsif permission.is_a?(Symbol) | permission.is_a?(String)
        Fl::Framework::Access::Permission.lookup(permission)
      else
        nil
      end
    end

    # Get the name of a permission.
    # If the *permission* argument is a string or a symbol, it is returned as a symbol.
    # If it is an instance of {Fl::Framework::Access::Permission}, its
    # {Fl::Framework::Access::Permission#name} is returned.
    # Otherwise, if it is a class, the method checks if it is a subclass of
    # {Fl::Framework::Access::Permission}, and if so it returns its {Fl::Framework::Access::Permission.name}
    # value.
    #
    # @param permission [Symbol,String,Fl::Framework::Access::Permission,Class] The permission whose name
    #  to get.
    #
    # @return [Symbol,nil] Returns the permission name if it can resolve it; otherwise, it returns `nil`.
    
    def self.permission_name(permission)
      case permission
      when Symbol
        permission
      when String
        permission.to_sym
      when Fl::Framework::Access::Permission
        permission.name
      when Class
        sc = permission
        until sc.nil?
          return permission.name if sc.name == Fl::Framework::Access::Permission.name
          sc = sc.superclass
        end

        nil
      else
        nil
      end
    end

    # Build the permission mask from a list of permissions.
    # Combines the individual permissions' permission masks into a single one by ORing them.
    # The method also takes a single integer, which is returned as, as a sort of syntactic sugar.
    #
    # @param permissions [Integer,Array<Integer,Symbol,String,Fl::Framework::Access::Permission,Class>] The
    #  permissions whose masks to combine. An integer value is returned as is.
    #  Each element in the array is converted to a permission name as documented
    #  for {.permission_name}, and the permission mask obtained from the registry.
    #  If the element is an integer, it is used as is.
    #
    # @return [Integer] Returns the permission mask.
    
    def self.permission_mask(permission)
      pl = (permission.is_a?(Array)) ? permission : [ permission ]
      pl.reduce(0) do |mask, e|
        if e.is_a?(Integer)
          mask |= e
        else
          n = self.permission_name(e)
          mask |= Fl::Framework::Access::Permission.permission_mask(n)
        end
        mask
      end
    end
  end
end
