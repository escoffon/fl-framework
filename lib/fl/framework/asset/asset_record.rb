require 'fl/framework/application_record'

module Fl::Framework::Asset
  # Implementation of the asset record object for an ActiveRecord database.
  # Asset records list assets with the system.
  # It will need the migration `create_fl_framework_assets`.
  #
  # ## Attributes
  # This class defines the following attributes:
  #
  # - **created_at** is an Integer containing the UNIX creation time.
  # - **updated_at** is an Integer containing the UNIX modification time.
  #
  # === Associations
  # Fl::Framework::Asset::Asset defines a number of associations:
  # - {#owner} is the owner of the asset.
  # - {#asset} is the object that contains the asset data.

  class AssetRecord < Fl::Framework::ApplicationRecord
    include Fl::Framework::Core::ModelHash
    extend Fl::Framework::Query

    self.table_name = 'fl_framework_assets'

    before_create :set_fingerprints

    # @!attribute [rw] created_at
    # The time when the asset record was created.
    # @return [DateTime] Returns the creation time of the asset record.

    # @!attribute [rw] updated_at
    # The time when the asset record was updated.
    # @return [DateTime] Returns the modification time of the asset record.

    # @!attribute [r] owner
    # The owner of the asset.
    # @return [Object] Returns the object that "owns" the asset.

    belongs_to :owner, polymorphic: true

    # @!attribute [r] asset
    # The object that contains the asset data.
    # @return [Object] Returns the asset object.

    belongs_to :asset, polymorphic: true

    # Initializer.
    #
    # @param attrs [Hash] A hash of initialization parameters.
    # @option attrs [Object,String] :owner The asset owner. A string value is resolved using
    #  {ActiveRecord::Base.find_by_fingerprint}.
    # @option attrs [Object,String] :asset The asset object. A string value is resolved using
    #  {ActiveRecord::Base.find_by_fingerprint}.

    def initialize(attrs = nil)
      attrs = {} unless attrs.is_a?(Hash)
      
      if attrs.has_key?(:asset) && attrs[:asset].is_a?(String)
        attrs[:asset] = ActiveRecord::Base.find_by_fingerprint(attrs[:asset])
      end

      if attrs.has_key?(:owner) && attrs[:owner].is_a?(String)
        attrs[:owner] = ActiveRecord::Base.find_by_fingerprint(attrs[:owner])
      end

      if attrs[:owner].nil? && !attrs[:asset].nil? && attrs[:asset].respond_to?(:owner)
        attrs[:owner] = attrs[:asset].send(:owner)
      end
        
      super(attrs)
    end

    # Update attributes.
    # The method removes **:asset** and **:owner** from *attrs* before calling the
    # superclass implementation.
    #
    # @param attrs [Hash] The attributes.
    #
    # @return @returns the return value from the `super` call.

    def update_attributes(attrs)
      nattrs = attrs.reduce({}) do |acc, a|
        ak, av = a
        case ak
        when :asset, :owner
        else
          acc[ak] = av
        end

        acc
      end

      super(nattrs)
    end
  
    # Build a query to fetch asset records.
    #
    # Note that any WHERE clauses from *:updated_after*, *:created_after*, *:updated_before*,
    # and *:created_before* are concatenated using the AND operator. The values for these options are:
    # a UNIX timestamp; a Time object; a string containing a representation of the time (this string
    # is converted to a {Fl::Framework::Core::Icalendar::Datetime} internally).
    #
    # @param opts [Hash] A Hash containing configuration options for the query.
    # @option opts [Array<Object,String>, Object, String] :only_owners Limit the returned values to asset
    #  records whose `owner` attribute is in the option's value
    #  (technically, whose `owner_id` and `owner_type` attribute pairs are in the list derived from the
    #  option's value).
    #  The elements in an array value are object instances or object fingerprints; note that identifiers
    #  are not supported, because the `owner` association is polymorphic.
    #  If this option is not present, all asset records are selected.
    # @option opts [Array<Object,String>, Object, String] :except_owners Limit the returned values to asset
    #  records whose `owner` attribute is not in the option's value
    #  (technically, whose `owner_id` and `owner_type` attribute pairs are not in the list derived from the
    #  option's value).
    #  The elements in an array value are object instances or object fingerprints; note that identifiers
    #  are not supported, because the `owner` association is polymorphic.
    #  If this option is not present, all asset records are selected.
    # @option opts [Array<Class,String>, Class, String] :only_asset_types Limit the returned values to
    #  asset records whose type is in the option's value
    #  (technically, whose `asset_type` attribute is in the list derived from the option's value).
    #  The elements in an array value are class objects (which are converted to class names), or class names.
    #  If this option is not present, all asset records are selected.
    # @option opts [Array<Class,String>, Class, String] :except_asset_types Limit the returned values to
    #  asset records whose type is not in the option's value
    #  (technically, whose `asset_type` attribute is not in the list derived from the option's value).
    #  The elements in an array value are class objects (which are converted to class names), or class names.
    #  If this option is not present, all asset records are selected.
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
    #  Defaults to <tt>updated_at DESC</tt>, so that the records are ordered by modification time, 
    #  with the most recent one listed first.
    # @option opts [Symbol, Array<Symbol>, Hash] :includes An array of symbols (or a single symbol),
    #  or a hash, to pass to the `includes` method
    #  of the relation; see the guide on the ActiveRecord query interface about this method.
    #  Note that the default value for **:includes** is `[ :owner, :asset ]`.
    #
    # Note that *:limit*, *:offset*, and *:includes* are convenience options, since they can be
    # added later by making calls to `limit`, `offset`, and `includes` respectively, on the
    # return value. But there are situations where the return type is hidden inside an API wrapper, and
    # the only way to trigger these calls is through the configuration options.
    #
    # @return [ActiveRecord::Relation] If the query options are empty, the method returns `self`
    #  (and therefore the class object); if they are not empty, it returns an association relation.

    def self.build_query(opts = {})
      q = self

      i = if opts[:includes]
            if opts[:includes].is_a?(Array) || opts[:includes].is_a?(Hash)
              opts[:includes]
            else
              [ opts[:includes] ]
            end
          else
            [ :asset, :owner ]
          end
      q = q.includes(i)

      o_lists = _partition_owner_lists(opts)
      a_lists = _partition_asset_type_lists(opts)

      # if :only_owners is nil, and :except_owners is also nil, the two options will create an empty set,
      # so we can short circuit here.
      # and similarly for :only_asset_types and :except_asset_types

      o_nil_o = o_lists.has_key?(:only_owners) && o_lists[:only_owners].nil?
      o_nil_x = o_lists.has_key?(:except_owners) && o_lists[:except_owners].nil?
      a_nil_o = a_lists.has_key?(:only_asset_types) && a_lists[:only_asset_types].nil?
      a_nil_x = a_lists.has_key?(:except_asset_types) && a_lists[:except_asset_types].nil?

      if o_nil_o && o_nil_x && a_nil_o && a_nil_x
        return q.where('(1 = 0)')
      end
    
      if a_lists[:only_asset_types].is_a?(Array)
        # If we have :only_asset_types, the :except_asset_types have already been eliminated, so all we need
        # is the only_asset_types

        q = q.where('(asset_type IN (:ul))', { ul: a_lists[:only_asset_types] })
      elsif a_lists[:except_asset_types]
        # since only_asset_types is not present, we need to add the except_asset_types

        q = q.where('(asset_type NOT IN (:ul))', { ul: a_lists[:except_asset_types] })
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
  
    # Execute a query to fetch the number of asset records for a given set of query options.
    # The number returned is subject to the configuration options *opts*; for example,
    # if <tt>opts[:only_owners]</tt> is defined, the return value is the number of asset records whose
    # owners identifiers are in the option.
    #
    # @param opts [Hash] A Hash containing configuration options for the query.
    #  See the documentation for {.build_query}.
    #
    # @return [Integer] Returns the number of asset records that would be returned by the query.

    def self.count_asset_records(opts = {})
      q = build_query(opts)
      (q.nil?) ? 0 : q.count
    end

    protected

    # @!visibility private
    MINIMAL_HASH_KEYS = [ :owner, :asset ]
    # @!visibility private
    STANDARD_HASH_KEYS = [ ]
    # @!visibility private
    VERBOSE_HASH_KEYS = [ ]
    # @!visibility private
    DEFAULT_OWNER_OPTS = { :verbosity => :minimal }
    # @!visibility private
    DEFAULT_ASSET_OPTS = { :verbosity => :standard }

    # Given a verbosity level, return predefined hash options to use.
    #
    # @param actor [Object] The actor for which we are building the hash representation.
    # @param verbosity [Symbol] The verbosity level; see #to_hash.
    # @param opts [Hash] The options that were passed to #to_hash. No options are processed by this method.
    #
    # @return [Hash] Returns a hash containing default options for `verbosity`.

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

    # Build a Hash representation of the asset record.
    # This method returns a Hash that contains key/value pairs that describe the asset record.
    #
    # @param actor [Object] The actor for which we are building the hash representation.
    #  See the documentation for {Fl::ModelHash::InstanceMethods#to_hash} and 
    #  {Fl::ModelHash::InstanceMethods#to_hash_local}.
    # @param keys [Array<Symbols>] The keys to return.
    # @param opts [Hash] Options for the method. In addition to the standard options:
    #
    #  - :to_hash[:owner] A hash of options to pass to the owner's `to_hash` method.
    #  - :to_hash[:asset] A hash of options to pass to the asset's `to_hash` method.
    #
    # @return [Hash] Returns a Hash containing the asset record's representation.

    def to_hash_local(actor, keys, opts = {})
      to_hash_opts = opts[:to_hash] || {}

      rv = {
      }
      sp = nil
      keys.each do |k|
        case k.to_sym
        when :asset
          asset_opts = to_hash_opts_with_defaults(to_hash_opts[:asset], DEFAULT_ASSET_OPTS)
          rv[:asset] = self.asset.to_hash(actor, asset_opts)
        when :owner
          if self.owner
            o_opts = to_hash_opts_with_defaults(to_hash_opts[:owner], DEFAULT_OWNER_OPTS)
            rv[:owner] = self.owner.to_hash(actor, o_opts)
          else
            rv[:owner] = nil
          end
        else
          rv[k] = self.send(k) if self.respond_to?(k)
        end
      end

      rv
    end

    private

    def set_fingerprints()
      self.owner_fingerprint = self.owner.fingerprint if self.owner
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

    def self._convert_asset_type_list(ul)
      ul.reduce([ ]) do |acc, u|
        case u
        when Class
          acc << u.name unless acc.include?(u.name)
        when String
          acc << u unless acc.include?(u)
        end

        acc
      end
    end
    
    def self._partition_asset_type_lists(opts)
      rv = { }

      if opts.has_key?(:only_asset_types)
        if opts[:only_asset_types].nil?
          rv[:only_asset_types] = nil
        else
          only_o = (opts[:only_asset_types].is_a?(Array)) ? opts[:only_asset_types] : [ opts[:only_asset_types] ]
          rv[:only_asset_types] = _convert_asset_type_list(only_o)
        end
      end

      if opts.has_key?(:except_asset_types)
        if opts[:except_asset_types].nil?
          rv[:except_asset_types] = nil
        else
          x_o = (opts[:except_asset_types].is_a?(Array)) ? opts[:except_asset_types] : [ opts[:except_asset_types] ]
          except_asset_types = _convert_asset_type_list(x_o)

          # if there is a :only_asset_types, then we need to remove the :except_asset_types members from it.
          # otherwise, we return :except_asset_types

          if rv[:only_asset_types].is_a?(Array)
            rv[:only_asset_types] = rv[:only_asset_types] - except_asset_types
          else
            rv[:except_asset_types] = except_asset_types
          end
        end
      end

      rv
    end
  end
end
