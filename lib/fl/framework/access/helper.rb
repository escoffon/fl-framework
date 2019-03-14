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

    # Get the name of a permission.
    # If the *permission* argument is a string or a symbol, it is returned as a symbol.
    # If it is an instance of {Fl::Framework::Access::Permission}, its
    # {Fl::Framework::Access::Permission#name} is returned.
    # Otherwise, if it is a class, the method checks if it is a subclss of
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
  end
end
