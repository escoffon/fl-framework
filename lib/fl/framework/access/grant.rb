module Fl::Framework::Access
  # Model class for access grants stored in the repository.
  # A grant describes the permissions on a target object granted to an entity called an *actor*.
  # The grantee (actor) and target are fixed at create time, but the permission mask may be modified.
  #
  # This class also defines a class API to manage grant objects; we recommend using the API, which provides
  # a global entry point for various operations that may be backed up by caches in the future.
  #
  #
  # #### Access control policies
  #
  # The {Permission} and {Grant} classes provide a framework for managing permission grants, but do not
  # enforce specific access control policies; that task is left to subclasses of {Checker}.
  # However, the {Grant} class hierarchy includes support for some common types of access controls.
  # An important aspect of this support is the fact that the {#granted_to} attribute is polymorphic,
  # so that different types of objects can be granted permissions.
  # This makes it possible to define access policies where permissions are granted to groups of actors.
  # For example, instead of creating N grants for the N members of a group, one can create a single grant
  # to the group itself; the access queries in that
  # case have to request grants associated with a single actor *or* with all groups to which this actor
  # belongs. We can use that behavior to implement the notion of a publicly accessible asset: define
  # a special system group that implicitly includes all actors, create a grant to that group, and then
  # request grants associated with it to obtain a list of assets that have granted public access.

  class Grant < Fl::Framework::ApplicationRecord
    include Fl::Framework::Core::ModelHash
    extend Fl::Framework::Query
    
    self.table_name = 'fl_framework_access_grants'
    
    # @!attribute [rw] grants
    # The permission mask stored in the grant; this is the list of simple permissions granted.
    # Note that the preferred method to manage the value of this attribute is to use the
    # {#add_grant}, {#remove_grant}, and {#has_grant?} methods, or the class methods
    # {.add_grant}, {.remove_grant}, and {.has_grant?}.
    # @return [Integer] Returns the permission mask in the grant.    

    # @!attribute [r] target
    # A `belongs_to` association to the object for which permission is granted.
    # This association is polymorphic.
    #
    # @return [Association] the object to which {#grants} are granted.

    belongs_to :target, polymorphic: true

    # @!attribute [r] granted_to
    # A `belongs_to` association to the entity that is granted permission.
    # This association is polymorphic; see the class documentation for a discussion of
    # why this is important.
    # @return [Association] the entity that is granted {#grants}.

    belongs_to :granted_to, polymorphic: true
    
    before_create :set_fingerprints

    validates :grants, presence: true
    validate :check_grants
    validates :granted_to, presence: true
    validates :target, presence: true
    
    # Constructor.
    #
    # @param attrs [Hash] A hash of initialization parameters.
    #
    # @option attrs [Integer] :grants The permission mask for the grant.
    # @option attrs [ActiveRecord::Base,String] :granted_to The grantee.
    #  A string value should be the object's fingerprint.
    # @option attrs [ActiveRecord::Base,String] :target The target object.
    #  A string value should be the object's fingerprint.

    def initialize(attrs = {})
      attrs = attrs || {}

      if attrs[:granted_to].is_a?(String)
        attrs[:granted_to] = self.class.find_by_fingerprint(attrs[:granted_to])
      end

      if attrs[:target].is_a?(String)
        attrs[:target] = self.class.find_by_fingerprint(attrs[:target])
      end

      if attrs.has_key?(:grants)
        attrs[:grants] = Fl::Framework::Access::Helper.permission_mask(attrs[:grants])
      end

      super(attrs)
    end

    # Bulk update.
    # The implementation accepts just the **:grants** parameter
    #
    # @param attrs [Hash] The attributes; all are ignored, except for **:grants**.

    def update_attributes(attrs)
      if attrs.has_key?(:grants)
        super(grants: attrs[:grants])
      else
        super({})
      end
    end

    # Add a set of permissions to the grants.
    #
    # @param permissions [Integer, Array<Symbol,String,Fl::Framework::Access::Permission,Class>] The
    #  permissions whose masks to combine, using {Fl::Framework::Access::Helper.permission_mask}.
    #
    # @return [Fl::Framework::Access::Grant] Returns `self`.
    
    def add_grant(permissions)
      self.grants |= Fl::Framework::Access::Helper.permission_mask(permissions)
      self
    end

    # Remove a set of permissions from the grants.
    #
    # @param permissions [Integer, Array<Symbol,String,Fl::Framework::Access::Permission,Class>] The
    #  permissions whose masks to combine, using {Fl::Framework::Access::Helper.permission_mask}.
    #
    # @return [Fl::Framework::Access::Grant] Returns `self`.

    def remove_grant(permissions)
      self.grants &= ~Fl::Framework::Access::Helper.permission_mask(permissions)
      self
    end

    # Check if a set of permissions is in the grants.
    #
    # @param permissions [Integer, Array<Symbol,String,Fl::Framework::Access::Permission,Class>] The
    #  permissions whose masks to combine, using {Fl::Framework::Access::Helper.permission_mask}.
    #
    # @return [Boolean] Returns `true` if the value of {#grants} ANDed with the value of *permissions*
    #  is nonzero; in other words, returns `true` if any of the permissions in *permissions* have been
    #  granted. Otherwise, returns `false`.
    
    def has_grant?(permissions)
      (self.grants & Fl::Framework::Access::Helper.permission_mask(permissions)) != 0
    end

    # Find a grant for an actor and target.
    #
    # @param granted_to [ActiveRecord::Base,String] The grantee.
    #  A string value should be the object's fingerprint.
    # @param target [ActiveRecord::Base,String] The target object.
    #  A string value should be the object's fingerprint.
    #
    # @return [Fl::Framework::Access::Grant,nil] Returns the grant object if one was found, otherwise `nil`.

    def self.find_grant(granted_to, target)
      self.where('(granted_to_fingerprint = :gfp) AND (target_fingerprint = :tfp)',
                 gfp: (granted_to.is_a?(String)) ? granted_to : granted_to.fingerprint,
                 tfp: (target.is_a?(String)) ? target : target.fingerprint).first
    end

    # Add a set of permissions to the grants for an actor and target.
    # This method looks up a {Grant} object and builds one if not found; it then sets the grants
    # from *permissions* and saves the object.
    #
    # @param permissions [Integer, Array<Symbol,String,Fl::Framework::Access::Permission,Class>] The
    #  permissions whose masks to combine, using {Fl::Framework::Access::Helper.permission_mask}.
    # @param granted_to [ActiveRecord::Base,String] The grantee.
    #  A string value should be the object's fingerprint.
    # @param target [ActiveRecord::Base,String] The target object.
    #  A string value should be the object's fingerprint.
    #
    # @return [Fl::Framework::Access::Grant] Returns the grant object that was either modified, or built.

    def self.add_grant(permissions, granted_to, target)
      g = self.find_grant(granted_to, target)
      g = self.new(granted_to: granted_to, target: target, grants: 0) if g.nil?
      g.add_grant(permissions)
      g.save
      g
    end

    # Remove a set of permissions from the grants for a grantee and target.
    # This method looks up a {Grant} object and removes the grants from *permissions* if found;
    # if no object is found, this is a no-op.
    # If an object is found, it is saved to storage.
    #
    # If the new set of grants for the grant object is 0, the object is destroyed.
    #
    # @param permissions [Integer, Array<Symbol,String,Fl::Framework::Access::Permission,Class>] The
    #  permissions whose masks to combine, using {Fl::Framework::Access::Helper.permission_mask}.
    # @param granted_to [ActiveRecord::Base,String] The grantee.
    #  A string value should be the object's fingerprint.
    # @param target [ActiveRecord::Base,String] The target object.
    #  A string value should be the object's fingerprint.
    #
    # @return [Fl::Framework::Access::Grant] Returns the grant object that was either modified, or `nil`.
    #  Note that the object has not been persisted; clients will have to call `save`.

    def self.remove_grant(permissions, granted_to, target)
      g = self.find_grant(granted_to, target)
      unless g.nil?
        g.grants &= ~Fl::Framework::Access::Helper.permission_mask(permissions)
        if g.grants == 0
          g.destroy
        else
          g.save
        end
      end
      g
    end

    # Check if a set of permissions is in the grants for a given target and grantee.
    #
    # @param permissions [Integer, Array<Symbol,String,Fl::Framework::Access::Permission,Class>] The
    #  permissions whose masks to combine, using {Fl::Framework::Access::Helper.permission_mask}.
    # @param granted_to [ActiveRecord::Base,String] The grantee.
    #  A string value should be the object's fingerprint.
    # @param target [ActiveRecord::Base,String] The target object.
    #  A string value should be the object's fingerprint.
    #
    # @return [Boolean] Returns `true` if the value of {#grants} ANDed with the value of *permissions*
    #  is nonzero; in other words, returns `true` if any of the permissions in *permissions* have been
    #  granted. Otherwise, returns `false`.

    def self.has_grant?(permissions, granted_to, target)
      g = self.find_grant(granted_to, target)
      (g.nil?) ? false : g.has_grant?(permissions)
    end

    # Return all grants associated with a given actor.
    #
    # @param granted_to [ActiveRecord::Base,String] The grantee.
    #  A string value should be the object's fingerprint.
    #
    # @return [Array<Fl::Framework::Access::Grant>] Returns an array containing all the grant objects
    #  where **granted_to** is *actor*.
    
    def self.grants_for_actor(granted_to)
      self.build_query(only_granted_to: granted_to).to_a
    end

    # Return all grants associated with a given target.
    #
    # @param target [ActiveRecord::Base,String] The target.
    #  A string value should be the object's fingerprint.
    #
    # @return [Array<Fl::Framework::Access::Grant>] Returns an array containing all the grant objects
    #  where **target** is *traget*.
    
    def self.grants_for_target(target)
      self.build_query(only_targets: target).to_a
    end

    # Remove all grants associated with a given actor.
    #
    # @param granted_to [ActiveRecord::Base,String] The grantee.
    #  A string value should be the object's fingerprint.
    #
    # @return If a SQL statement is executed, returns the return value from the `execute` call.
    #  Otherwise, returns `nil`. You can use the result object to get more information about the call.
    
    def self.delete_grants_for_actor(granted_to)
      gfp = if granted_to.is_a?(String)
              granted_to
            elsif granted_to.is_a?(ActiveRecord::Base) && granted_to.respond_to?(:fingerprint)
              granted_to.fingerprint
            else
              nil
            end
      return nil if gfp.nil?
      
      sql = "DELETE FROM #{self.table_name} WHERE (granted_to_fingerprint = '#{gfp}')"
      self.connection.execute(sql)
    end

    # Remove all grants associated with a given target.
    #
    # @param target [ActiveRecord::Base,String] The target.
    #  A string value should be the object's fingerprint.
    #
    # @return If a SQL statement is executed, returns the return value from the `execute` call.
    #  Otherwise, returns `nil`. You can use the result object to get more information about the call.

    def self.delete_grants_for_target(target)
      tfp = if target.is_a?(String)
              target
            elsif target.is_a?(ActiveRecord::Base) && target.respond_to?(:fingerprint)
              target.fingerprint
            else
              nil
            end
      return nil if tfp.nil?
      
      sql = "DELETE FROM #{self.table_name} WHERE (target_fingerprint = '#{tfp}')"
      self.connection.execute(sql)
    end

    # Shows the grants in the permission mask.
    # This wraps a call to {Fl::Framework::Access::Permission.extract_permissions}.
    #
    # @return [Array<Symbol>] Returns an array containing the names of the simple permissions that are
    #  present in {#grants}.

    def extract_permissions()
      Fl::Framework::Access::Permission.extract_permissions(grants)
    end
    
    # Build a query to fetch access grants.
    #
    # Note that any WHERE clauses from **:updated_after**, **:created_after**, **:updated_before**,
    # and **:created_before** are concatenated using the AND operator. The values for these options are:
    # a UNIX timestamp; a Time object; a string containing a representation of the time (this string
    # is converted to a {Fl::Framework::Core::Icalendar::Datetime} internally).
    #
    # @param opts [Hash] A Hash containing configuration options for the query.
    # @option opts [Array<Object,String>, Object, String] :only_granted_to Limit the returned values to
    #  grants whose `granted_to` attribute is in the option's value
    #  (technically, whose `granted_to_id` and `granted_to_type` attribute pairs are in the list derived
    #  from the option's value).
    #  The elements in an array value are object instances or object fingerprints; note that identifiers
    #  are not supported, because the `granted_to` association is polymorphic.
    #  If this option is not present, all grants are selected.
    # @option opts [Array<Object,String>, Object, String] :except_granted_to Limit the returned values to
    #  grants whose `granted_to` attribute is not in the option's value
    #  (technically, whose `granted_to_id` and `granted_to_type` attribute pairs are not in the list derived
    #  from the option's value).
    #  The elements in an array value are object instances or object fingerprints; note that identifiers
    #  are not supported, because the `granted_to` association is polymorphic.
    #  If this option is not present, all grants are selected.
    # @option opts [Array<Object,String>, Object, String] :only_targets Limit the returned values to
    #  grants whose `target` attribute is in the option's value
    #  (technically, whose `target_id` and `target_type` attribute pairs are in the list derived
    #  from the option's value).
    #  The elements in an array value are object instances or object fingerprints; note that identifiers
    #  are not supported, because the `target` association is polymorphic.
    #  If this option is not present, all grants are selected.
    # @option opts [Array<Object,String>, Object, String] :except_targets Limit the returned values to
    #  grants whose `target` attribute is not in the option's value
    #  (technically, whose `target_id` and `target_type` attribute pairs are not in the list derived
    #  from the option's value).
    #  The elements in an array value are object instances or object fingerprints; note that identifiers
    #  are not supported, because the `target` association is polymorphic.
    #  If this option is not present, all grants are selected.
    # @option opts [Array<Object,String>, Object, String] :only_types Limit the returned
    #  values to grants whose `target_type` attribute is in the option's value
    #  (technically, whose `target_type` attribute is in the list derived from the option's value).
    #  The elements in an array value are strings or classes; the strings contain class names, and the
    #  classes are converted to class names.
    #  If this option is not present, all grants are selected.
    # @option opts [Array<Object,String>, Object, String] :except_types Limit the returned
    #  values to grants whose `target_type` attribute is not in the option's value
    #  (technically, whose `target_type` attribute is not in the list derived from the option's value).
    #  The elements in an array value are strings or classes; the strings contain class names, and the
    #  classes are converted to class names.
    #  If this option is not present, all grants are selected.
    # @option opts :permissions Limit the returned values to grants that satisfy the permission conditions
    #  described by this option. See below for details.
    #  If this option is not present, all grants are selected.
    # @option opts [Integer, Time, String] :updated_after selects list items updated after a given time.
    # @option opts [Integer, Time, String] :created_after selects list items created after a given time.
    # @option opts [Integer, Time, String] :updated_before selects list items updated before a given time.
    # @option opts [Integer, Time, String] :created_before selects list items created before a given time.
    # @option opts [Integer] :offset Sets the number of records to skip before fetching;
    #  a `nil` value causes the option to be ignored.
    #  Defaults to 0 (start at the beginning).
    # @option opts [Integer] :limit The maximum number of records to return;
    #  a `nil` value causes the option to be ignored.
    #  Defaults to all records.
    # @option opts [String, Array] :order A string or array containing the <tt>ORDER BY</tt> clauses
    #  for the records. The string value is converted to an array by splitting it at commas.
    #  A `false` value or an empty string or array causes the option to be ignored.
    # @option opts [Symbol, Array<Symbol>, Hash] :includes An array of symbols (or a single symbol),
    #  or a hash, to pass to the +includes+ method
    #  of the relation; see the guide on the ActiveRecord query interface about this method.
    #
    # Note that **:limit**, **:offset**, and **:includes** are convenience options, since they can be
    # added later by making calls to +limit+, +offset+, and +includes+ respectively, on the
    # return value. But there are situations where the return type is hidden inside an API wrapper, and
    # the only way to trigger these calls is through the configuration options.
    #
    # #### The **:permissions** option
    #
    # This option defines filters (WHERE clauses, really) for permissions.
    # The canonical form of the option's value is an array of clause descriptors and logical operators,
    # in the form `[ <clause>, <op>, <clause>, <op>, <clause>...]`: a sequence of clauses joined by
    # the logical operators `:or` and `:and`. Clauses are hashes containing the keys **:all** or **:any**,
    # whose values are permission descriptors. The **:all** key generates a clause that accepts grants
    # where *all* the permissions in the value are granted; the **:any* key generates a clause that
    # accepts grants where *at least one* permission in the value is granted.
    # The permission descriptors can have the following forms:
    #
    # - An integer containing the bitmask of the requested permissions; for example: `0x0000000c`.
    # - A string or symbol is the name of a registered permission; this name is used to obtain the
    #   corresponding permission mask. For example: `Fl::Framework::Access::Permission::Edit::NAME`
    #   (which is converted to the bitmask value `0x0000000c`).
    # - A class object for a registered permission, from which the bitmask is generated.
    #   For example: `Fl::Framework::Access::Permission::Edit`.
    # - An instance of (a subclass of) {Fl::Framework::Access::Permission}, from which the bitmask is
    #   generated. This is an uncommon form to use.
    # - An array whose elements are one of the forms described above. The final value is the OR
    #   combination of the bitmasks from each element in the array.
    #
    # A clause value can be simplified to be one of the forms listed above, rather than a hash; in this
    # it is assumed to behave as a **:all** permission mask. Similarly, the value for the **:permissions**
    # option can be simplified to one of the forms listed above: `Fl::Framework::Access::Permission::Edit`
    # is equivaluent to `[ { all: Fl::Framework::Access::Permission::Edit } ]`.
    #
    # For example, to select objects that grant either a `Read` or `Write` permission, use
    #
    # ```
    #   Fl::Framework::Access::Grant.build_query({
    #     permissions: [ { all: Fl::Framework::Access::Read }, :or, { all: Fl::Framework::Access::Write } ]
    #   })
    # ```
    #
    # This is better written as:
    #
    # ```
    #   Fl::Framework::Access::Grant.build_query({
    #     permissions: [ { any: [ Fl::Framework::Access::Read, Fl::Framework::Access::Write ] } ]
    #   })
    # ```
    #
    # or
    #
    # ```
    #   Fl::Framework::Access::Grant.build_query({
    #     permissions: [ { any: Fl::Framework::Access::Read::BIT | Fl::Framework::Access::Write::BIT } ]
    #   })
    # ```
    #
    # (Note that this last form does not work for composite permissions, whose `BIT` value is 0;
    # use a permission name or permission class to avoid this pitfall.)
    #
    # To select objects that grant `Edit` permission (and therefore both `Read` *and* `Write`, use
    #
    # ```
    #   Fl::Framework::Access::Grant.build_query({
    #     permissions: [ { all: Fl::Framework::Access::Edit } ]
    #   })
    # ```
    #
    # which can be collapsed to
    #
    # ```
    #   Fl::Framework::Access::Grant.build_query({
    #     permissions: Fl::Framework::Access::Edit
    #   })
    # ```
    #
    # To get targets where user `u` has write permission, we need to select those grants that include the
    # `Write` permission, as well as those owned by `u`; this is where a `:or` operator comes in handy:
    #
    # ```
    #   Fl::Framework::Access::Grant.build_query({
    #     only_granted_to: u,
    #     permissions: [ Fl::Framework::Access::Write, :or, Fl::Framework::Access::Owner ]
    #   })
    # ```
    #
    # (This is what {.accessible_query} does.)
    #
    # @return [ActiveRecord::Relation] If the query options are empty, the method returns `self`
    #  (and therefore the class object); if they are not empty, it returns an association relation.

    def self.build_query(opts = {})
      q = self

      if opts[:includes]
        i = (opts[:includes].is_a?(Array) || opts[:includes].is_a?(Hash)) ? opts[:includes] : [ opts[:includes] ]
        q = q.includes(i)
      else
        q = q.includes(:granted_to, :target)
      end

      to_lists = partition_lists_of_polymorphic_references(opts, 'granted_to')
      tg_lists = partition_lists_of_polymorphic_references(opts, 'targets')
      ty_lists = partition_filter_lists(opts, 'types') do |dl|
        dl.map do |d|
          if d.is_a?(Class)
            d.name
          else
            d.to_s
          end
        end
      end
