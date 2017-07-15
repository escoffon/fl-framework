require 'fl/framework/attachment/query'

module Fl::Framework::Attachment::ActiveRecord
  # ActiveRecord-specific functionality for the attachment management extension module.

  module Attachable
    # The methods in this module will be installed as class methods of the including class.

    module ClassMethods
    end

    # The methods in this module are installed as instance method of the including class.

    module InstanceMethods
      # Build a query to fetch an object's attachments.
      #
      # Note that any WHERE clauses from *:updated_after*, *:created_after*, *:updated_before*,
      # and *:created_before* are concatenated using the AND operator. The values for these options are:
      # a UNIX timestamp; a Time object; a string containing a representation of the time (this string
      # is converted to a {Fl::Framework::Core::Icalendar::Datetime} internally).
      #
      # @param opts [Hash] A Hash containing configuration options for the query.
      # @option opts [String, Symbol] :name The name of the association for which we are building the query;
      #  the default value is +:attachments+. If you call
      #  {Fl::Framework::Attachment::Attachable::ClassMethods#has_attchments} with a nonstandard association
      #  name, you will have to provide this option.
      # @option opts [Array<String>, String] :only_types A list of MIME types for attachments that should be
      #  returned by the query. This list can include "globbed" MIME types like +image/*+ to cover classes
      #  of content types. The globbed type +*/*+ is equivalent to "all types", and its presence is equivalent
      #  to not providing this option (all types are allowed).
      # @option opts [Array<String>, String] :except_types A list of MIME types for attachments that should
      #  *not* be returned by the query. This list can include "globbed" MIME types like +image/*+ to cover
      #  classes of content types. The globbed type +*/*+ is equivalent to "no types", and its presence will
      #  cause the query to return no results (no types are allowed).
      #  If a type is present in both *:only_types* and *:except_types*, it is not returned: *:except_types*
      #  has priority over *:only_types*.
      # @option opts [Array<Object, String>, Object, String] :only_authors See the discussion of this
      #  option in {Fl::Framework::Query#_expand_author_list}.
      # @option opts [Array<Object>, Object] :except_authors See the discussion of this
      #  option in {Fl::Framework::Query#_expand_author_list}.
      # @option opts [Array<Object>, Object] :only_groups See the discussion of this
      #  option in {Fl::Framework::Query#_expand_author_list}.
      # @option opts [Array<Object>, Object] :except_groups See the discussion of this
      #  option in {Fl::Framework::Query#_expand_author_list}.
      # @option opts [Integer, Time, String] :updated_after selects attachments updated after a given time.
      # @option opts [Integer, Time, String] :created_after selects attachments created after a given time.
      # @option opts [Integer, Time, String] :updated_before selects attachments updated before a given time.
      # @option opts [Integer, Time, String] :created_before selects attachments created before a given time.
      # @option opts [Integer] :offset Sets the number of records to skip before returning;
      #  a +nil+ value causes the option to be ignored.
      #  Defaults to 0 (start at the beginning).
      # @option opts [Integer] :limit The maximum number of attachments to return;
      #  a +nil+ value causes the option to be ignored.
      #  Defaults to all attachments.
      # @option opts [String] :order A string containing the <tt>ORDER BY</tt> clause for the attachments;
      #  a +nil+ value causes the option to be ignored.
      #  Defaults to <tt>updated_at DESC</tt>, so that the attachments are ordered by modification time, 
      #  with the most recent one listed first.
      # @option opts [Symbol, Array<Symbol>, Hash] includes An array of symbols (or a single symbol),
      #  or a hash, to pass to the +includes+ method
      #  of the relation; see the guide on the ActiveRecord query interface about this method.
      #
      # Note that *:limit*, *:offset*, *:order*, and *:includes* are convenience options, since they can be
      # added later by making calls to +limit+, +offset+, +order+, and +includes+ respectively, on the
      # return value. But there situations where the return type is hidden inside an API wrapper, and
      # the only way to trigger these calls is through the configuration options.
      #
      # @return If the query options are empty, the method returns the +attachments+ association; if they are
      #  not empty, it returns an association relation.
      #  If +self+ does not seem to have an +attachments+ association, it returns +nil+.
      #
      # @example Get the last 10 attachments from all users (showing equivalent calls)
      #  c = get_attachable_object()
      #  q = c.attachments_query(limit: 10)
      #  q = c.attachments_query().limit(10)
      #  q = c.attachments_query(order: nil).order('updated_at DESC').limit(10)
      #
      # @example Get the first 10 attachments from a given user (showing equivalent calls)
      #  c = get_attachable_object()
      #  u = get_user()
      #  q = c.attachments_query(only_authors: u, order: 'created_at ASC, limit: 10)
      #  q = c.attachments_query(only_authors: u, order: nil).order('created_at ASC').limit(10)
      #
      # @example Get all attachments not from a given user
      #  c = get_attachable_object()
      #  u = get_user()
      #  q = c.attachments_query(except_authors: u)
      #
      # @example Get all attachments from a given user that were created less than ten days ago
      #  c = get_attachable_object()
      #  u = get_user()
      #  t = Time.new
      #  t -= 10.days
      #  q = c.attachments_query(only_authors: u, created_since: t)

      def attachments_query(opts = {})
        name = opts.has_key?(:name) ? opts[:name].to_sym : :attachments

        return nil unless self.respond_to?(name)

        q = self.send(name)

        if opts[:includes]
          i = (opts[:includes].is_a?(Array) || opts[:includes].is_a?(Hash)) ? opts[:includes] : [ opts[:includes] ]
          q = q.includes(i)
        end

        t_lists = _normalize_attachment_type_lists(opts)
        u_lists = _partition_author_lists(_expand_author_lists(opts))

        if t_lists[:only]
          # If we have :only, then :except has already been eliminated, so all we need is :only,
          # but there are a few special situations.

          # First of all, :only could be empty; this can happen, for example, if :except contains */*.
          # In this case, theoretically we could just plop a WHERE (1 = 0) shere clause, since we know
          # that no records should be returned, but we let it through and use the regular array clause.
          # All the empty :only conditions are caused by poor choices of :only_types and :except_types.

          # :only contains */*: all types are allowed, so we don't need a WHERE clause. Note that we
          # can ignore :except, since _normalize_attachment_type_list has eliminated those types from
          # :only

          unless t_lists[:only].include?('*/*')
            # If :only contains globbed MIME types, we need to use a different WHERE clause

            globbed = t_lists[:only].find { |t| t.index('*') }
            if globbed
              wc = []
              a = { }
              t_lists[:only].each_with_index do |t, idx|
                p = "p#{idx}"
                if t.index('*')
                  wc << "(attachment_content_type LIKE :#{p})"
                  a[p.to_sym] = t.gsub('*', '%')
                else
                  wc << "(attachment_content_type = :#{p})"
                  a[p.to_sym] = t
                end
              end

              q = q.where(wc.join(' OR '), a)
            else
              # OK, nothing globbed, so this is easy

              q = q.where('(attachment_content_type IN (:p1))', p1: t_lists[:only])
            end
          end
        elsif t_lists[:except]
          # since :only is nil, we need to add :except
          # There are similar special cases to :only

          # If :except contains '*/*', then all types are forbidden, and we need to place a WHERE clause
          # that eliminates everything. This is an extreme edge condition

          if t_lists[:except].include?('*/*')
            q = q.where('(1 = 0)')
          else
            # If :except contains globbed MIME types, we need to use a different WHERE clause

            globbed = t_lists[:except].find { |t| t.index('*') }
            if globbed
              wc = []
              a = { }
              t_lists[:except].each_with_index do |t, idx|
                p = "p#{idx}"
                if t.index('*')
                  wc << "(attachment_content_type NOT LIKE :#{p})"
                  a[p.to_sym] = t.gsub('*', '%')
                else
                  wc << "(attachment_content_type != :#{p})"
                  a[p.to_sym] = t
                end
              end

              q = q.where(wc.join(' AND '), a)
            else
              # OK, nothing globbed, so this is easy

              q = q.where('(attachment_content_type NOT IN (:p1))', p1: t_lists[:except])
            end
          end
        end

        if u_lists[:only_ids]
          # If we have :only_ids, the :except_ids have already been eliminated, so all we need is the only_ids
          # There is a similar argument with an empty only_ids to only_types, above.

          iarg = 1
          wc = []
          a = { }
          u_lists[:only_ids].each do |cn, ids|
            p = "p#{iarg}"
            wc << "((author_type = '#{cn}') AND (author_id IN (:#{p})))"
            a[p.to_sym] = ids.map { |i| i.to_i }
            iarg += 1
          end

          q = q.where(wc.join(' OR '), a)
        elsif u_lists[:except_ids]
          # since only_ids is nil, we need to add the except_ids

          iarg = 1
          wc = []
          a = { }
          u_lists[:except_ids].each do |cn, ids|
            p = "p#{iarg}"
            wc << "((author_type = '#{cn}') AND (author_id NOT IN (:#{p})))"
            a[p.to_sym] = ids.map { |i| i.to_i }
            iarg += 1
          end

          q = q.where(wc.join(' AND '), a)
        end

        ts = _date_filter_timestamps(opts)
        wt = []
        wta = {}
        if ts[:c_after_ts]
          wt << '(created_at > :c_after_ts)'
          wta[:c_after_ts] = ts[:c_after_ts].to_time
        end
        if ts[:u_after_ts]
          wt << '(updated_at > :c_after_ts)'
          wta[:u_after_ts] = ts[:u_after_ts].to_time
        end
        if ts[:c_before_ts]
          wt << '(created_at < :c_before_ts)'
          wta[:c_before_ts] = ts[:c_before_ts].to_time
        end
        if ts[:u_before_ts]
          wt << '(updated_at < :c_before_ts)'
          wta[:u_before_ts] = ts[:u_before_ts].to_time
        end
        if wt.count > 0
          q = q.where(wt.join(' AND '), wta)
        end

        order = (opts.has_key?(:order)) ? opts[:order] : 'created_at DESC'
        q = q.order(order) if order

        offset = (opts.has_key?(:offset)) ? opts[:offset] : nil
        q = q.offset(offset) if offset.is_a?(Integer) && (offset > 0)

        limit = (opts.has_key?(:limit)) ? opts[:limit] : nil
        q = q.limit(limit) if limit.is_a?(Integer) && (limit > 0)

        q
      end

      # Execute a query to fetch the number of attachments associated with an object.
      # The number returned is subject to the configuration options +opts+; for example,
      # if <tt>opts[:only_authors]</tt> is defined, the return value is the number of attachments for +self+
      # and created by the given authors.
      #
      # @param opts [Hash] A Hash containing configuration options for the query.
      # @option opts [String, Symbol] :name The name of the association for which we are building the query.
      #  See {#attachments_query}.
      # @option opts [Array<String>, String] :only_types Return only attachments of the specified type.
      #  See {#attachments_query}.
      # @option opts [Array<String>, String] :except_types Return only attachments whose types
      #  are *not* in this list. See {#attachments_query}.
      # @option opts [Array<Object, String>, Object, String] :only_authors See the discussion of this
      #  option in {Fl::Framework::Query#_expand_author_list}.
      # @option opts [Array<Object>, Object] :except_authors See the discussion of this
      #  option in {Fl::Framework::Query#_expand_author_list}.
      # @option opts [Array<Object>, Object] :only_groups See the discussion of this
      #  option in {Fl::Framework::Query#_expand_author_list}.
      # @option opts [Array<Object>, Object] :except_groups See the discussion of this
      #  option in {Fl::Framework::Query#_expand_author_list}.
      # @option opts [Integer, Time, String] :updated_after selects attachments updated after a given time.
      # @option opts [Integer, Time, String] :created_after selects attachments created after a given time.
      # @option opts [Integer, Time, String] :updated_before selects attachments updated before a given time.
      # @option opts [Integer, Time, String] :created_before selects attachments created before a given time.
      # @option opts [Integer] :offset Sets the number of records to skip before returning.
      #  See {#attachments_query}.
      # @option opts [Integer] :limit The maximum number of attachments to return.
      #  See {#attachments_query}.
      # @option opts [String] :order A string containing the <tt>ORDER BY</tt> clause for the attachments.
      #  See {#attachments_query}.
      #
      # @return [Integer] Returns the number of attachments that would be returned by the query.

      def attachments_count(opts = {})
        q = attachments_query(opts)
        (q.nil?) ? 0 : q.count
      end

      private

      # Generate the type lists from query options.
      # This method builds two lists, one that contains the content types to return
      # in the query, and one of content types to ignore in the query.
      # It essentially normalizes the content type options for WHERE clause generation.
      #
      # @param opts [Hash] A Hash containing configuration options for the query.
      # @option opts [Array<String>, String] :only_types A list of MIME types for attachments that should be
      #  returned by the query. This list can include "globbed" MIME types like +image/*+ to cover classes
      #  of content types. The globbed type +*/*+ is equivalent to "all types", and its presence is equivalent
      #  to not providing this option (all types are allowed).
      # @option opts [Array<String>, String] :except_types A list of MIME types for attachments that should
      #  *not* be returned by the query. This list can include "globbed" MIME types like +image/*+ to cover
      #  classes of content types. The globbed type +*/*+ is equivalent to "no types", and its presence will
      #  cause the query to return no results (no types are allowed).
      #  If a type is present in both *:only_types* and *:except_types*, it is not returned: *:except_types*
      #  has priority over *:only_types*.
      #
      # @return [Hash] Returns a hash with two entries:
      #  - *:only* is +nil+, to indicate that no "must-have" type selection is requested; or it is
      #    an array whose elements are MIME types for allowed content types.
      #  - *:except* is +nil+, to indicate that no "must-not-have" type selection is requested; or it is
      #    an array whose elements are MIME types for forbidden content types.

      def _normalize_attachment_type_lists(opts)
        only_types = opts[:only_types]
        except_types = opts[:except_types]
        rv = {
          :only => nil,
          :except => nil
        }

        # 1. Build the arrays of class objects

        rv[:only] = if only_types.is_a?(Array)
                      only_types.dup
                    elsif only_types.nil?
                      nil
                    else
                      [ only_types ]
                    end
        rv[:except] = if except_types.is_a?(Array)
                       except_types.dup
                     elsif except_types.nil?
                       nil
                     else
                       [ except_types ]
                     end

        # 2. Remove any except types from the only list
        #    We have to account for the (nonsensical) edge condition where :except_types contains */*,
        #    in which case we just eliminate everything from the query

        if rv[:except].is_a?(Array)
          if rv[:except].include?('*/*')
            rv[:only] = []
            rv[:except] = nil
          elsif rv[:only].is_a?(Array)
            rv[:only] = rv[:only] - rv[:except]
            rv[:except] = nil
          end
        end

        rv
      end
    end

    # Perform actions when the module is included.
    # - Injects the class methods and instance methods.
    # - In the context of the _base_ (and therefore of the attachable class), includes the module
    #   {Fl::Framework::Attachment::Attachable}.
    #
    # @param [Module] base The module or class that included this module.

    def self.included(base)
      base.extend ClassMethods

      base.send(:include, Fl::Framework::Attachment::Attachable)
      base.send(:include, Fl::Framework::Attachment::Query)
      base.send(:include, InstanceMethods)

      base.instance_eval do
      end

      base.class_eval do
      end
    end
  end
end
