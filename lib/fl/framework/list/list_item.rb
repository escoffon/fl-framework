module Fl::Framework::List
  # An item in a list.
  # Instances of this class manage the relationship between an object and its container list.
  # This creates a layer of indirection between a list and its contents that adds these properties
  # to the relationship:
  #
  # - An object can be placed in multiple lists.
  # - The relationship has an "owner" that may be different from the owner of the listed object.
  # - It is possible to associate a name with the listed object, and then use
  #   {Fl::Framework::List::List#resolve_path} to find objects by name in a containment hierarchy.
  # - The relationship has a status, so that for example an item can be marked "selected."
  #   Note that, because an object can belong to multiple lists, its status may be different in two
  #   different lists.
  #
  # #### Associations
  #
  # The class defines the following associations:
  #
  # - {#owner} is a polymorphic `belongs_to` association linking to the entity that owns the list item
  #   (the creator). Note that this is a readonly value: once set in the constructor, the owner cannot be
  #   changed.
  # - {#list} is a `belongs_to` association linking to the container list (an instance of
  #   {Fl::Framework::List::List}).
  #   Note that this is a readonly value: once set in the constructor, the list cannot be changed.
  # - {#listed_object} is a polymorphic `belongs_to` association linking to the actual object in the item.
  #   Note that this is a readonly value: once set in the constructor, the listed object cannot be
  #   changed.
  # - {#state_updated_by} is a polymorphic `belongs_to` association linking to the entity that last
  #   modified the state of the item.
  
  class ListItem < Fl::Framework::ApplicationRecord
    include Fl::Framework::Core::ModelHash
    include Fl::Framework::Core::AttributeFilters
    extend Fl::Framework::Query

    self.table_name = 'fl_framework_list_items'

    # @!visibility private
    StateByValue = {}
    # @!visibility private
    StateByName = {}

    # The name of the deselected state.
    STATE_SELECTED = :selected

    # The name of the selected state.
    STATE_DESELECTED = :deselected

    # @!attribute [r] list
    # A `belongs_to` association linking to the list to which the list item belongs.
    # @return [Association] the container list.
    
    belongs_to :list, class_name: 'Fl::Framework::List::List'

    # @!attribute [r] listed_object
    # A polymorphic `belongs_to` association linking to the actual object in the list.
    # @return [Association] the listed object.

    belongs_to :listed_object, polymorphic: true

    # @!attribute [rw] listed_object_class_name
    # The class name of the listed object; this may differ from **:listed_object_type** under some
    # circumstances, for example if the listed object is part of a Single Table Inheritance hierarchy.
    # @return [String] the class name of the listed object.

    # @!attribute [r] owner
    # The owner of the relationship; note that the owner could be different from the listed object's
    # owner.
    # @return [Association] the owner.
    
    belongs_to :owner, polymorphic: true, optional: true

    # @!attribute [rw] name
    # The name of the item. This name can be used to identify items within a list, in particular
    # when resolving paths (see {List#resolve_path}).
    # It is case sensitive, must not contain `/` (forward slash) or `\` (backslash), must be at most
    # 200 characters long, and must be unique within the context of a list.
    # @return [String] the item's name (path component)

    # @!attribute [rw] readonly_state
    # This attribute controls if the list item can be modified (by changing its state).
    # @return [Boolean] the readonly state of the list item.
    
    # @!attribute [rw] state_updated_by
    # A polymorphic `belongs_to` association linking to the entity that last modified the item's state.
    # @return [Association] the updater.

    belongs_to :state_updated_by, polymorphic: true, optional: true

    validate :object_must_be_listable
    validate :check_duplicate_entries, :on => :create
    validate :validate_state
    validates :name, :length => { :maximum => 200 }
    validate :validate_name

    before_create :object_state_defaults_for_create, :set_class_name_field, :set_fingerprints
    after_create :update_list_timestamps
    after_destroy :check_list_item
    after_destroy :update_list_timestamps
    before_save :object_state_defaults_for_save
    before_save :refresh_item_summary
    after_save :bump_list_timestamp

    filtered_attribute :state_note, [ FILTER_HTML_STRIP_DANGEROUS_ELEMENTS ]

    # Constructor.
    #
    # @param attrs [Hash] A hash of initialization parameters.

    def initialize(attrs = {})
      rv = super(attrs)

      self.owner = self.list.owner if !self.owner && self.list
      self.state = Fl::Framework::List::ListItem::STATE_SELECTED unless self.state?
      self.state_updated_by = self.owner unless self.state_updated_by

      # A newly created list object will cause the list update time to be bumped

      @bump_list_update_time = true

      rv
    end

    # Update attributes.
    # The method removes **:list**, **:listed_object**, **:owner** from *attrs* before calling the
    # superclass implementation.
    #
    # @param attrs [Hash] The attributes.
    #
    # @return @returns the return value from the `super` call.

    def update_attributes(attrs)
      nattrs = attrs.reduce({}) do |acc, a|
        ak, av = a
        case ak
        when :list, :listed_object, :owner
        else
          acc[ak] = av
        end

        acc
      end

      super(nattrs)
    end

    # The setter for the list.
    # Does not change the value of {#list} if the object is persisted.
    #
    # @param l [Fl::Framework::List::List] The list.

    def list=(l)
      super(l) unless self.persisted?
    end

    # The setter for the listed object.
    # Does not change the value of {#listed_object} if the object is persisted.
    #
    # @param o [ActiveRecord::Base] The listed object.

    def listed_object=(o)
      super(o) unless self.persisted?
    end
    
    # The setter for the state.
    # This method sets the state to *state*, the state timestamp to the current time, and the state user
    # to the owner. Because of this behavior, clients should call {#set_state} instead, which
    # lets them specify a user.
    #
    # @param state The state: a symbol or an integer value.

    def state=(state)
      set_state(state, nil)
    end

    # The getter for the state.
    #
    # @return Returns a symbolic representation of the state.

    def state()
      Fl::Framework::List::ListItem.state_from_db(read_attribute(:state))
    end

    # Sets the state, by a given actor.
    #
    # @param state [Symbol,String,Integer] The state: a symbol or string, or an integer value.
    # @param actor The actor that should be marked as having set the state; if @c nil, the owner is used.

    def set_state(state, actor = nil)
      write_attribute(:state, Fl::Framework::List::ListItem.state_to_db(state))
      write_attribute(:state_updated_at, Time.new)

      self.state_updated_by = (actor.nil?) ? self.owner : actor

      # setting the state will cause the update time on the list to be bumped

      @bump_list_update_time = true
    end

    # Set the note associated with the state.
    #
    # @param note [String] A string containing the note.

    def state_note=(note)
      super(note)

      # setting the state note will cause the update time on the list to be bumped

      @bump_list_update_time = true
    end
  
    # Build a query to fetch list items.
    # The query supports getting list items for one or more (including all) lists.
    #
    # Note that any WHERE clauses from *:updated_after*, *:created_after*, *:updated_before*,
    # and *:created_before* are concatenated using the AND operator. The values for these options are:
    # a UNIX timestamp; a Time object; a string containing a representation of the time (this string
    # is converted to a {Fl::Framework::Core::Icalendar::Datetime} internally).
    #
    # @param opts [Hash] A Hash containing configuration options for the query.
    # @option opts [Array<Fl::Framework::List::List,Integer,String>, Fl::Framework::List::List, Integer, String] :only_lists Limit the returned values to list items whose `list` attribute is in the option's value
    #  (technically, whose `list_id` attribute is in the list of identifier derived from the option's value).
    #  The elements in an array value are {Fl::Framework::List::List} instances, list identifiers, or
    #  object fingerprints.
    #  If this option is not present, all list items are selected.
    # @option opts [Array<Fl::Framework::List::List,Integer,String>, Fl::Framework::List::List, Integer, String] :except_lists Limit the returned values to list items whose `list` attribute is not in the option's value
    #  (technically, whose `list_id` attribute is not in the list of identifier derived from the option's
    #  value).
    #  The elements in an array value are {Fl::Framework::List::List} instances, list identifiers, or
    #  object fingerprints.
    #  If this option is not present, all list items are selected.
    # @option opts [Array<Object,String>, Object, String] :only_owners Limit the returned values to list
    #  items whose `owner` attribute is in the option's value
    #  (technically, whose `owner_id` and `owner_type` attribute pairs are in the list derived from the
    #  option's value).
    #  The elements in an array value are object instances or object fingerprints; note that identifiers
    #  are not supported, because the `owner` association is polymorphic.
    #  If this option is not present, all list items are selected.
    # @option opts [Array<Object,String>, Object, String] :except_owners Limit the returned values to list
    #  items whose `owner` attribute is not in the option's value
    #  (technically, whose `owner_id` and `owner_type` attribute pairs are not in the list derived from the
    #  option's value).
    #  The elements in an array value are object instances or object fingerprints; note that identifiers
    #  are not supported, because the `owner` association is polymorphic.
    #  If this option is not present, all list items are selected.
    # @option opts [Array<Object,String>, Object, String] :only_listables Limit the returned values to list
    #  items whose `listed_object` attribute is in the option's value
    #  (technically, whose `listed_object_id` and `listed_object_type` attribute pairs are in the list
    #  derived from the option's value).
    #  The elements in an array value are object instances or object fingerprints; note that identifiers
    #  are not supported, because the `listed_object` association is polymorphic.
    #  If this option is not present, all list items are selected.
    # @option opts [Array<Object,String>, Object, String] :except_listables Limit the returned values to list
    #  items whose `listed_object` attribute is not in the option's value
    #  (technically, whose `listed_object_id` and `listed_object_type` attribute pairs are not in the list
    #  derived from the option's value).
    #  The elements in an array value are object instances or object fingerprints; note that identifiers
    #  are not supported, because the `listed_object` association is polymorphic.
    #  If this option is not present, all list items are selected.
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
    #  Defaults to <tt>list_id ASC, sort_order ASC</tt>, so that the records are ordered by sort order
    #  and grouped by list.
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
      end

      l_lists = _partition_list_lists(opts)
      o_lists = _partition_owner_lists(opts)
      p_lists = _partition_listable_lists(opts)

      # if :only_owners is nil, and :except_owners is also nil, the two options will create an empty set,
      # so we can short circuit here.
      # and similarly for :only_lists and :except_lists, and :only_listables and :except_listables

      o_nil_o = o_lists.has_key?(:only_owners) && o_lists[:only_owners].nil?
      o_nil_x = o_lists.has_key?(:except_owners) && o_lists[:except_owners].nil?
      l_nil_o = l_lists.has_key?(:only_lists) && l_lists[:only_lists].nil?
      l_nil_x = l_lists.has_key?(:except_lists) && l_lists[:except_lists].nil?
      p_nil_o = p_lists.has_key?(:only_listables) && p_lists[:only_listables].nil?
      p_nil_x = p_lists.has_key?(:except_listables) && p_lists[:except_listables].nil?

      if o_nil_o && o_nil_x && l_nil_o && l_nil_x && p_nil_o && p_nil_x
        return q.where('(1 = 0)')
      end
    
      if l_lists[:only_lists].is_a?(Array)
        # If we have :only_lists, the :except_lists have already been eliminated, so all we need
        # is the only_lists

        q = q.where('(list_id IN (:ul))', { ul: l_lists[:only_lists] })
      elsif l_lists[:except_lists]
        # since only_lists is not present, we need to add the except_lists

        q = q.where('(list_id NOT IN (:ul))', { ul: l_lists[:except_lists] })
      end

      if p_lists[:only_listables].is_a?(Array)
        # If we have :only_listables, the :except_listables have already been eliminated, so all we need
        # is the only_listables

        q = q.where('(listed_object_fingerprint IN (:ul))', { ul: p_lists[:only_listables] })
      elsif p_lists[:except_listables]
        # since only_listables is not present, we need to add the except_listables

        q = q.where('(listed_object_fingerprint NOT IN (:ul))', { ul: p_lists[:except_listables] })
      end

      if o_lists[:only_owners].is_a?(Array)
        # If we have :only_owners, the :except_owners have already been eliminated, so all we need
        # is the only_owners

        q = q.where('(owner_fingerprint IN (:ul))', { ul: o_lists[:only_owners] })
      elsif o_lists[:except_owners]
        # since only_owners is not present, we need to add the except_owners

        q = q.where('(owner_fingerprint NOT IN (:ul))', { ul: o_lists[:except_owners] })
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

      order_clauses = _parse_order_option(opts, 'list_id ASC, sort_order ASC')
      q = q.order(order_clauses) if order_clauses.is_a?(Array)

      offset = (opts.has_key?(:offset)) ? opts[:offset] : nil
      q = q.offset(offset) if offset.is_a?(Integer) && (offset > 0)

      limit = (opts.has_key?(:limit)) ? opts[:limit] : nil
      q = q.limit(limit) if limit.is_a?(Integer) && (limit > 0)

      q
    end
  
    # Execute a query to fetch the number of list items for a given set of query options.
    # The number returned is subject to the configuration options +opts+; for example,
    # if <tt>opts[:only_lists]</tt> is defined, the return value is the number of list items whose
    # list identifiers are in the option.
    #
    # @param opts [Hash] A Hash containing configuration options for the query.
    #  See the documentation for {.build_query}.
    #
    # @return [Integer] Returns the number of list items that would be returned by the query.

    def self.count_list_items(opts = {})
      q = build_query(opts)
      (q.nil?) ? 0 : q.count
    end
    
    # Generate a query for list items in a single list.
    # This can be accomplished via {.build_query} by passing an appropriate value for
    # the **:only_lists** option, and it is implemented as such, but is provided as a separate
    # method for convenience.
    #
    # @param list [Fl::Framework::List::List, String] The list for which to get list items; the value
    #  is either an onject, or a string containing the listable's fingerprint.
    # @param opts [Hash] Additional options for the query; these are merged with **:only_lists**
    #  and passed to {.build_query}.
    #
    # @return [ActiveRecord::Relation] Returns a relation.

    def self.query_for_list(list, opts = {})
      build_query({ order: 'sort_order ASC' }.merge(opts).merge({ only_lists: list }))
    end
    
    # Generate a query for list items that contain a given listable.
    # This can be accomplished via {.build_query} by passing an appropriate value for
    # the **:only_listables** option, and it is implemented as such, but is provided as a separate
    # method for convenience.
    #
    # Note that this method (indirectly) returns all lists where *listable* is defined; `map` the
    # returned value to generate an array of lists:
    #
    # ```
    # lists = Fl::Framework::List::ListItem.query_for_listable(listable).map { |li| li.list }
    # ```
    #
    # @param listable [Object, String] The listable object for which to get list items; the value is either
    #  an onject, or a string containing the listable's fingerprint.
    # @param opts [Hash] Additional options for the query; these are merged with **:only_listables**
    #  and passed to {.build_query}.
    #
    # @return [ActiveRecord::Relation] Returns a relation.

    def self.query_for_listable(listable, opts = {})
      build_query({ order: 'updated_at DESC' }.merge(opts).merge({ only_listables: listable }))
    end
          
    # Generate a query for the list item for a given listable in a given list.
    #
    # @param listable [Object, String] The listable object to look up; a string value is assumed to be
    #  a fingerprint.
    # @param list [Fl::Framework::List::List, String] The list to search; a string value is assumed to be
    #  a fingerprint.
    #
    # @return [ActiveRecord::Relation] Returns a relation; calling `first` on the return value should
    #  return the list item, or `nil` if *listable* is not in *list*.

    def self.query_for_listable_in_list(listable, list)
      lid = (list.is_a?(String)) ? split_fingerprint(list)[1] : list.id
      fp = (listable.is_a?(String)) ? listable : listable.fingerprint
      
      self.where('(list_id = :lid) AND (listed_object_fingerprint = :fp)', { lid: lid, fp: fp })
    end
          
    # Find a listable in a list.
    # This method wraps around {.query_for_listable_in_list}, calling `first` on its return value,
    # and then getting the **:listed_object** attribute.
    #
    # @param listable [Object, String] The listable object to look up; a string value is assumed to be
    #  a fingerprint.
    # @param list [Fl::Framework::List::List, String] The list to search; a string value is assumed to be
    #  a fingerprint.
    #
    # @return [Object] If *listable* is present in *list*, returns *listable*; otherwise, returns `nil`.

    def self.find_listable_in_list(listable, list)
      li = query_for_listable_in_list(listable, list).first
      (li.nil?) ? nil : li.listed_object
    end

    # Refresh the denormalized **:item_summary** attribute for a given listed object.
    # This method runs an UPDATE SQL statement that sets the **:item_summary** column for all
    # records associated with the listed object *listable*.
    #
    # @param listable The listable object whose list item summary is to be placed in associated records
    #  of the list objects table.

    def self.refresh_item_summaries(listable)
      # Since we can't seem to be able to use bind variables, let's just sanitize the SQL

      sql = "UPDATE #{table_name} SET "
      sql += sanitize_sql_for_assignment({ :item_summary => listable.list_item_summary })
      sql += ' WHERE ('
      sql += sanitize_sql_for_conditions([ '(listed_object_fingerprint = :fp)', fp: listable.fingerprint ])
      sql += ')'
      self.connection.exec_update(sql, "item_summary_update")
    end

    # Convert a state symbol to a value as stored in the database.
    #
    # @param state [Symbol,String,Numeric] The symbolic value of the state.
    #
    # @return [Integer,nil] Returns the converted value, `nil` if *state* is not a valid name
    #  (or a valid value).

    def self.state_to_db(state)
      return nil if state.nil?

      load_list_item_state_values()

      case state
      when Numeric
        state_i = state.to_i
        (StateByValue.has_key?(state_i)) ? state_i : nil
      else
        state_s = state.to_s
        if state_s =~ /^(\+|\-)?[0-9]+$/
          state_i = state_s.to_i
          (StateByValue.has_key?(state_i)) ? state_i : nil
        else
          state_y = state.to_sym
          (StateByName.has_key?(state_y)) ? StateByName[state_y] : nil
        end
      end
    end

    # Convert a state symbol from a value as stored in the database.
    #
    # @param state [Integer] The value for the state as stored in the database.
    #
    # @return [Symbol,nil] Returns the symbolic value of the state, or `nil` if *value* is `nil`.
    #
    # @raise Throws an exception if *value* is not in the database table.
      
    def self.state_from_db(state)
      return nil if state.nil?

      load_list_item_state_values()
        
      case state
      when Numeric
        state_i = state.to_i
        raise "bad state value: #{state} (#{StateByValue})" unless StateByValue.has_key?(state_i)
        StateByValue[state_i]
      else
        state_s = state.to_s
        if state_s =~ /^(\+|\-)?[0-9]+$/
          state_i = state_s.to_i
          raise "bad state value: #{state}" unless StateByValue.has_key?(state_i)
          StateByValue[state_i]
        else
          state_y = state.to_sym
          raise "bad state value: #{state}" unless StateByName.has_key?(state_y)
          state_y
        end
      end
    end

    # Resolve a list item.
    # This method converts *o* to a {Fl::Framework::List::ListItem} if necessary.
    # The object to resolve, *o*, can be one of the following:
    #
    # 1. Instances of {Fl::Framework::List::ListItem], which are kept as-is.
    #    However, the method enforces that *o* is in list *list*.
    # 2. Subclasses of {ActiveRecord::Base} that respond to the `listable?` method and return `true`
    #    (and are, therefore, listable).
    #    If *owner* is `nil`, and the object responds to `owner`, and `owner` returns a non-nil value,
    #    use that value; otherwise, use `list.owner`.
    # 3. Strings containing an object fingerprint, which is used to find the object in storage.
    #    The resulting objects should be listable as described in the previous item.
    # 4. Hashes that contain attributes for the instance of {Fl::Framework::List::ListItem} to create.
    #    These hashes contain at least the **:listed_object** attribute.
    #    The value of **:list** is ignored: it is overridden by *list*.
    #    The value of **:listed_object** can be an ActiveRecord model instance or a string containing
    #    the object's fingerprint.
    #    If *owner* is `nil`, and the hash contains a non-nil **:owner**, use that value; otherwise,
    #    use `list.owner`.
    #    All other key/vaue pairs in the hash are passed down to the constructor: it is the caller's
    #    responsibility to ensure that the list item (sub)class supports them.
    #  
    # @param o The object to resolve. See above for details.
    # @param list [Fl::Framework::List::List] The list where the object should be placed.
    # @param owner The owner for the resolved object. See above for a discussion on how this value is used.
    #
    # @return [Fl::Framework::List::ListItem,String] Returns either an instance
    #  of {Fl::Framework::List::ListItem}, or a string containing an error message.

    def self.resolve_object(o, list, owner = nil)
      c_o = _convert_object(o)
      
      if c_o.is_a?(Fl::Framework::List::ListItem)
        if c_o.list.id != list.id
          resolved = I18n.tx('fl.framework.list_item.model.different_list', item: c_o.fingerprint,
                             item_list: c_o.list.fingerprint, list: list.fingerprint)
        else
          resolved = c_o
        end
      elsif c_o.is_a?(ActiveRecord::Base)
        c_owner = if owner
                    owner
                  elsif (c_o.respond_to?(:owner) && c_o.owner)
                    c_o.owner
                  else
                    list.owner
                  end
        resolved = self.new({
                              list: list,
                              listed_object: c_o,
                              owner: c_owner
                            })
      elsif c_o.is_a?(Hash)
        n_o = (c_o.has_key?(:listed_object)) ? _convert_object(c_o[:listed_object]) : nil
        if n_o.is_a?(String)
          resolved = n_o
        else
          c_owner = if owner
                      owner
                    elsif !c_o[:owner].nil?
                      c_o[:owner]
                    elsif (n_o.respond_to?(:owner) && n_o.owner)
                      n_o.owner
                    else
                      list.owner
                    end
          nh = c_o.reduce({
                            list: list,
                            listed_object: n_o,
                            owner: c_owner,
                            name: c_o[:name]
                          }) do |acc, kvp|
            hk, hv = kvp
            acc[hk] = hv unless acc.has_key?(hk)
            acc
          end

          resolved = self.new(nh)
        end
      else
        resolved = c_o
      end

      resolved
    end

    # Normalizes an array containing a list of objects in a list.
    # This method enumerates the contents of *objects*, calling {.resolve_object}
    # for each element and adding it to the normalized array.
    # Various types of elements are acceptable in *objects*, as described in the
    # documentation for {.resolve_object}.
    #
    # If an element is a string or hash and the object resolution triggers an error, the error string
    # is placed in the normalized array at that position. Additionally, if the resolved object is not
    # listable, an error string is also placed in the normalized array at that position.
    #
    # @param [Array] objects The input array (or a single object, which will be converted to an
    #  input array).
    # @param list [Fl::Framework::List::List] The list for which to perform the normalization; this value
    #  is passed to {.resolve_object}.
    # @param owner The owner for any newly created list objects; this value is passed to {.resolve_object}.
    #
    # @return Returns a two-element array:
    #  - The count of objects whose conversion failed; this is the count of elements in the normalized
    #    array that are strings.
    #  - An array containing the normalized, converted object, or error messages (as a String object).

    def self.normalize_objects(objects, list, owner = nil)
      return [0, []] unless objects

      objects = [ objects ] unless objects.is_a?(Array)
      errcount = 0
      converted = objects.map do |o|
        r = resolve_object(o, list, owner)
        errcount += 1 if r.is_a?(String)
        r
      end

      [ errcount, converted ]
    end

    protected

    # @!visibility private
    # Validation check: the listed object must be listable.

    def object_must_be_listable()
      o = self.listed_object
      if o && (!o.respond_to?(:listable?) || !o.listable?)
        errors.add(:listed_object, I18n.tx('fl.framework.list_item.model.not_listable', listed_object: o.to_s))
      end
    end

    # @!visibility private
    # validation check: the listed object must not already be in the list

    def check_duplicate_entries()
      if self.listed_object && self.list
        lo = Fl::Framework::List::ListItem.query_for_listable_in_list(self.listed_object, self.list).first
        if lo
          errors.add(:listed_object, I18n.tx('fl.framework.list_item.model.already_in_list',
                                             :listed_object => self.listed_object.to_s, :list => self.list))
        end
      end
    end

    # @!visibility private

    def validate_state()
      if Fl::Framework::List::ListItem.state_to_db(read_attribute(:state)).nil?
        self.errors[:state] << I18n.tx('fl.framework.list_list_item.model.validate.invalid_state',
                                       :value => read_attribute(:state))
      end
    end

    # @!visibility private
    INVALID_NAME_REGEXP = Regexp.new("[\/\\\\]")

    # @!visibility private

    def validate_name()
      unless self.name.blank?
        name = self.name
        
        if name =~ INVALID_NAME_REGEXP
          self.errors[:name] << I18n.tx('fl.framework.list_item.model.validate.invalid_name', :name => name)
        end

        q = Fl::Framework::List::ListItem.where('(name = :name)', name: name)
        q = q.where('(id != :lid)', lid: self.id) if self.persisted?
        qc = q.count
        if qc > 0
          self.errors[:name] << I18n.tx('fl.framework.list_item.model.validate.duplicate_name', :name => name)
        end
      end
    end
    
    # @!visibility private
    MINIMAL_HASH_KEYS = [ :owner, :list, :listed_object, :readonly_state, :state, :sort_order, :item_summary ]
    # @!visibility private
    STANDARD_HASH_KEYS = [ :state_updated_at, :state_updated_by, :state_note ]
    # @!visibility private
    VERBOSE_HASH_KEYS = [ ]
    # @!visibility private
    DEFAULT_LIST_OPTS = { :verbosity => :minimal }
    # @!visibility private
    DEFAULT_LISTED_OBJECT_OPTS = { :verbosity => :standard }
    # @!visibility private
    DEFAULT_OWNER_OPTS = { :verbosity => :minimal }
    # @!visibility private
    DEFAULT_STATE_UPDATED_BY_OPTS = { :verbosity => :minimal }

    # Given a verbosity level, return predefined hash options to use.
    #
    # @param actor [Object] The actor for which we are building the hash representation.
    # @param verbosity [Symbol] The verbosity level; see #to_hash.
    # @param opts [Hash] The options that were passed to #to_hash. No options are processed by this method.
    #
    # @return [Hash] Returns a hash containing default options for +verbosity+.

    def to_hash_options_for_verbosity(actor, verbosity, opts)
      if (verbosity != :id) && (verbosity != :ignore)
        if verbosity == :minimal
          {
            :include => MINIMAL_HASH_KEYS
          }
        elsif verbosity == :standard
          {
            :include => MINIMAL_HASH_KEYS | STANDARD_HASH_KEYS
          }
        elsif (verbosity == :verbose) || (verbosity == :complete)
          {
            :include => MINIMAL_HASH_KEYS | STANDARD_HASH_KEYS | VERBOSE_HASH_KEYS
          }
        else
          {}
        end
      else
        {}
      end
    end

    # Build a Hash representation of the session.
    # This method returns a Hash that contains key/value pairs that describe the session.
    #
    # @param actor [Object] The actor for which we are building the hash representation.
    #  See the documentation for {Fl::ModelHash::InstanceMethods#to_hash} and 
    #  {Fl::ModelHash::InstanceMethods#to_hash_local}.
    # @param keys [Array<Symbols>] The keys to return.
    # @param opts [Hash] Options for the method. In addition to the standard options:
    #
    #  - :to_hash[:list] A hash of options to pass to the list's `to_hash` method.
    #  - :to_hash[:listed_object] A hash of options to pass to the listed object's `to_hash` method.
    #  - :to_hash[:owner] A hash of options to pass to the owner's `to_hash` method.
    #  - :to_hash[:state_updated_by] A hash of options to pass to the `to_hash` method
    #    for **:state_updated_by**.
    #
    # @return [Hash] Returns a Hash containing the list item's representation.

    def to_hash_local(actor, keys, opts = {})
      to_hash_opts = opts[:to_hash] || {}

      rv = {
      }
      sp = nil
      keys.each do |k|
        case k.to_sym
        when :list
          list_opts = to_hash_opts_with_defaults(to_hash_opts[:list], DEFAULT_LIST_OPTS)
          rv[:list] = self.list.to_hash(actor, list_opts)
        when :listed_object
          lo_opts = to_hash_opts_with_defaults(to_hash_opts[:listed_object], DEFAULT_LISTED_OBJECT_OPTS)
          rv[:listed_object] = self.listed_object.to_hash(actor, lo_opts)
        when :owner
          if self.owner
            o_opts = to_hash_opts_with_defaults(to_hash_opts[:owner], DEFAULT_OWNER_OPTS)
            rv[:owner] = self.owner.to_hash(actor, o_opts)
          else
            rv[:owner] = nil
          end
        when :state_updated_by
          if self.state_updated_by
            u_opts = to_hash_opts_with_defaults(to_hash_opts[:state_updated_by], DEFAULT_STATE_UPDATED_BY_OPTS)
            rv[:state_updated_by] = self.state_updated_by.to_hash(actor, u_opts)
          else
            rv[:state_updated_by] = nil
          end
        else
          rv[k] = self.send(k) if self.respond_to?(k)
        end
      end

      rv
    end

    private

    def self._convert_object(o)
      case o
      when Fl::Framework::List::ListItem
        converted = o
      when ActiveRecord::Base
        if o.respond_to?(:listable?) && o.listable?
          converted = o
        else
          converted = I18n.tx('fl.framework.list_item.model.not_listable', :listed_object => o.fingerprint)
        end
      when String
        begin
          n_o = self.find_by_fingerprint(o)
          if n_o.respond_to?(:listable?) && n_o.listable?
            converted = n_o
          else
            converted = I18n.tx('fl.framework.list_item.model.not_listable', :listed_object => o)
          end
        rescue Exception => exc
          converted = exc.message
        end
      when Hash
        converted = o
      else
        converted = I18n.tx('fl.framework.list_item.model.bad_listed_object', :listed_object => o.to_s)
      end

      converted
    end

    def self.table_alias
      'lit'
    end

    def self.load_list_item_state_values()
      if StateByValue.count < 1
        self.connection.select_all('SELECT id, name, desc_backstop FROM fl_framework_list_item_state_t').each() do |r|
          id = r['id'].to_i
          sym = r['name'].to_sym
          StateByValue[id] = sym
          StateByName[sym] = id
        end
      end
    end

    def object_state_defaults_for_create()
      self.state_updated_by = self.owner unless self.state_updated_by
    end

    def set_class_name_field()
      self.listed_object_class_name = self.listed_object.class.name
    end

    def set_fingerprints()
      self.listed_object_fingerprint = self.listed_object.fingerprint
      self.owner_fingerprint = self.owner.fingerprint if self.owner
    end

    def check_list_item()
      # if the listed object maps to a list item, we need to check how many list objects are
      # associated with the list item. If no more, we need to delete the list item as well.
      # Note that there should be 0 if this was the last list object previous to the delete
      # (we are here after the delete, which has removed the listed object from the list item's
      # containers in the database)

