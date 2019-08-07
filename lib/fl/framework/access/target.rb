module Fl::Framework::Access
  # A module used to inject target functionality.
  # Include this module in classes that need to grant permissions to others; instances of this class are
  # placed in the `target` attribute of a {Fl::Framework::Access::Grant} object.
  
  module Target
    # The instance methods injected into the including class.

    module InstanceMethods
      # Find an access grant to a given actor and `self`.
      # This is a convenience wrapper around {Fl::Framework::Access::Grant.find_grant} that uses
      # `self` as the target.
      #
      # @param actor [ActiveRecord::Base,String] The actor for which to check for grants.
      #  A string value is assumed to be a fingerprint.
      #
      # @return [Fl::Framework::Access::Grant,nil] Returns the grant object containing the permissions
      #  currently granted to *actor* on `self`. If no grant object was found, returns `nil`.
      
      def find_grant_to(actor)
        Fl::Framework::Access::Grant.find_grant(actor, self)
      end

      # Add an access grant to `self`.
      # If the grant is not already present, the method creates a new {Fl::Framework::Access::Grant}
      # instance.
      # This is a convenience wrapper around {Fl::Framework::Access::Grant.add_grant} that uses
      # `self` as the target.
      #
      # @param permissions [Integer, Array<Symbol,String,Fl::Framework::Access::Permission,Class>] The
      #  permissions whose masks to combine, using {Fl::Framework::Access::Helper.permission_mask}.
      # @param actor [ActiveRecord::Base,String] The actor to which *permissions* is granted.
      #  A string value is assumed to be a fingerprint.
      #
      # @return [Fl::Framework::Access::Grant] Returns the grant object.
      
      def grant_permission_to(permissions, actor)
        Fl::Framework::Access::Grant.add_grant(permissions, actor, self)
      end

      # Remove a set of permissions.
      # This is a convenience wrapper around {Fl::Framework::Access::Grant.remove_grant} that uses
      # `self` as the target.
      #
      # @param permissions [Integer, Array<Symbol,String,Fl::Framework::Access::Permission,Class>] The
      #  permissions whose masks to combine, using {Fl::Framework::Access::Helper.permission_mask}.
      # @param actor [ActiveRecord::Base,String] The actor from which *permissions* is revoked.
      #  A string value is assumed to be a fingerprint.
      
      def revoke_permission_from(permission, actor)
        Fl::Framework::Access::Grant.remove_grant(permission, actor, self)
      end

      protected
      
      # Callback after an instance is created: add the owner grant.
      # This method adds a {Permission::Owner} grant to the owner of `self`; this grant is used
      # by the query methods to find assets owned by a given actor.

      def create_owner_grant()
        if self.respond_to?(:owner) && !self.owner.nil?
          Fl::Framework::Access::Grant.add_grant(Fl::Framework::Access::Permission::Owner::BIT,
                                                 self.owner, self)
        end
      end
      
      # Callback before an instance is destroyed: remove all grants associated with the instance.

      def delete_target_grants()
        Fl::Framework::Access::Grant.delete_grants_for_target(self)
      end
    end

    # Perform actions when the module is included.
    # - Injects the instance methods to manage grants.
    # - Registers {InstanceMethods::delete_target_grants} as a **:before_destroy** callback.
    # - Registers {InstanceMethods::create_owner_grant} as a **:after_create** callback.
    
    def self.included(base)
      base.include InstanceMethods

      base.send(:before_destroy, :delete_target_grants)
      base.send(:after_create, :create_owner_grant)

      base.instance_eval do
      end

      base.class_eval do
      end
    end
  end
end