#      all_permissions = _get_permissions_mask(opts, :all_permissions)
#      any_permissions = _get_permissions_mask(opts, :any_permissions)

      # if :only_granted_to is nil, and :except_granted_to is also nil, the two options will create
      # an empty set, so we can short circuit here.
      # and similarly for the others

      to_nil_o = to_lists.has_key?(:only_granted_to) && to_lists[:only_granted_to].nil?
      to_nil_x = to_lists.has_key?(:except_granted_to) && to_lists[:except_granted_to].nil?
      tg_nil_o = tg_lists.has_key?(:only_targets) && tg_lists[:only_targets].nil?
      tg_nil_x = tg_lists.has_key?(:except_targets) && tg_lists[:except_targets].nil?
      ty_nil_o = ty_lists.has_key?(:only_types) && ty_lists[:only_types].nil?
      ty_nil_x = ty_lists.has_key?(:except_types) && ty_lists[:except_types].nil?

      if to_nil_o && to_nil_x && tg_nil_o && tg_nil_x && ty_nil_o && ty_nil_x
        return q.where('(1 = 0)')
      end
      
      # In the following, if we have :only_, the :except_ have already been eliminated, so all we need
      # is the only_ value. Otherwise, if :except_ is present we tag the where clause for that

      if to_lists[:only_granted_to].is_a?(Array)
        q = q.where('(granted_to_fingerprint IN (:ul))', { ul: to_lists[:only_granted_to] })
      elsif to_lists[:except_granted_to]
        q = q.where('(granted_to_fingerprint NOT IN (:ul))', { ul: to_lists[:except_granted_to] })
      end

      if tg_lists[:only_targets].is_a?(Array)
        q = q.where('(target_fingerprint IN (:ul))', { ul: tg_lists[:only_targets] })
      elsif tg_lists[:except_targets]
        q = q.where('(target_fingerprint NOT IN (:ul))', { ul: tg_lists[:except_targets] })
      end

      if ty_lists[:only_types].is_a?(Array)
        q = q.where('(target_type IN (:ul))', { ul: ty_lists[:only_types] })
      elsif ty_lists[:except_types]
        q = q.where('(target_type NOT IN (:ul))', { ul: ty_lists[:except_types] })
      end
      
 #     if all_permissions.is_a?(Integer)
 #       q = q.where('((grants & :pm) = :pm)', { pm: all_permissions })
 #     elsif any_permissions.is_a?(Integer)
 #       q = q.where('((grants & :pm) != 0)', { pm: any_permissions })
 #     end

      q = _add_permission_clauses(q, opts)
      
      ts = _date_filter_timestamps(opts)
      wt = []
      wta = {}
      if ts[:c_after_ts]
        wt << '(created_at > :c_after_ts)'
        wta[:c_after_ts] = ts[:c_after_ts].to_time
      end
      if ts[:u_after_ts]
        wt << '(updated_at > :u_after_ts)'
        wta[:u_after_ts] = ts[:u_after_ts].to_time
      end
      if ts[:c_before_ts]
        wt << '(created_at < :c_before_ts)'
        wta[:c_before_ts] = ts[:c_before_ts].to_time
      end
      if ts[:u_before_ts]
        wt << '(updated_at < :u_before_ts)'
        wta[:u_before_ts] = ts[:u_before_ts].to_time
      end
      if wt.count > 0
        q = q.where(wt.join(' AND '), wta)
      end

      order_clauses = _parse_order_option(opts)
      q = q.order(order_clauses) if order_clauses.is_a?(Array)

      offset = (opts.has_key?(:offset)) ? opts[:offset] : nil
      q = q.offset(offset) if offset.is_a?(Integer) && (offset > 0)

      limit = (opts.has_key?(:limit)) ? opts[:limit] : nil
      q = q.limit(limit) if limit.is_a?(Integer) && (limit > 0)

      q
    end
    
    # Execute a query to fetch the number of grants for a given set of query options.
    # The number returned is subject to the configuration options +opts+; for example,
    # if <tt>opts[:only_data]</tt> is defined, the return value is the number of grants for the given
    # list of assets.
    #
    # @param opts [Hash] A Hash containing configuration options for the query.
    #  See the documentation for {.build_query}.
    #
    # @return [Integer] Returns the number of list items that would be returned by the query.

    def self.count_grants(opts = {})
      q = build_query(opts)
      (q.nil?) ? 0 : q.count
    end
    
    # Build a query to fetch target objects accessible to an actor.
    # This method uses the values of *actor* and *permissions* to set up appropriate values for
    # the query:
    #
    # - *actor* sets the value of the **only_granted_to** option. **except_granted_to** is removed
    #   from *opts*.
    # - *permissions* sets the value of the **all** permissions option. **permissions** is removed
    #   from *opts*.
    # - The {Fl::Framework::Access::Permission::Owner} permission is automatically added to the
    #   permission list, since ownership implies full access to assets.
    #
    # For example, to get all the target objects to which user `a1` has read access:
    #
    # ```
    # q = Fl::Framework::Access::Grant.accessible_query(a1, Fl::Framework::Access::Permission::Read)
    # objects = q.map { |g| g.target }
    # ```
    #
    # This query returns grants to `a1` for the `:read`, `:edit`, and `:manage` permissions (and `:owner`,
    # which is added implicitly).
    # To select just data of type `MyDatum`:
    #
    # ```
    # class MyDatum < ActiveRecord::Base
    #   include Fl::Framework::Access::Access
    #   has_access_control Fl::Framework::Access::GrantChecker.new
    # end
    #
    # q = Fl::Framework::Access::Grant.accessible_query(a1,
    #                                                   Fl::Framework::Access::Permission::Read,
    #                                                   only_types: MyDatum)
    # objects = q.map { |g| g.target }
    # ```
    #
    # @param actor [ActiveRecord::Base,String,Array<ActiveRecord::Base,String>] The actor (or actors)
    #  for which to return accessible objects. The most common value is a scalar, but you can pass an
    #  array if you want objects accessible by a number of actors (for example, to add group visibility).
    #  An invalid value (including `nil`) sets up the query to return an empty set.
    # @param permissions [Integer, Array<String,Fl::Framework::Access::Permission>] The permissions used
    #  to determine accessibility.
    #  An integer value contains a permission mask. An array value is converted to a list of permission
    #  masks, which are then ORed to get the final mask. Each element in the array is a string containing
    #  a permission name, or a permission object.
    #  A `nil` value turns off the permission filter, and returns all grants to *actor*.
    # @param opts [Hash] A Hash containing configuration options for the query.
    #  See the description for *opts* in {.build_query}.
    #  Note that the options **:only_granted_to**, **:except_granted_to**, **:only_permissions**,
    #  and **:except_permissions** are ignored.
    #
    # @return [ActiveRecord::Relation] If the query options are empty, the method returns `self`
    #  (and therefore the class object); if they are not empty, it returns an association relation.

    def self.accessible_query(actor, permissions, opts = {})
      opts = {} unless opts.is_a?(Hash) || opts.is_a?(ActionController::Parameters)

      actor_param = _normalize_actor(actor)
      return self.where('(1 = 0)') if actor_param.nil?
        
      iopts = { only_granted_to: actor_param }
      if !permissions.nil?
        iopts[:permissions] = [ { all: permissions }, :or,
                                { any: Fl::Framework::Access::Permission::Owner::BIT } ]
      end
      no = opts.reduce(iopts) do |acc, kvp|
        pk, pv = kvp
        spk = pk.to_sym
        case spk
        when :only_granted_to, :except_granted_to, :permissions
        else
          acc[spk] = pv
        end

        acc
      end

      self.build_query(no)
    end
    
    protected

    # The default properties to return from `to_hash`.
    DEFAULT_HASH_KEYS = [ :grants, :granted_to, :target ]

    # The additional verbose properties to return from `to_hash`.
    VERBOSE_HASH_KEYS = [ ]

    # Given a verbosity level, return predefined hash options to use.
    #
    # @param actor [Object] The actor for which we are building the hash representation.
    # @param verbosity [Symbol] The verbosity level; see #to_hash.
    # @param opts [Hash] The options that were passed to #to_hash. No options are processed by this method.
    #
    # @return [Hash] Returns a hash containing default options for +verbosity+.

    def to_hash_options_for_verbosity(actor, verbosity, opts)
      if (verbosity == :minimal) || (verbosity == :standard)
        {
          :include => DEFAULT_HASH_KEYS
        }
      elsif (verbosity == :verbose) || (verbosity == :complete)
        {
          :include => DEFAULT_HASH_KEYS | VERBOSE_HASH_KEYS
        }
      else
        {}
      end
    end

    # Build a Hash representation of the list.
    # This method returns a Hash that contains key/value pairs that describe the list.
    #
    # @param actor [Object] The actor for which we are building the hash representation.
    #  See the documentation for {Fl::Framework::ModelHash::InstanceMethods#to_hash} and 
    #  {Fl::Framework::ModelHash::InstanceMethods#to_hash_local}.
    # @param keys [Array<Symbols>] The keys to return.
    # @param opts [Hash] Options for the method. The listed options are in addition to the standard ones.
    #
    # @option opts [Hash] :to_hash[:objects] Hash options for the elements in the **:objects** key.
    #  The value is passed as the parameter to the `to_hash` call to the listed objects.
    #  Note that, to return objects in the hash, you have to place **:objects** in the **:include** key.
    #
    # @return [Hash] Returns a Hash containing the list representation.

    def to_hash_local(actor, keys, opts = {})
      to_hash_opts = opts[:to_hash] || {}

      rv = {}
      sp = nil
      keys.each do |k|
        case k
        when :granted_to
          to_opts = to_hash_opts_with_defaults(to_hash_opts[:granted_to], { verbosity: :minimal })
          rv[k] = self.granted_to.to_hash(actor, to_opts)
        when :target
          tg_opts = to_hash_opts_with_defaults(to_hash_opts[:target], { verbosity: :minimal })
          rv[k] = self.target.to_hash(actor, tg_opts)
        else
          rv[k] = self.send(k) if self.respond_to?(k)
        end
      end

      rv
    end

    private

    def self._get_permissions_mask(opts, pk)
      if opts.has_key?(pk)
        v = (opts[pk].is_a?(Array)) ? opts[pk] : [ opts[pk] ]

        v.reduce(0) do |acc, e|
          if e.is_a?(Integer)
            acc |= e
          elsif e.is_a?(String)
            if (e =~ /^[0-9]+$/) || (e =~ /^0x[0-9a-f]+/i)
              acc |= e.to_i
            else
              n = Fl::Framework::Access::Helper.permission_name(e)
              acc |= Fl::Framework::Access::Permission.permission_mask(n) if n
            end
          elsif e.is_a?(Symbol) || (e < Fl::Framework::Access::Permission)
            n = Fl::Framework::Access::Helper.permission_name(e)
            acc |= Fl::Framework::Access::Permission.permission_mask(n) if n
          end
          
          acc
        end
      else
        nil
      end
    end

    PERMISSION_OPS = [ :or, :OR, :and, :AND, 'or', 'OR', 'and', 'AND' ]
    
    def self._add_permission_clauses(q, opts)
      if opts.has_key?(:permissions)
        pl = (opts[:permissions].is_a?(Array)) ? opts[:permissions] : [ opts[:permissions] ]

        prev = nil
        wh = { }
        wi = 0
        ws = pl.reduce('(') do |acc, p|
          if (p.is_a?(String) || p.is_a?(Symbol)) && PERMISSION_OPS.include?(p)
            prev = p.to_sym
            acc << " #{p.to_s.upcase} "
          else
            acc << ' AND ' if !prev.nil? && !prev.is_a?(Symbol)

            if p.is_a?(Hash) || p.is_a?(ActionController::Parameters)
              if p.has_key?(:all)
                k = "pm#{wi}".to_sym
                prev = "((grants & :#{k}) = :#{k})"
                acc << prev
                wh[k] = _get_permissions_mask(p, :all)
                wi += 1
              elsif p.has_key?(:any)
                k = "pm#{wi}".to_sym
                prev = "((grants & :#{k}) != 0)"
                acc << prev
                wh[k] = _get_permissions_mask(p, :any)
                wi += 1
              else
                # if the hash does not contain :all or :any, we just shut down the query here
                
                k = "pm#{wi}".to_sym
                prev = "((grants & :#{k}) = :#{k})"
                acc << prev
                wh[k] = 0
                wi += 1
              end
            else
              k = "pm#{wi}".to_sym
              prev = "((grants & :#{k}) = :#{k})"
              acc << prev
              wh[k] = _get_permissions_mask({ all: p }, :all)
              wi += 1
            end
          end

          acc
        end

        # OK we have built the clauses

        q = q.where(ws + ')', wh)
      end

      q
    end


    # @param actor [ActiveRecord::Base,String,Array<ActiveRecord::Base,String>] The actor (or actors)
    #  for which to return accessible objects. The most common value is a scalar, but you can pass an
    #  array if you want objects accessible by a number of actors (for example, to add group visibility).
    #  An invalid value (including `nil`) sets up the query to return an empty set.
    # @param permissions [Integer, Array<String,Fl::Framework::Access::Permission>] The permissions used
    #  to determine accessibility.
    #  An integer value contains a permission mask. An array value is converted to a list of permission
    #  masks, which are then ORed to get the final mask. Each element in the array is a string containing
    #  a permission name, or a permission object.
    #  A `nil` value turns off the permission filter, and returns all grants to *actor*.
    # @param opts [Hash] A Hash containing configuration options for the query.
    #  See the description for *opts* in {.build_query}.
    #  Note that the options **:only_granted_to**, **:except_granted_to**, **:only_permissions**,
    #  and **:except_permissions** are ignored.
    #
    # @return [ActiveRecord::Relation] If the query options are empty, the method returns `self`
    #  (and therefore the class object); if they are not empty, it returns an association relation.

    def self._normalize_actor(actor)
      a = (actor.is_a?(Array)) ? actor : [ actor ]

      a.each do |e|
        return nil if e.nil? || (!e.is_a?(String) && !e.respond_to?(:fingerprint))
      end

      a
    end
    
    def check_grants()
      if self.grants && (self.grants == 0)
        errors.add(:grants, I18n.tx('fl.framework.access.grant.model.validate.empty_grants'))
      end
    end
    
    def set_fingerprints()
      self.granted_to_fingerprint = self.granted_to.fingerprint if self.granted_to
      self.target_fingerprint = self.target.fingerprint if self.target
    end
  end
end
