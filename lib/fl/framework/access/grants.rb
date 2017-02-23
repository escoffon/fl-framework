module Fl::Framework::Access
  # Mixin module to load access grants/rights management.

  module Grants
    # Grant access to list objects.
    INDEX = :index

    # Grant access to create objects.
    CREATE = :create

    # Grant access to the contents of an object.
    READ = :read

    # Grant access to modify (write) the contents of an object.
    WRITE = :write

    # Grant access to delete an object.
    DESTROY = :destroy

    # Grant administrative access to an object.
    ADMIN = :admin

    # Grant ownership access to an object.
    OWNER = :owner

    # Grant public access to an object.
    PUBLIC = :public

    # A Struct to store access grant information.
    # Instances of this class define two accessors: +rel+ for the relationship object, and
    # +actor+ for the actor. This is the data type for array elements returned by
    # Fl::Access::InstanceMethods#access_grants and Fl::Access::InstanceMethods#access_actors.

    AccessGrant = Struct.new(:rel, :actor)

    # The methods in this module will be installed as class methods of the including class.

    module ClassMethods
      # Get the forward grants for an operation.
      # A forward grant is the name of another operation that declared +op+ in its +grants+ configuration
      # parameter, and therefore declared that it grants rights to +op+.
      # For example, given the following operation definitions:
      #   access_op Fl::Access::Grants::WRITE, :default_access_checker, { scope: :instance, grants: [ Fl::Access::Grants::READ ] }
      #   access_op Fl::Access::Grants::ADMIN, :default_access_checker, { scope: :instance, grants: [ Fl::Access::Grants::READ, Fl::Access::Grants::WRITE ] }
      # the forward grants contain the following values:
      #   {
      #     read: [ :write, :admin ],
      #     write: [ :admin ]
      #   }
      # which means that +:write+ and +:admin+ grants imply also +:read+ grants.
      #
      # @param op [Symbol] The name of the operation for which to get the forward grants.
      #
      # @return [Array<Symbol>] Returns an array containing the forward grants for +op+; if none are
      #  registered, an empty array is returned.

      def forward_grants_for_op(op)
        s = op.to_sym
        ops = access_control_forward_grants()
        if ops.has_key?(s)
          ops[s]
        else
          []
        end
      end

      # Generate access grant parameters from a list of access grants.
      # This method builds an array of strings in the format parsed by
      # {Fl::Access::Grants::InstanceMethods#load_access_grants}.
      #
      # Note that +owner+ grants are not included in the return value.
      #
      # @param grants [Fl::Access::AccessGrant, Array<Fl::Access::AccessGrant>] An array (or a single value,
      #  which will be converted to an array) of {Fl::Access::AccessGrant} objects, as returned for example
      #  by {Fl::Access::InstanceMethods#access_grants}.
      # @param format [Symbol, String] A symbol (or a string that will be converted to a symbol)
      #  selecting the format to use:
      #  - *:as_strings* Return access grants in a string representation:
      #    "_type_/_id_/_grant_" where _type_ is the type of the grantee (+user+ or +group+), _id_ the
      #    grantee's object identifier, and _grant_ the grant type (+read+, +write+, and so on).
      #     This is the default value.
      #  - *:as_hash* Return access grants in a hash representation.
      #    The hash contains two keys, *:grantee* and *:grant*. The value of *:grant* is a symbol containing
      #    the grant type (+read+, +write+, and so on). The value of *:grantee* key is a hash containing the
      #    keys *:type*, *:id*, *:name*, and *:description*. The *:type* and *:id* keys contain information
      #    to fetch the object in the database: class name and object identifier.
      #    The value of the *:name* key is the grantee's name (+username+ for users and +groupname+ for
      #    groups).
      #    The value of *:description* is a (short) description of the object.
      #
      # @return [Array<String>, Array<Hash>] Returns an array of access grant descriptors as detailed above.

      def access_grant_descriptors(grants, format = :as_strings)
        rv = []
        fmt = format.to_sym

        grants = [ grants ] unless grants.is_a?(Array)
        grants.each do |g|
          unless g.rel.grant.to_s == 'owner'
            if fmt == :as_hash
              rv << _format_grant_as_hash(g)
            else
              rv << _format_grant_as_string(g)
            end
          end
        end

        rv
      end

      private

      def _format_grant_as_string(g)
        case g.actor
        when Fl::Core::Group
          atype = 'group'
          aname = g.actor.groupname
        when Fl::Core::User
          atype = 'user'
          aname = g.actor.username
        else
          atype = g.actor.class.name
          aname = g.actor.id
        end

        "#{atype}/#{aname}/#{g.rel.grant}"
      end

      def _format_grant_as_hash(g)
        grantee = {
          type: g.actor.class.name,
          id: g.actor.id
        }

        case g.actor
        when Fl::Core::Group
          grantee[:name] = g.actor.groupname
          grantee[:description] = g.actor.display_name
        when Fl::Core::User
          grantee[:name] = g.actor.username
          grantee[:description] = g.actor.username
        else
          grantee[:name] = g.actor.id
          grantee[:description] = g.actor.id
        end

        { grant: g.rel.grant.to_sym, grantee: grantee }
      end
    end

    # The methods in this module are installed as instance method of the including class.

    module InstanceMethods
      # Load access grant parameters.
      # This method parses the contents of +grants+, extracts actor and grant name, and calls
      # {#add_access_grant} to create the new grants.
      #
      # Note that the default behavior is to clear existing access grants, so that a call to this
      # method overrides the existing collection of grants.
      #
      # @param grants [Array<String>, String, Array<Hash>, Hash] An array (or a single value, which will be
      #  converted to an array) of actor/grant specifiers.
      #  Each specifier is a string or a hash in the format generated by
      #  {Fl::Access::Grants::ClassMethods#access_grant_descriptors}.
      #  For example, <tt>group/group1/write</tt> grants the group named +group1+ the +write+ access right.
      #  The same grant as a hash is:
      #    {
      #      grant: :write,
      #      grantee: {
      #        type: 'Fl::Core::Group',
      #        id: 'the_identifier_for_group_1',
      #        name: 'group1',
      #        description: 'The description (display_name) for group 1'
      #      }
      #    }
      #
      # @return Returns +true+ if all access rights were loaded, +false+ otherwise. On a +false+ return, some
      #  access rights may have been loaded.

      def load_access_grants(grants, clear = true)
        clear_access_grants() if clear

        loaded_all = true
        grants = [ grants ] unless grants.is_a?(Array)
        grants.each do |g|
          if g.is_a?(String)
            otype, oid, gtype = g.split('/')
            actor = case otype.to_s.downcase
                    when 'group'
                      Fl::Core::Group.convert_parameter(oid)
                    when 'user'
                      Fl::Core::User.convert_parameter(oid)
                    else
                      loaded_all = false
                      nil
                    end
          elsif g.is_a?(Hash)
            begin
              gtype = g[:grant]
              klass = g[:grantee][:type].constantize
              actor = klass.find(g[:grantee][:id])
            rescue => exc
              actor = nil
            end
          end

          if actor && gtype
            loaded_all = false unless self.add_access_grant(actor, gtype)
          else
            loaded_all = false
          end
        end

        loaded_all
      end

      # Generate access grant parameters from the current access grants.
      # This method builds an array of strings in the format parsed by
      # {Fl::Access::Grants::InstanceMethods#load_access_grants}.
      #
      # @param format [Symbol, String] A symbol (or a string that will be converted to a symbol)
      #  selecting the format to use. See the documentation for 
      #  {Fl::Access::Grants::InstanceMethods#load_access_grants}.
      #
      # @return [Array<String>, Array<Hash>] Returns an array of access grant descriptiors as documented for
      #  {Fl::Access::Grants::ClassMethods#access_grant_descriptors}.

      def access_grant_descriptors(format = :to_strings)
        self.class.access_grant_descriptors(self.access_grants, format)
      end

      # Get the set of access grants for this object.
      # Access grants are representation of +ACCESS+ relationship between +self+ and actors.
      # The list of access grants is cached in an instance variable, under the assumption that these
      # relationships vary infrequently.
      #
      # Note that this list contains only direct access grants: objects that are granted access via
      # a +LINKED_TO+ relationship are included in {#access_actors}.
      #
      # @param reload [Boolean] If +true+, force a reload of the cached data.
      #
      # @return [Array<Fl::Access::AccessGrant>] Returns an array of {Fl::Access::AccessGrant} structs
      #  that contain the Neo4j::ActiveRel corresponding to the
      #  +ACCESS+ relationship (an instance of {Fl::Rel::Core::Access}), and the {Fl::Core::Actor} that is
      #  the recipient of the access grant; use the +rel+ and +actor+ accessors, respectively.
      #  The reason that we return the actor explicitly, even though it could be obtained from the
      #  {Fl::Rel::Core::Access} object, is that {#access_actors} builds a list with the same format, but in
      #  case of actors connected through a +LINKED_TO+, the {Fl::Rel::Core::Access} contains the first
      #  actor, not the second one.

      def access_grants(reload = false)
        if @access_grants.nil? || reload
          @access_grants = self.query_as(:o).match('(o)-[r:ACCESS]->(a)').pluck(:r, :a).map do |row|
            # The query returns a Neo4j::Server::CypherRelationship, and we need to convert it to
            # a Fl::Rel::Core::Access.
            # At some point maybe we should convert access_grants to an association and manage the
            # access grants by managing the collection. The downside of that is that we don't have ready
            # access to the relationship object, which holds the type of access.
            
            r, actor = row
            rel = Fl::Rel::Core::Access.new(from_node: self, to_node: actor, grant: r.props[:grant])

            # this is a bit of a hack: the rel object above should actually be marked persisted, since it was
            # really loaded from the database. I'm not sure of how this is accomplished in general, but a
            # call to the (private) create_model method seems to be an acceptable way of doing it; see
            # neo4j/active_rel/persistence.rb and neo4j/active_rel/initialize.rb (for init_on_load).
            # After a call to create_model, the ActiveRel is marked persisted.
            # An alternative is to make a direct call to init_on_load, since we can assume that, if the
            # object data were picked up from the DB, they are valid.

            success = rel.send(:create_model)
            AccessGrant.new(rel, actor)
          end
        end

        @access_grants
      end

      # Add an access grant.
      # If the combination of +grant+ and +actor+ is not present in the access grants, add it.
      #
      # @param actor [Fl::Core::Actor] The actor that will be granted +grant+ access.
      # @param grant [Symbol, String] The access type to grant; for example: +:read+, +:write+, +:admin+.
      #  A string value is converted to a symbol.
      #
      # @return Returns +true+ if the access grant is created (or if it already exists), +false+ on failure.

      def add_access_grant(actor, grant)
        sg = grant.to_s
        self.access_grants.each do |g|
          return true if (g.rel.grant == sg) && (g.actor.id == actor.id)
        end

        r = Fl::Rel::Core::Access.new(from_node: self, to_node: actor, grant: sg)
        return false unless r.save

        @access_grants << AccessGrant.new(r, actor)
        _set_access_grants_modified()

        true
      end

      # Check for an access grant.
      #
      # @param actor [Fl::Core::Actor] The actor that has been granted +grant+ access.
      # @param grant [Symbol, String] The access type to grant; for example: +:read+, +:write+, +:admin+.
      #  A string value is converted to a symbol.
      #
      # @return Returns +true+ if the access grant is present, +false+ otherwise.

      def has_access_grant?(actor, grant)
        sg = grant.to_s
        self.access_grants.each do |g|
          return true if (g.rel.grant == sg) && (g.actor.id == actor.id)
        end

        false
      end

      # Remove an access grant.
      # If the combination or +grant+ and +actor+ is present in the access grants, remove it.
      #
      # @param actor [Fl::Core::Actor] The actor whose +grant+ access will be revoked.
      # @param grant [Symbol, String] The access type to revoke; for example: +:read+, +:write+, +:admin+.
      #  If +nil+, all access grants associated with +actor+ are removed.
      #
      # If a grant is removed, the access grants cache is invalidated.

      def remove_access_grant(actor, grant = nil)
        if grant.nil?
          ng = self.access_grants.select do |g|
            if g.actor.id == actor.id
              g.rel.destroy
              _set_access_grants_modified()
              false
            else
              true
            end
          end

          @access_grants = ng
        else
          sg = grant.to_s
          self.access_grants.each_with_index do |g, idx|
            if (g.rel.grant == sg) && (g.actor.id == actor.id)
              g.rel.destroy
              @access_grants.delete_at(idx)
              _set_access_grants_modified()
              return
            end
          end
        end
      end

      # Remove all access grants.
      # This method clears the current list of access grants and invalidates the access grants cache.

      def clear_access_grants()
        self.access_grants.each do |g|
          g.rel.destroy
        end

        @access_grants = []
        _set_access_grants_modified()
      end

      # Check if the access grants have changed.
      #
      # @return Returns +true+ if the access grants have been modified, and the object has not been saved to
      #  persistent storage, +false+ otherwise.

      def access_grants_changed?()
        @access_grants_changed
      end

      # Get the set of actors with access grants for this object.
      # This method returns both direct (through an +ACCESS+ relationship) and indirect (through a
      # +LINKED_TO+ relationship) access grants.
      # The list of access grants is cached in an instance variable, under the assumption that these
      # relationships vary infrequently.
      #
      # @param reload [Boolean] If +true+, force a reload of the cached data.
      #
      # @return [Array<Fl::Access::AccessGrant>] Returns an array of {Fl::Access::AccessGrant} structs
      #  that contain the Neo4j::ActiveRel corresponding to the grant.
      #  See the documentation for {Fl::Access::InstanceMethods#access_grants}.
      #
      # @note This method is currently not used; it was left in for possible later use.

      def access_actors(reload = false)
        if @access_actors.nil? || reload
          @access_actors = []
          seen_actors = {}
          self.query_as(:o).match('(o)-[r:ACCESS]->(a1)<-[l:LINKED_TO*0..1]-(a2)').pluck(:r, :a1, :a2, :l).each do |e|
            r, a1, a2, l = e

            # If we have a subgraph like (o)<-[A]-(a1)<-[L]-(a2), the query returns two paths for it:
            # (o)<-[A]-(a1) and (o)<-[A]-(a1)<-[L]-(a2), because of the *0..1 qualifier in LINKED_TO.
            # In the first case, a1 and a2 have the same node; in the second, they have a different node.
            # So all we need to do is add a2: there is no need to add the intemediate a1 from the second path

            unless seen_actors[a2.id]
              @access_actors << AccessGrant.new(r, a2)
              seen_actors[a2.id] = true
            end
          end
        end

        @access_actors
      end

      private

      def _clear_access_relationships()
        if self.persisted?
          self.query_as(:o)\
            .match('(o)-[r:ACCESS]->(a)')\
            .where('(r.grant <> {owner_grant})', owner_grant: Fl::Access::Grants::OWNER)\
            .delete(:r)\
            .exec
        end
      end

      def _set_access_grants_modified()
        @access_grants_changed = true
      end

      def _clear_access_grants_modified()
        @access_grants_changed = false
      end

      def _clear_access_caches()
        @access_grants =  nil
        @access_actors = nil
      end

      def _check_public_grant()
        # see Fl::Access::Access::InstanceMethods#adjust_visibility_state for why we do this

        if self.visibility == Fl::Visibility::PUBLIC
          self.add_access_grant(Fl::Core::Group.public_group, Fl::Access::Grants::PUBLIC)
        end
      end

      def _validate_access_grants()
        return unless self.respond_to?(:visibility)

        # Although technically we should consider invalid a state where the visibility is :group
        # or :friends and no access rights are actually defined, we can't because of a chicken and egg
        # situation: in order to add an ACCESS relationship, the nodes must be valid, but the node won't
        # be valid at the time the first access right is added. So, we let this condition slide...

        case self.visibility
        when Fl::Visibility::PRIVATE
          # :private may have access grants only for ACCESS:owner

          access_grants.each do |ag|
            if ag.rel.grant.to_sym != :owner
              if ag.actor.is_a?(Fl::Core::Group)
                self.errors.add(:access_grants, I18n.tx('fl.access.model.validation.private_grant_group',
                                                        :groupname => ag.actor.groupname,
                                                        :grant => ag.rel.grant))
              elsif ag.actor.is_a?(Fl::Core::User)
                self.errors.add(:access_grants, I18n.tx('fl.access.model.validation.private_grant_user',
                                                        :username => ag.actor.username,
                                                        :grant => ag.rel.grant))
              else
                self.errors.add(:access_grants, I18n.tx('fl.access.model.validation.private_grant',
                                                        :grant => ag.rel.grant))
              end
            end
          end
        when Fl::Visibility::GROUP
          check_groups = _access_owner_groups
          check_ids = check_groups.map { |g| g.id }
          access_grants.each do |ag|
            if ag.actor.is_a?(Fl::Core::Group)
              if ag.actor.id == Fl::Core::Group.public_group.id
                self.errors.add(:access_grants, I18n.tx('fl.access.model.validation.public_grant_group',
                                                        :visibility => self.visibility))
              else
                unless check_ids.include?(ag.actor.id)
                  self.errors.add(:access_grants, I18n.tx('fl.access.model.validation.not_owner_group',
                                                          :groupname => ag.actor.groupname))
                end
              end
            elsif ag.actor.is_a?(Fl::Core::User)
              role_group = check_groups.detect do |g|
                g.has_role?(ag.actor, [Fl::Core::Group::ROLE_MEMBER, Fl::Core::Group::ROLE_ADMIN])
              end
              if role_group.nil?
                self.errors.add(:access_grants, I18n.tx('fl.access.model.validation.not_owner_group_user',
                                                        :username => ag.actor.username))
              end
            end
          end
        when Fl::Visibility::FRIENDS
          check_groups = _access_owner_groups | _access_owner_friends
          check_ids = check_groups.map { |g| g.id }
          access_grants.each do |ag|
            if ag.actor.is_a?(Fl::Core::Group)
              if ag.actor.id == Fl::Core::Group.public_group.id
                self.errors.add(:access_grants, I18n.tx('fl.access.model.validation.public_grant_group',
                                                        :visibility => self.visibility))
              else
                unless check_ids.include?(ag.actor.id)
                  self.errors.add(:access_grants, I18n.tx('fl.access.model.validation.not_owner_friend',
                                                          :groupname => ag.actor.groupname))
                end
              end
            elsif ag.actor.is_a?(Fl::Core::User)
              role_group = check_groups.detect do |g|
                g.has_role?(ag.actor, [Fl::Core::Group::ROLE_MEMBER, Fl::Core::Group::ROLE_ADMIN])
              end
              if role_group.nil?
                self.errors.add(:access_grants, I18n.tx('fl.access.model.validation.not_owner_friend_user',
                                                        :username => ag.actor.username))
              end
            end
          end
        when Fl::Visibility::PUBLIC
          # :public may have access grants only for ACCESS:owner and ACCESS:public (to the public group)

          access_grants.each do |ag|
            case ag.rel.grant.to_sym
            when Fl::Access::Grants::OWNER
            when Fl::Access::Grants::PUBLIC
              if ag.actor.id != Fl::Core::Group.public_group.id
                if ag.actor.is_a?(Fl::Core::Group)
                  self.errors.add(:access_grants, I18n.tx('fl.access.model.validation.public_grant_group',
                                                          :groupname => ag.actor.groupname,
                                                          :grant => ag.rel.grant))
                elsif ag.actor.is_a?(Fl::Core::User)
                  self.errors.add(:access_grants, I18n.tx('fl.access.model.validation.public_grant_user',
                                                          :username => ag.actor.username,
                                                          :grant => ag.rel.grant))
                else
                  self.errors.add(:access_grants, I18n.tx('fl.access.model.validation.public_grant',
                                                          :grant => ag.rel.grant))
                end
              end
            else
              if ag.actor.is_a?(Fl::Core::Group)
                self.errors.add(:access_grants, I18n.tx('fl.access.model.validation.public_grant_group',
                                                        :groupname => ag.actor.groupname,
                                                        :grant => ag.rel.grant))
              elsif ag.actor.is_a?(Fl::Core::User)
                self.errors.add(:access_grants, I18n.tx('fl.access.model.validation.public_grant_user',
                                                        :username => ag.actor.username,
                                                        :grant => ag.rel.grant))
              else
                self.errors.add(:access_grants, I18n.tx('fl.access.model.validation.public_grant',
                                                        :grant => ag.rel.grant))
              end
            end
          end
        when Fl::Visibility::DIRECT
          # :direct is a free for all
        end
      end
    end

    # Perform actions when the module is included.
    # - Injects the class and instance methods.
    # - Defines the 
    def self.included(base)
      base.extend ClassMethods

      base.instance_eval do
        # Get the registered forward grants.
        # This method looks up the access grant on the class hierarchy, so that it picks up and expands
        # grants inherited from superclasses.
        #
        # @return [Hash] Returns a hash where the keys are operation names, and the values are arrays
        #  of operation names that list the operations that grant access to the key.

        def access_control_forward_grants()
          s = self
          until s.instance_variable_defined?(:@access_control_forward_grants)
            s = s.superclass
          end
          s.instance_variable_get(:@access_control_forward_grants)
        end
      end

      base.class_eval do
        include InstanceMethods

        @access_control_forward_grants = {}

        after_initialize :_clear_access_grants_modified
        after_save :_clear_access_grants_modified
        after_save :_check_public_grant
        validate :_validate_access_grants
      end
    end
  end
end
