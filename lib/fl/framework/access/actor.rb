module Fl::Framework::Access
  # A module used to inject actor functionality.
  # Include this module in classes that are granted permissions by others; instances of this class are
  # placed in the `granted_to` attribute of a {Fl::Framework::Access::Grant} object.
  
  module Actor
    # The instance methods injected into the including class.

    module InstanceMethods
      # Find an access grant for a given target and `self`.
      # This is a convenience wrapper around {Fl::Framework::Access::Grant.find_grant} that uses `self`
      # as the *actor* parameter.
      #
      # @param target [ActiveRecord::Base,String] The target for which to check for grants.
      #  A string value is assumed to be a fingerprint.
      #
      # @return [Fl::Framework::Access::Grant,nil] Returns the grant object containing the permissions
      #  currently granted to `self` on *target*. If no grant object was found, returns `nil`.
      
      def find_grant_for(target)
        Fl::Framework::Access::Grant.find_grant(self, target)
      end

      protected
      
      # Callback before an instance is destroyed: remove all grants associated with the instance.

      def delete_actor_grants()
        Fl::Framework::Access::Grant.delete_grants_for_actor(self)
      end
    end

    # Perform actions when the module is included.
    # - Injects the instance methods to manage grants.
    # - Registers {InstanceMethods::delete_target_grants} as a **:before_destroy** callback.
    
    def self.included(base)
      base.include InstanceMethods

      base.send(:before_destroy, :delete_actor_grants)

      base.instance_eval do
      end

      base.class_eval do
      end
    end
  end
end
