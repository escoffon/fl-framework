module Fl::Framework::List
  # Model class for lists.
  # A list manages a collection of listable objects by managing a collection of list item objects.
  # Any subclass of {ActiveRecord::Base} that wants to be placed in lists must call the
  # {Fl::Framework::List::Listable::ClassMethods#is_listable} macro:
  #
  # ```
  # class MyModel < ActiveRecord::Base
  #  is_listable
  # end
  # ```
  # (Note that only subclasses of {ActiveRecord::Base} can be listable.)
  #
  # Instances of {List} manage collections of {Fl::Framework::List::ListItem} objects, which adds
  # a few properties to the relationship, as described in the documentation for
  # {Fl::Framework::List::ListItem}. This is essentially a `has_many_through` association, where the
  # "through" class contains additional information for the relationship.
  #
  # #### List item factories
  #
  # There are circumstances where it is necessary to add behavior to the relationship: for example,
  # adding access control checks to the list item objects to prevent unauthorized access.
  # Since this is done by subclassing {Fl::Framework::List::ListItem}, {List} defines a
  # class API to override the class of its list items. This is done on a class basis, so that one has
  # the option of overriding the list item class for all {List} instances, or for selected subclasses.
  # For example, to override the list item class globally:
  #
  #
  # #### Associations
  #
  # The class defines the following associations:
  #
  # - {#owner} is a `belongs_to` association to the entity that "owns" the list.
  # - {#list_items} is a `has_many` association that lists all the items in the list.
  # - {#containers} is a `has_many` association that lists all the containers (lists) to which the
  #   list belongs.

  class List < Fl::Framework::ApplicationRecord
    # Exception raised by lists when listed object normalization fails.
    
    class NormalizationError < RuntimeError
      # Initializer.
      #
      # @param msg [String] An error message.
      # @param olist [Array] An arry that contains the list of objects that triggered the error.
      #  Any sring elements are added to the error list.
      
      def initialize(msg = '', olist = [])
        super(msg)

        @errs = if olist
                  olist.reduce([]) do |acc, o|
                    acc << o if o.is_a?(String)
                    acc
                  end
                else
                  [ ]
                end
      end

      # The error list.
      #
      # @return [Array<String>] Returns an array containing the error messages from the normalization.
      
      def errors
        @errs
      end
    end

    include Fl::Framework::Core::ModelHash
    include Fl::Framework::Core::AttributeFilters
    include Fl::Framework::Core::TitleManagement
    extend Fl::Framework::Query
    include Fl::Framework::List::Listable
    include Fl::Framework::List::Helper
    
    self.table_name = 'fl_framework_lists'
    
    # @!attribute [r] containers
    # Since a list can be placed in other lists, it automatically creates an association named `containers`
    # that lists all the lists to which it belongs.
    # @return [Association] a `has_many` associations to the list items where `self` is the
    #  listed object.
    #  Note that this associaition returns {Fl::Framework::List::ListItem} instances; to get the
    #  list objects, access their **:list** attribute. For example:
    #
    #  ```
    #    list = get_the_list()
    #    list_containers = list.containers.map { |li| li.list }
    #  ```
    
    is_listable

    # @!attribute [rw] owner
    # A `belongs_to` association that describes the entity that "owns" the list; this is typically
    # the creator. This association is polymorphic and it is optional (*i.e.* the owner can be `nil`).
    # @return [Association] the list owner.

    belongs_to :owner, polymorphic: true, optional: true
    
    # @!attribute [rw] list_items
    # A `has_many` association containing the list items; this association is a collection of
    # {Fl::Framework::List::ListItem} instances.
    # @return [Association] the list items.

    has_many :list_items, -> { order("sort_order ASC") }, autosave: true,
             class_name: 'Fl::Framework::List::ListItem', dependent: :destroy

    # @!attribute [rw] list_display_preferences
    # The display preferences for the list. This is a hash of options for use by presentations
    # to determine how the list should be displayed.
    # The contents of this hash are somewhat client-dependent, but some "standard" properties are:
    #
    # - **limit** An integer containing the number of items to display; the value -1 indicates all.
    # - **only_types** An array of class names listing the types of objects to display.
    # - **order** The sort order for the list.
    # - **only_states** An array containing the list of states to select.
    #
    # @return [Hash] The list display preferences; since this attribute is stored as JSON, the
    #  keys are strings and not symbols.

    serialize :list_display_preferences, JSON

    # The cutoff value for the title length when extracted from the caption.
    TITLE_LENGTH = 60

    validates :title, :length => { :minimum => 1, :maximum => 200 }
    # validates :list_access_level, :presence => true
    validates :default_readonly_state, :presence => true
    validate :check_list_items

    before_create :set_fingerprints
    before_validation :before_validation_checks
    before_save :before_save_checks

    filtered_attribute :title, [ FILTER_HTML_TEXT_ONLY ]
    filtered_attribute :caption, [ FILTER_HTML_STRIP_DANGEROUS_ELEMENTS ]

    # @!attribute [rw] title
    # The list title.
    # @return [String] the list title.

    # @!attribute [rw] caption
    # The list caption.
    # @return [String] the list caption.

    @@_list_item_class = { }
    
    # Gets the class used to store list items.
    #
    # @return [Class] Returns the class that was registered for this list class.
    #  Note that the registered class is a subclass of {Fl::Framework::List::ListItem}.

    def self.list_item_class()
      (@@_list_item_class.has_key?(self.name)) ? @@_list_item_class[self.name] : Fl::Framework::List::ListItem
    end

    # Sets the class used to store list items.
    #
    # @param liclass [Class,String] The subclass of {Fl::Framework::List::ListItem} to use, or
    #  the name of the subclass.
    #
    # @raise [RuntimeError] Raises an exception if *liclass* resolves to a class that does not
    #  derive from {Fl::Framework::List::ListItem}.

    def self.list_item_class=(liclass)
      k = if liclass.is_a?(Class)
            liclass
          elsif liclass.is_a?(String)
            liclass.constantize
          else
            raise I18n.tx('fl.framework.list.model.bad_list_item_class')
          end

      if !k.ancestors.include?(Fl::Framework::List::ListItem)
        raise I18n.tx('fl.framework.list.model.invalid_list_item_class')
      end
      
      @@_list_item_class[self.name] = k
    end
    
    # Gets the class used to store list items.
    # This is a wrapper around {.list_item_class}.
    #
    # @return [Class] Returns the class that was registered for this list class.
    #  Note that the registered class is a subclass of {Fl::Framework::List::ListItem}.

    def list_item_class()
      self.class.list_item_class()
    end
    
    # Constructor.
    #
    # @param attrs [Hash] A hash of initialization parameters.
    #  The :objects pseudoattribute contains a list of objects to place in the list (by wrapping them
    #  in a Fl::Framework::List::ListItem); these instances of Fl::Framework::List::ListItem use the
    #  list's owner as their owner.

    def initialize(attrs = {})
      attrs = attrs || {}
      objs = attrs.delete(:objects)

      attrs[:owner] = actor_from_parameter(attrs[:owner]) if attrs.has_key?(:owner)
      
      unless attrs.has_key?(:caption)
        attrs[:caption] = I18n.localize_x(Time.now.to_date, :format => :list_title)
      end

      attrs[:default_readonly_state] = true unless attrs.has_key?(:default_readonly_state)
      
      rv = super(attrs)

      if objs
        set_objects(objs, self.owner)
      end

      rv
    end

    # Bulk update.
    #
    # @param attrs [Hash] The attributes, including the **:objects** pseudo-attribute.

    def update_attributes(attrs)
      objs = attrs.delete(:objects)

      rv = super(attrs)

      if objs
        set_objects(objs, self.owner)
        rv = self.save()
      end

      rv
    end

    # Set the list permission.
    # This attribute controls who will be able to make changes to the list of listed objects.
    # Its value is one of the known visibilities :private, :group, :friends, and :public.
    # If :private, only the list's owner can add or remove items.
    # If :group, the list's owner or users who have :group visibility can add or remove items.
    # If :friends, the list's owner or users who have :friends visibility can add or remove items.
    # If :public, anyone can add or remove items.
    #
    # @param visibility The visibility level to use for checking list permissions; this is one of the
    #  known symbolic names :private, :group, :friends, and :public.

    #def list_access_level=(visibility)
    #  write_attribute(:list_access_level, Fl::Db::Assets::Resource.visibility_to_db(visibility))
    #end

    # Get the list permission.
    #
    # @return Returns the visibility level to use for checking list permissions; this is one of the
    #  known symbolic names :private, :group, :friends, and :public.

    #def list_access_level()
    #  Fl::Db::Assets::Resource.visibility_from_db(read_attribute(:list_access_level))
    #end

    # Look up an object relationship in this list.
    # This method runs a query that searches for a relationship to *obj* in the list.
    # If no relationship is found, `nil` is returned.
    #
    # @param obj [Object, String] The object to look up; a string value is assumed to be a fingerprint.
    #
    # @return [Fl::Framework::List::ListItem,nil] If *obj* is found in in one of `self`'s list items,
    #  that list item is returned. Otherwise, `nil` is returned.

    def find_list_item(obj)
      if obj.is_a?(String)
        cname, oid = self.class.split_fingerprint(obj)
      else
        cname = obj.class.name
        oid = obj.id
      end

      self.list_items.where('(listed_object_type = :cname) AND (listed_object_id = :oid)', {
                              cname: cname,
                              oid: oid
                            }).first
    end

    # Get the list of objects in the list.
    # This method wraps around the {#list_items} association and returns the listed objects, rather
    # than the relationship objects.
    #
    # @param reload [Boolean] Set to `true` to reload the {#list_items} association.
    #
    # @return [Array<Fl::Framework::List::ListItem>] Returns an array containing the objects in the list;
    #  maps over the array returned
    #  by the {#list_items} association, extracting their **list_object** attribute.

    def objects(reload = false)
      self.list_items.reload if reload
      self.list_items.map { |li| li.listed_object }
    end

    # Add an object to the list.
    #
    # @param obj [ActiveRecord::Base] The object to add; if already in the list, the request is ignored.
    # @param owner The owner for the list object that stores the association between `self` and *obj*.
    #  If `nil`, the list's owner is used.
    # @param name [String] The name to give to the list item; this is used by {#resolve_path} to find
    #  list items in a hierarchy.
    #
    # @return Returns the instance of {Fl::Framework::List::ListItem} that stores the association between
    #  `self` and *obj*. If *obj* is already in the list, the existing list item is returned.

    def add_object(obj, owner = nil, name = nil)
      li = find_list_item(obj)
      unless li
        li = self.list_item_class.new({
                                        list: self,
                                        listed_object: obj,
                                        owner: (owner) ? owner : self.owner,
                                        name: (name.is_a?(String)) ? name : nil
                                      })
        self.list_items << li
      end

      li
    end

    # Remove an object from the list.
    #
    # @param obj [ActiveRecord::Base, String] The object to remove; if not in the list, the request
    #  is ignored. A string value is assumed to be a fingerprint.

    def remove_object(obj)
      li = find_list_item(obj)
      self.list_items.delete(li) if li
    end

    # Get the value of the next sort order in the sequence.
    # This method runs a query to fetch the highest value of the **sort_order** column in the
    # list items table (for this list), and returns that value plus 1.
    #
    # @return Returns the next value to use in **sort_order**.

    def next_sort_order()
      sql = "SELECT MAX(sort_order) as max_sort_order FROM #{Fl::Framework::List::ListItem.table_name} WHERE (list_id = #{self.id})"
      rec = self.class.connection.select_all(sql).first
      if rec['max_sort_order'].nil?
        1
      else
        rec['max_sort_order'].to_i + 1
      end
    end
  
    # Build a query to fetch lists.
    #
    # Note that any WHERE clauses from *:updated_after*, *:created_after*, *:updated_before*,
    # and *:created_before* are concatenated using the AND operator. The values for these options are:
    # a UNIX timestamp; a Time object; a string containing a representation of the time (this string
    # is converted to a {Fl::Framework::Core::Icalendar::Datetime} internally).
    #
    # @param opts [Hash] A Hash containing configuration options for the query.
    # @option opts [Array<Object,String>, Object, String] :only_owners Limit the returned values to lists
    #  whose `owner` attribute is in the option's value
    #  (technically, whose `owner_id` and `owner_type` attribute pairs are in the list derived from the
    #  option's value).
    #  The elements in an array value are object instances or object fingerprints; note that identifiers
    #  are not supported, because the `owner` association is polymorphic.
    #  If this option is not present, all list items are selected.
    # @option opts [Array<Object,String>, Object, String] :except_owners Limit the returned values to lists
    #  whose `owner` attribute is not in the option's value
    #  (technically, whose `owner_id` and `owner_type` attribute pairs are not in the list derived from the
    #  option's value).
    #  The elements in an array value are object instances or object fingerprints; note that identifiers
    #  are not supported, because the `owner` association is polymorphic.
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

      o_lists = _partition_owner_lists(opts)

      # if :only_owners is nil, and :except_owners is also nil, the two options will create an empty set,
      # so we can short circuit here.

      o_nil_o = o_lists.has_key?(:only_owners) && o_lists[:only_owners].nil?
      o_nil_x = o_lists.has_key?(:except_owners) && o_lists[:except_owners].nil?

      if o_nil_o && o_nil_x
        return q.where('(1 = 0)')
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

      order_clauses = _parse_order_option(opts)
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

    # Build a query to find list items in this list.
    # This is a convenience method that returns an `ActiveRecord::Relation` on {ListItem} with a
    # where clause that selects items belonging to `self`.
    #
    # @param opts [Hash] Additional options to pass to {ListItem.build_query}; note that
    #  **:only_lists** and **:except_lists** are ignored if present, since the method adds its own
    #  values for them.
    #
    # @return [ActiveRecord::Relation] Returns a relation that can be used to fetch the list items.

    def query_list_items(opts = {})
      Fl::Framework::List::ListItem.build_query(opts.merge({ only_lists: [ self ], except_lists: nil}))
    end

    # Resolve a path to a list item.
    # This method splits the components of *path* and looks up the first one in the list; if it finds
    # a list item, and the item is a list, it calls itself recursively to resolve the rest of the path.
    # (Actually the algorithm is not recursive, but the end effect is the same.)
    #
    # Note tat the method executes a query for each component in the path, and therefore it does not have
    # the best performance.
    #
    # @param path [String] A path to the list item to look up; path components are separated by `/`
    #  (forward slash) characters.
    #
    # @return [Fl::Framework::List::LIstItem,nil] Returns a list item if one is found; otherwise, it
    #  returns `nil`.

    def resolve_path(path)
      pl = path.split(Regexp.new("[\/\\\\]+"))
      pl.shift if pl[0].length < 1
      return nil if pl.count < 1
      
      list = self
      last = pl.pop
      pl.each do |pc|
        li = Fl::Framework::List::ListItem.where('(list_id = :lid) AND (name = :n)',
                                                 lid: list.id, n: pc).first
        return nil if li.nil? || !li.listed_object.is_a?(Fl::Framework::List::List)
        list = li.listed_object
      end

      Fl::Framework::List::ListItem.where('(list_id = :lid) AND (name = :n)', lid: list.id, n: last).first
    end
    
    protected

    # The default properties to return from `to_hash`.
    DEFAULT_HASH_KEYS = [ :caption, :title, :owner, :default_readonly_state, # :list_access_level
                          :list_display_preferences ]
    # The additional verbose properties to return from `to_hash`.
    VERBOSE_HASH_KEYS = [ :lists, :objects ]

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
        when :lists
          l_opts = to_hash_opts_with_defaults(to_hash_opts[:lists], { verbosity: :id })
          rv[k] = self.lists.map do |l|
            l.to_hash(actor, l_opts)
          end
        when :objects
          o_opts = to_hash_opts_with_defaults(to_hash_opts[:objects], { verbosity: :id })
          rv[k] = self.objects.map do |obj|
            obj.to_hash(actor, o_opts)
          end
        when :owner
          o_opts = to_hash_opts_with_defaults(to_hash_opts[:owner], { verbosity: :minimal })
          rv[k] = self.owner.to_hash(actor, o_opts)
        when :list_items
          li_opts = to_hash_opts_with_defaults(to_hash_opts[:list_items], { verbosity: :minimal })
          rv[k] = self.list_items.map do |obj|
            obj.to_hash(actor, li_opts)
          end
        else
          rv[k] = self.send(k) if self.respond_to?(k)
        end
      end

      rv
    end

    private
        
    def set_objects(objs, owner)
      errs, conv = self.list_item_class.normalize_objects(objs, self, owner)
      if errs > 0
        exc = NormalizationError.new(I18n.tx('fl.framework.list.model.normalization_failure'), conv)
        raise exc
      else
        self.list_items = conv
      end
    end

    def set_fingerprints()
      self.owner_fingerprint = self.owner.fingerprint if self.owner
    end

    def check_list_items
      self.list_items.each_with_index do |li, idx|
        if !li.listed_object.respond_to?(:listable?) || !li.listed_object.listable?
          errors.add(:objects, I18n.tx('fl.framework.list_item.model.not_listable',
                                       listed_object: li.listed_object.to_s))
        elsif self.persisted? && !li.list.id.nil? && (li.list.id != self.id)
          errors.add(:objects, I18n.tx('fl.framework.list.model.validate.inconsistent_list',
                                       list_item: li.to_s, list: self.to_s))
        end

        li.sort_order = idx
      end
    end

    def before_validation_checks
      populate_title_if_needed(:caption, TITLE_LENGTH)
#      self.list_access_level = self.visibility if self.list_access_level.nil?
    end

    def before_save_checks
      populate_title_if_needed(:caption, TITLE_LENGTH)
 #     self.list_access_level = self.visibility if self.list_access_level.nil?
    end
  end
end
