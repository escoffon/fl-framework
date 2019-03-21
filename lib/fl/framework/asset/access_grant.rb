module Fl::Framework::Asset
  # Model class for asset access grants.
  #
  # Note that access grants can only be created or destroyed: there is no provision to reassign the
  # grant to a different actor, or to associate a different asset with the grant.
  
  class AccessGrant < Fl::Framework::ApplicationRecord
    include Fl::Framework::Core::ModelHash
    extend Fl::Framework::Query
    
    self.table_name = 'fl_framework_access_grants'
    
    # @!attribute [r] permission
    # The name of the permission associated with the grant; you can use
    # {Fl::Framework::Access::Permission.lookup} to obtain the corresponding permission object.
    # @return [String] Returns the name of the permission.    

    # @!attribute [r] actor
    # A `belongs_to` association to the entity that is granted permission.
    # This association is polymorphic.
    # @return [Association] the actor that is granted {#permission}.

    belongs_to :actor, polymorphic: true

    # @!attribute [r] asset
    # A `belongs_to` association to the asset for which permission is granted.
    # This association is not polymorphic.
    # @return [Association] the asset that grants {#permission} to {#actor}.

    belongs_to :asset, class_name: 'Fl::Framework::Asset::AssetRecord'

    # @!attribute [r] data_object
    # A `belongs_to` association to the actual data object for which permission is granted.
    # This association is polymorphic.
    #
    # Note that this object can also be obtained via the `asset` association in {#asset}; it is
    # provided here directly as a denormalization used by the schema to optimize queries.
    # We mark this association optional so that an initial object is valid; the create hook will
    # populate it.
    #
    # @return [Association] the data object wrapped by the asset.

    belongs_to :data_object, polymorphic: true, optional: true
    
    before_create :set_fingerprints_and_data

    validates :permission, presence: true
    validate :check_permission
    
    # Constructor.
    #
    # @param attrs [Hash] A hash of initialization parameters.
    #  Must include **:permission**, **:actor**, and **:asset**.
    #  If **:permission** is a {Fl::Framework::Access::Permission}, it is converted to its name.
    #  If **:actor** and **:asset** are strings, they are assumed to be fingerprints to the actual
    #  objects.

    def initialize(attrs = {})
      attrs = attrs || {}

      if attrs.has_key?(:permission)
        attrs[:permission] = Fl::Framework::Access::Helper.permission_name(attrs[:permission])
      end
      
      if attrs[:actor].is_a?(String)
        attrs[:actor] = self.class.find_by_fingerprint(attrs[:actor])
      end

      if attrs[:asset].is_a?(String)
        attrs[:asset] = self.class.find_by_fingerprint(attrs[:asset])
      end

      attrs.delete(:data_object)
      
      super(attrs)
    end

    # Bulk update.
    # The implementation is a no-op: all attributes are stripped from *attrs*.
    #
    # @param attrs [Hash] The attributes, which are currently ignored.

    def update_attributes(attrs)
      super({})
    end
  
    # Build a query to fetch access grants.
    #
    # Note that any WHERE clauses from *:updated_after*, *:created_after*, *:updated_before*,
    # and *:created_before* are concatenated using the AND operator. The values for these options are:
    # a UNIX timestamp; a Time object; a string containing a representation of the time (this string
    # is converted to a {Fl::Framework::Core::Icalendar::Datetime} internally).
    #
    # @param opts [Hash] A Hash containing configuration options for the query.
    # @option opts [Array<Object,String>, Object, String] :only_actors Limit the returned values to grants
    #  whose `actor` attribute is in the option's value
    #  (technically, whose `actor_id` and `actor_type` attribute pairs are in the list derived from the
    #  option's value).
    #  The elements in an array value are object instances or object fingerprints; note that identifiers
    #  are not supported, because the `actor` association is polymorphic.
    #  If this option is not present, all grants are selected.
    # @option opts [Array<Object,String>, Object, String] :except_actors Limit the returned values to grants
    #  whose `actor` attribute is not in the option's value
    #  (technically, whose `actor_id` and `actor_type` attribute pairs are not in the list derived from the
    #  option's value).
    #  The elements in an array value are object instances or object fingerprints; note that identifiers
    #  are not supported, because the `actor` association is polymorphic.
    #  If this option is not present, all records are selected.
    # @option opts [Array<Object,String,Integer>, Object, String] :only_data Limit the returned
    #  values to grants whose `data_object` attribute is in the option's value
    #  (technically, whose `data_object_type` and `data_object_id` attributes are in the list derived from
    #  the option's value).
    #  The elements in an array value are object instances or object fingerprints; note that identifiers
    #  are not supported, because the `data_object` association is polymorphic.
    #  If this option is not present, all grants are selected.
    # @option opts [Array<Object,String,Integer>, Object, String] :except_data Limit the returned
    #  values to grants whose `data_object` attribute is not in the option's value
    #  (technically, whose `data_object_type` and `data_object_id` attributes are not in the list derived
    #  from the option's value).
    #  The elements in an array value are object instances or object fingerprints; note that identifiers
    #  are not supported, because the `data_object` association is polymorphic.
    #  If this option is not present, all grants are selected.
    # @option opts [Array<Object,String>, Object, String] :only_types Limit the returned
    #  values to grants whose `data_object_type` attribute is in the option's value
    #  (technically, whose `data_object_type` attribute is in the list derived from the option's value).
    #  The elements in an array value are strings or classes; the strings contain class names, and the
    #  classes are converted to class names.
    #  If this option is not present, all grants are selected.
    # @option opts [Array<Object,String>, Object, String] :except_types Limit the returned
    #  values to grants whose `data_object_type` attribute is not in the option's value
    #  (technically, whose `data_object_type` attribute is not in the list derived from the option's value).
    #  The elements in an array value are strings or classes; the strings contain class names, and the
    #  classes are converted to class names.
    #  If this option is not present, all grants are selected.
    # @option opts [Array,scalar] :only_permissions Limit the returned
    #  values to grants whose `permission` attribute is in the option's value
    #  (technically, whose `permission` attribute is in the list derived from the option's value).
    #  A scalar value, or an element in an array value, is extracted using
    #  {Fl::Framework::Access:Helper.permission_name}.
    #  If this option is not present, all grants are selected.
    #  Note that this option (and **:except_permissions**) does not expand permission grants; if you
    #  are interested in, say, all assets readable by a given actor, use the specialized
    #  method {.accessible_query}, which does expand grants.
    # @option opts [Array,scalar] :except_permissions Limit the returned
    #  values to grants whose `permission` attribute is not in the option's value
    #  (technically, whose `permission` attribute is not in the list derived from the option's value).
    #  A scalar value, or an element in an array value, is extracted using
    #  {Fl::Framework::Access:Helper.permission_name}.
    #  If this option is not present, all grants are selected.
    # @option opts [Integer, Time, String] :updated_after selects list items updated after a given time.
    # @option opts [Integer, Time, String] :created_after selects list items created after a given time.
    # @option opts [Integer, Time, String] :updated_before selects list items updated before a given time.
    # @option opts [Integer, Time, String] :created_before selects list items created before a given time.
    # @option opts [Integer] :offset Sets the number of records to skip before fetching;
    #  a +nil+ value causes the option to be ignored.
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
    # Note that *:limit*, *:offset*, and *:includes* are convenience options, since they can be
    # added later by making calls to +limit+, +offset+, and +includes+ respectively, on the
    # return value. But there are situations where the return type is hidden inside an API wrapper, and
    # the only way to trigger these calls is through the configuration options.
    #
    # @return [ActiveRecord::Relation] If the query options are empty, the method returns `self`
    #  (and therefore the class object); if they are not empty, it returns an association relation.

    def self.build_query(opts = {})
      q = self

      if opts[:includes]
        i = (opts[:includes].is_a?(Array) || opts[:includes].is_a?(Hash)) ? opts[:includes] : [ opts[:includes] ]
        q = q.includes(i)
      else
        q = q.includes(:actor, :data_object)
      end

      a_lists = partition_lists_of_polymorphic_references(opts, 'actors')
      d_lists = partition_lists_of_polymorphic_references(opts, 'data')
      p_lists = partition_filter_lists(opts, 'permissions') do |pl|
        pl.map { |p| Fl::Framework::Access::Helper.permission_name(p) }
      end
      t_lists = partition_filter_lists(opts, 'types') do |dl|
        dl.map do |d|
          if d.is_a?(Class)
            d.name
          else
            d.to_s
          end
        end
      end

      # if :only_actors is nil, and :except_actors is also nil, the two options will create an empty set,
      # so we can short circuit here.
      # and similarly for :only_data and :except_data, :only_permissions and :except_permissions,
      # and :only_types and :except_types

      a_nil_o = a_lists.has_key?(:only_actors) && a_lists[:only_actors].nil?
      a_nil_x = a_lists.has_key?(:except_actors) && a_lists[:except_actors].nil?
      d_nil_o = d_lists.has_key?(:only_data) && d_lists[:only_data].nil?
      d_nil_x = d_lists.has_key?(:except_data) && d_lists[:except_data].nil?
      p_nil_o = p_lists.has_key?(:only_permissions) && p_lists[:only_permissions].nil?
      p_nil_x = p_lists.has_key?(:except_permissions) && p_lists[:except_permissions].nil?
      t_nil_o = t_lists.has_key?(:only_types) && t_lists[:only_types].nil?
      t_nil_x = t_lists.has_key?(:except_types) && t_lists[:except_types].nil?

      if a_nil_o && a_nil_x && d_nil_o && d_nil_x && p_nil_o && p_nil_x && t_nil_o && t_nil_x
        return q.where('(1 = 0)')
      end
    
      if d_lists[:only_data].is_a?(Array)
        # If we have :only_data, the :except_data have already been eliminated, so all we need
        # is the only_data

        q = q.where('(data_object_fingerprint IN (:ul))', { ul: d_lists[:only_data] })
      elsif d_lists[:except_data]
        # since only_data is not present, we need to add the except_data

        q = q.where('(data_object_fingerprint NOT IN (:ul))', { ul: d_lists[:except_data] })
      end

      if a_lists[:only_actors].is_a?(Array)
        # If we have :only_actors, the :except_actors have already been eliminated, so all we need
        # is the only_actors

        q = q.where('(actor_fingerprint IN (:ul))', { ul: a_lists[:only_actors] })
      elsif a_lists[:except_actors]
        # since only_actors is not present, we need to add the except_actors

        q = q.where('(actor_fingerprint NOT IN (:ul))', { ul: a_lists[:except_actors] })
      end
    
      if p_lists[:only_permissions].is_a?(Array)
        # If we have :only_permissions, the :except_permissions have already been eliminated, so all we need
        # is the only_permissions

        q = q.where('(permission IN (:ul))', { ul: p_lists[:only_permissions] })
      elsif p_lists[:except_permissions]
        # since only_permissions is not present, we need to add the except_permissions

        q = q.where('(permission NOT IN (:ul))', { ul: p_lists[:except_permissions] })
      end
    
      if t_lists[:only_types].is_a?(Array)
        # If we have :only_types, the :except_types have already been eliminated, so all we need
        # is the only_types

        q = q.where('(data_object_type IN (:ul))', { ul: t_lists[:only_types] })
      elsif t_lists[:except_types]
        # since only_types is not present, we need to add the except_types

        q = q.where('(data_object_type NOT IN (:ul))', { ul: t_lists[:except_types] })
      end
      
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
  
    # Build a query to fetch data objects accessible to an actor.
    # This method sets up the permission filters as requested by *permissions*, merges the *opts*
    # values, and calls {.build_query} to generate the query.
    #
    # Note that, differently from {.build_query}, this method expands the grantors for the permission
    # list: for example, a `:read` request is expanded to its grantors `:edit` and `:manage`, and the
    # expanded list is placed in **:only_permissions**.
    # Also, the {Fl::Framework::Asset::Permission::Owner} permission is automatically added to the
    # permission list, since ownership implies full access to assets.
    #
    # For example, to get all the data objects to which user *a1* has read access:
    #
    # ```
    # q = Fl::Framework::Asset::AccessGrant.accessible_query(a1, Fl::Framework::Access::Permission::Read)
    # objects = q.map { |g| g.data_object }
    # ```
    #
    # This query returns grants to *a1* for the `:read`, `:edit`, and `:manage` permissions (and `:owner`,
    # which is added implicitly).
    # To select just data of type `MyDatum`:
    #
    # ```
    # class MyDatum < ActiveRecord::Base
    #   include Fl::Framework::Asset::Asset
    #   include Fl::Framework::Access::Access
    #   is_asset
    #   has_access_control Fl::Framework::Asset::AccessChecker.new
    # end
    #
    # q = Fl::Framework::Asset::AccessGrant.accessible_query(a1,
    #                                                        Fl::Framework::Access::Permission::Read,
    #                                                        only_types: MyDatum)
    # objects = q.map { |g| g.data_object }
    # ```
    #
    # @param actor [Object] The actor for which to return accessible objects.
    # @param permissions [Array,scalar] An array of permission specifiers, or a single permission
    #  specifier. This array is loaded into the **:only_permissions** option to {.build_query}.
    #  The special value `:any` indicates that all permissions are acceptable.
    # @param opts [Hash] A Hash containing configuration options for the query.
    #  See the description for *opts* in {.build_query}.
    #  Note that the options **:only_actors**, **:except_actors**, **:only_permissions**,
    #  and **:except_permissions** are ignored.
    #
    # @return [ActiveRecord::Relation] If the query options are empty, the method returns `self`
    #  (and therefore the class object); if they are not empty, it returns an association relation.

    def self.accessible_query(actor, permissions, *opts)
      no = { only_actors: actor }
      if permissions != :any
        pl = (permissions.is_a?(Array)) ? permissions : [ permissions ]
        plist = pl.reduce([ ]) do |acc, p|
          pn = Fl::Framework::Access::Helper.permission_name(p)
          acc |= [ pn ]
          acc |= Fl::Framework::Access::Permission.grantors_for_permission(pn)
          acc
        end

        no[:only_permissions] = plist | [ Fl::Framework::Asset::Permission::Owner::NAME ]
      end

      if opts.count > 0
        opts[0].each do |ok, ov|
          case ok.to_sym
          when :only_actors, :except_actors, :only_permissions, :except_permissions
          else
            no[ok] = ov
          end
        end
      end
             
      self.build_query(no)
    end
    
    protected

    # The default properties to return from `to_hash`.
    DEFAULT_HASH_KEYS = [ :permission, :actor, :asset ]

    # The additional verbose properties to return from `to_hash`.
    VERBOSE_HASH_KEYS = [ :data_object ]

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
        when :actor
          act_opts = to_hash_opts_with_defaults(to_hash_opts[:actor], { verbosity: :minimal })
          rv[k] = self.actor.to_hash(actor, act_opts)
        when :asset
          ass_opts = to_hash_opts_with_defaults(to_hash_opts[:asset], { verbosity: :minimal })
          rv[k] = self.asset.to_hash(actor, ass_opts)
        when :data_object
          # This is a paranoid check in case the caller generates a hash representation before the
          # object is saved
          
          if self.data_object
            do_opts = to_hash_opts_with_defaults(to_hash_opts[:data_object], { verbosity: :minimal })
            rv[k] = self.data_object.to_hash(actor, do_opts)
          else
            rv[k] = nil
          end
        else
          rv[k] = self.send(k) if self.respond_to?(k)
        end
      end

      rv
    end

    private

    def check_permission()
      if self.permission && Fl::Framework::Access::Permission.lookup(self.permission).nil?
        errors.add(:permission, I18n.tx('fl.framework.access_grant.model.validate.unknown_permission',
                                        permission: self.permission))
      end
    end
    
    def set_fingerprints_and_data()
      self.data_object = self.asset.asset if self.asset
      
      self.actor_fingerprint = self.actor.fingerprint if self.actor
      self.data_object_fingerprint = self.data_object.fingerprint if self.data_object
    end
  end
end
