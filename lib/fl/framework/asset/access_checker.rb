module Fl::Framework::Asset
  # The asset permission checker.
  # This access checker uses the access grants table to control access to assets.
  
  class AccessChecker < Fl::Framework::Access::Checker
    # Initializer.

    def initialize()
      super()
    end

    # Configure the including class.
    #
    # @param base [Class] The class object in whose context the `has_access_control` macro is executed.
    #
    # @raise [RuntimeError] Raises an exception if *base* is not an asset.
    
    def configure(base)
      raise I18n.tx('fl.framework.asset.checker.not_an_asset', class_name: base.name) unless base.asset?

      # We eager load :actor and :data_object because they are the two items we'll need for determining
      # access
      
      base.send(:has_many, :grants, -> { includes(:actor, :data_object).order('id') }, {
                  as: :data_object,
                  class_name: 'Fl::Framework::Asset::AccessGrant',
                  dependent: :destroy
                })
      base.send(:after_create, :create_owner_grant)
      # see the documentation for :clear_grants_hack for why we use :prepend
      base.send(:before_destroy, :clear_grants_hack, prepend: true)
      base.send(:include, Fl::Framework::Asset::AccessChecker::InstanceMethods)
    end
    
    # Run an access check.
    # The access check is based on the {Fl::Framework::Asset::AccessGrant} database, as follows.
    #
    # 1. If the `*asset*.owner` is the same as *actor*, the permission is granted: owners have full
    #    access to their assets.
    # 2. Otherwise, find all grants to *actor*. If one of these contains *permission*, grant access.
    # 3. The next step is to expand forwarded permissions to build a collection of terminal permissions,
    #    and repeat the preceding search over the expanded list.
    # 4. If no match is found, permission is not granted.
    #
    # Note that the current algorithm does not support groups, but that's OK since groups are not yet
    # implemented!
    #
    # @param permission [Symbol,String,Fl::Framework::Access::Permission] The requested permission;
    #  this is usually the name of a permission registered with the permission registry, but it could
    #  also be passed as a permission instance.
    # @param actor [Object] The actor requesting *permission*.
    # @param asset [Object] The target of the request (the asset for which *permission* is requested).
    # @param context [any] The context in which to do the check; this is arbitrary data to pass to the
    #  checker parameter.
    #
    # @return [Symbol,nil,Boolean] An access check method is expected to return a symbol containing the
    #  name of the granted permission if access rights were granted.
    #  Note that the returned value may be different from *permission* if the permission is granted through
    #  forwarding (for example, if the request was for **:write** and it was granted because of an
    #  **:edit** permission).
    #  It should return `nil` if access grants were not granted.
    #  Under some conditions, it may elect to return `false` to indicate that there was some kind of error
    #  when checking for access; a `false` return value indicates that access rights were not granted,
    #  and it *must* be interpreted as such.

    def access_check(permission, actor, asset, context = nil)
      pn = permission_name(permission)
      return pn if actor.fingerprint == asset.owner.fingerprint

      plist = _filter_grants(asset.grants, actor.fingerprint)
      plist.each { |p| return p if p == pn }

      # OK so since the first pass did not yeld matches, let's expand the collection

      perm = Fl::Framework::Access::Permission.lookup(pn)
      if perm
        perm.grantors.each { |p| return p if plist.include?(p) }
      end      
      
      return nil
    end

    private

    def _filter_grants(gl, afp)
      gl.reduce([ ]) do |acc, g|
        acc << g.permission.to_sym if g.actor.fingerprint == afp
        acc
      end
    end
    
    def _expand_grants(pl)
      pl.reduce([ ]) do |acc, pn|
        p = Fl::Framework::Access::Permission.lookup(pn)
        if p
          acc |= p.grantors
        end
        acc
      end
    end
    
    public
    
    # The instance methods injected into the including class by {#configure}.

    module InstanceMethods
      # Find an access grant.
      # Looks up a grant of *permission* to *actor*, and returns it if found.
      # Note that this lookup does not expand forwarded permissions; for example, a request for a
      # `:read` grant will not return a `:edit` grant (where `:edit` includes the `:read` permission).
      #
      # @param permission [Symbol,String,Fl::Framework::Access::Permission,Class] The permission to look up.
      #  See {Fl::Framework::Access::Helper.permission_name}.
      # @param actor [ActiveRecord::Base,String] The actor to which *permission* was granted.
      #  A string value is assumed to be a fingerprint.
      #
      # @return [Fl::Framework::Asset::AccessGrant,nil] Returns the grant object, `nil` if no grant
      #  was found.
      
      def find_grant(permission, actor)
        sp = Fl::Framework::Access::Helper.permission_name(permission)
        ap = (actor.is_a?(String)) ? actor : actor.fingerprint
        
        self.grants.each do |g|
          return g if (g.permission.to_sym == sp) && (g.actor.fingerprint == ap)
        end
        
        nil
      end

      # Add an access grant.
      # If the grant is not already present, the method
      # creates a {Fl::Framework::Asset::AccessGrant} where `self` is the target asset.
      #
      # @param permission [Symbol,String,Fl::Framework::Access::Permission,Class] The permission to grant.
      #  See {Fl::Framework::Access::Helper.permission_name}.
      # @param actor [ActiveRecord::Base,String] The actor to which *permission* is granted.
      #  A string value is assumed to be a fingerprint.
      #
      # @return [Fl::Framework::Asset::AccessGrant] Returns the grant object.
      
      def grant_permission(permission, actor)
        g = find_grant(permission, actor)
        if g.nil?
          sp = Fl::Framework::Access::Helper.permission_name(permission)
          a = (actor.is_a?(String)) ? ActiveRecord::Base.find_by_fingerprint(actor) : actor
          g = Fl::Framework::Asset::AccessGrant.create(permission: sp, actor: a, asset: self.asset_record)
          self.grants << g
        end
        g
      end

      # Revoke an access grant.
      # If the grant is present, the method destroys it and drops it from the `grants` association.
      #
      # @param permission [Symbol,String,Fl::Framework::Access::Permission,Class] The permission to revoke.
      #  See {Fl::Framework::Access::Helper.permission_name}.
      # @param actor [ActiveRecord::Base,String] The actor from which *permission* is revoked.
      #  A string value is assumed to be a fingerprint.
      
      def revoke_permission(permission, actor)
        g = find_grant(permission, actor)
        self.grants.destroy(g) unless g.nil?
      end

      protected
      
      # Callback before an instance is destroyed: clear the grants list.
      # We need this method (and we need to prepend it), because of the interaction between the
      # `asset_record` and `grants` associations. Because the two are defined in that order,
      # their destroy callbacks are also called in that order; and because `asset_record` has
      # **:dependent** set to `:destroy`, it attempts to destroy the asset record (in the
      # **fl_framework_assets** table). But because there are outstanding grant records (in the
      # **fl_framework_access_grants**), and because there is a foreign key constraint from that
      # table to **fl_framework_asset**, the delete call fails.
      # The solution is to place the `has_many` for **grants** before the `has_one` for **asset_record**;
      # unfortunately, this is not possible, since typically the class first declares to be an asset
      # with `is_asset`, and then to support access control with `has_access_control`.
      # The workaround is to prepend this callback to the other ones, and make it clear the **grants**
      # association.

      def clear_grants_hack()
        self.grants.clear
      end
      
      # Callback after an instance is created: add the owner grant.
      # This method adds a {Permission::Owner} grant to the owner of the asset; this grant is used
      # by the query methods to find assets owned by a given actor.

      def create_owner_grant()
        self.grants.create(permission: Fl::Framework::Asset::Permission::Owner::NAME,
                           actor: self.owner, asset: self.asset_record)
      end
    end
  end
end