#      if self.listed_object.is_a?(Fl::Framework::List::ListItem)
#        list_item = self.listed_object
#        list_item.destroy if list_item.containers.count == 0
#      end
    end

    def update_list_timestamps()
      self.list.updated_at = Time.new
      self.list.save
    end

    def object_state_defaults_for_save()
      state = read_attribute(:state)
      if state.nil?
        write_attribute(:state, Fl::Framework::List::ListItem.state_to_db(STATE_SELECTED))
        write_attribute(:state_updated_at, Time.new)
      else
        write_attribute(:state, Fl::Framework::List::ListItem.state_to_db(state))
      end
    end

    def refresh_item_summary()
      self.item_summary = self.listed_object.list_item_summary
    end

    def bump_list_timestamp()
      if @bump_list_update_time
        self.list.updated_at = Time.now
        self.list.save

        # after a save, we turn off the bump flag; this is done so that an object that is created
        # with new, and then saved to persist, is marked as "no bump" in case it is kept around by
        # the client and further modified.

        @bump_list_update_time = false
      end
    end

    private
  
    def self._convert_list_list(ul)
      ul.reduce([ ]) do |acc, u|
        case u
        when Integer
          acc << u
        when Fl::Framework::List::List
          acc << u.id
        when String
          c, id = ActiveRecord::Base.split_fingerprint(u, 'Fl::Framework::List::List')
          acc << id.to_i unless id.nil?
        end

        acc
      end
    end

    def self._partition_list_lists(opts)
      rv = { }

      if opts.has_key?(:only_lists)
        if opts[:only_lists].nil?
          rv[:only_lists] = nil
        else
          only_l = (opts[:only_lists].is_a?(Array)) ? opts[:only_lists] : [ opts[:only_lists] ]
          rv[:only_lists] = _convert_list_list(only_l)
        end
      end

      if opts.has_key?(:except_lists)
        if opts[:except_lists].nil?
          rv[:except_lists] = nil
        else
          x_l = (opts[:except_lists].is_a?(Array)) ? opts[:except_lists] : [ opts[:except_lists] ]
          except_lists = _convert_list_list(x_l)

          # if there is a :only_lists, then we need to remove the :except_lists members from it.
          # otherwise, we return :except_lists

          if rv[:only_lists].is_a?(Array)
            rv[:only_lists] = rv[:only_lists] - except_lists
          else
            rv[:except_lists] = except_lists
          end
        end
      end

      rv
    end

    def self._convert_owner_list(ul)
      ul.reduce([ ]) do |acc, u|
        case u
        when ActiveRecord::Base
          acc << "#{u.class.name}/#{u.id}"
        when String
          # Technically, we could get the class from the name, check that it exists and that it is
          # a subclass of ActiveRecord::Base, but for the time being we don't
          
          c, id = ActiveRecord::Base.split_fingerprint(u)
          acc << u unless c.nil? || id.nil?
        end

        acc
      end
    end
    
    def self._partition_owner_lists(opts)
      rv = { }

      if opts.has_key?(:only_owners)
        if opts[:only_owners].nil?
          rv[:only_owners] = nil
        else
          only_o = (opts[:only_owners].is_a?(Array)) ? opts[:only_owners] : [ opts[:only_owners] ]
          rv[:only_owners] = _convert_owner_list(only_o)
        end
      end

      if opts.has_key?(:except_owners)
        if opts[:except_owners].nil?
          rv[:except_owners] = nil
        else
          x_o = (opts[:except_owners].is_a?(Array)) ? opts[:except_owners] : [ opts[:except_owners] ]
          except_owners = _convert_owner_list(x_o)

          # if there is a :only_owners, then we need to remove the :except_owners members from it.
          # otherwise, we return :except_owners

          if rv[:only_owners].is_a?(Array)
            rv[:only_owners] = rv[:only_owners] - except_owners
          else
            rv[:except_owners] = except_owners
          end
        end
      end

      rv
    end

    def self._convert_listable_list(ul)
      ul.reduce([ ]) do |acc, u|
        case u
        when ActiveRecord::Base
          acc << "#{u.class.name}/#{u.id}"
        when String
          # Technically, we could get the class from the name, check that it exists and that it is
          # a subclass of ActiveRecord::Base, but for the time being we don't
          
          c, id = ActiveRecord::Base.split_fingerprint(u)
          acc << u unless c.nil? || id.nil?
        end

        acc
      end
    end
    
    def self._partition_listable_lists(opts)
      rv = { }

      if opts.has_key?(:only_listables)
        if opts[:only_listables].nil?
          rv[:only_listables] = nil
        else
          only_o = (opts[:only_listables].is_a?(Array)) ? opts[:only_listables] : [ opts[:only_listables] ]
          rv[:only_listables] = _convert_listable_list(only_o)
        end
      end

      if opts.has_key?(:except_listables)
        if opts[:except_listables].nil?
          rv[:except_listables] = nil
        else
          x_o = (opts[:except_listables].is_a?(Array)) ? opts[:except_listables] : [ opts[:except_listables] ]
          except_listables = _convert_listable_list(x_o)

          # if there is a :only_listables, then we need to remove the :except_listables members from it.
          # otherwise, we return :except_listables

          if rv[:only_listables].is_a?(Array)
            rv[:only_listables] = rv[:only_listables] - except_listables
          else
            rv[:except_listables] = except_listables
          end
        end
      end

      rv
    end
  end
end
