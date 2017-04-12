module Fl::Framework::Comment::ActiveRecord
  # ActiveRecord-specific functionality for the comment management extension module.

  module Commentable
    include Fl::Framework::Comment::Query

    # The methods in this module will be installed as class methods of the including class.

    module ClassMethods
    end

    # The methods in this module are installed as instance method of the including class.

    module InstanceMethods
      # Build a query to fetch an object's comments.
      #
      # Note that any WHERE clauses from *:updated_after*, *:created_after*, *:updated_before*,
      # and *:created_before* are concatenated using the AND operator. The values for these options are:
      # a UNIX timestamp; a Time object; a string containing a representation of the time (this string
      # is converted to a {Fl::Framework::Core::Icalendar::Datetime} internally).
      #
      # @param opts [Hash] A Hash containing configuration options for the query.
      # @option opts [Array<Object, String>, Object, String] :only_authors See the discussion of this
      #  option in {Fl::Framework::Comment::Query#_expand_author_list}.
      # @option opts [Array<Object>, Object] :except_authors See the discussion of this
      #  option in {Fl::Framework::Comment::Query#_expand_author_list}.
      # @option opts [Array<Object>, Object] :only_groups See the discussion of this
      #  option in {Fl::Framework::Comment::Query#_expand_author_list}.
      # @option opts [Array<Object>, Object] :except_groups See the discussion of this
      #  option in {Fl::Framework::Comment::Query#_expand_author_list}.
      # @option opts [Integer, Time, String] :updated_after selects comments updated after a given time.
      # @option opts [Integer, Time, String] :created_after selects comments created after a given time.
      # @option opts [Integer, Time, String] :updated_before selects comments updated before a given time.
      # @option opts [Integer, Time, String] :created_before selects comments created before a given time.
      # @option opts [Integer] :offset Sets the number of records to skip before returning;
      #  a +nil+ value causes the option to be ignored.
      #  Defaults to 0 (start at the beginning).
      # @option opts [Integer] :limit The maximum number of comments to return;
      #  a +nil+ value causes the option to be ignored.
      #  Defaults to all comments.
      # @option opts [String] :order A string containing the <tt>ORDER BY</tt> clause for the comments;
      #  a +nil+ value causes the option to be ignored.
      #  Defaults to <tt>created_at DESC</tt>, so that the comments are ordered by creation time, 
      #  with the most recent one listed first.
      #
      # Note that *:limit*, *:offset*, and *:order* are convenience options, since they can be
      # added later by making calls to +limit+, +offset+, and +order+, respectively, on the return value.
      #
      # @return If the query options are empty, the method returns the +comments+ association; if they are
      #  not empty, it returns an association relation.
      #  If +self+ does not seem to have a +comments+ association, it returns +nil+.
      #
      # @example Get the last 10 comments from all users (showing equivalent calls)
      #  c = get_commentable_object()
      #  q = c.comments_query(limit: 10)
      #  q = c.comments_query().limit(10)
      #  q = c.comments_query(order: nil).order('created_at DESC').limit(10)
      #
      # @example Get the first 10 comments from a given user (showing equivalent calls)
      #  c = get_commentable_object()
      #  u = get_user()
      #  q = c.comments_query(only_authors: u, order: 'created_at ASC, limit: 10)
      #  q = c.comments_query(only_authors: u, order: nil).order('created_at ASC').limit(10)
      #
      # @example Get all comments not from a given user
      #  c = get_commentable_object()
      #  u = get_user()
      #  q = c.comments_query(except_authors: u)
      #
      # @example Get all comments from a given user that were created less than ten days ago
      #  c = get_commentable_object()
      #  u = get_user()
      #  t = Time.new
      #  t -= 10.days
      #  q = c.comments_query(only_authors: u, created_since: t)

      def comments_query(opts = {})
        return nil unless self.respond_to?(:comments)

        q = self.comments

        u_lists = _partition_author_lists(_expand_author_lists(opts))

        if u_lists[:only_ids]
          # If we have :only_ids, the :except_ids have already been eliminated, so all we need is the only_ids

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

      # Build a query to fetch an object's comments and subcomments.
      # Subcomments are comments associated with the top level comments.
      # This method adds a +WITH+ statement, followed by an +OPTIONAL_MATCH+ statement that picks up each
      # comment's subcomments.
      #
      # @param query [Neo4j::Core::Query] A query object as returned by
      #  {Fl::Framework::Comment::Query#comments_query} and possibly further modified.
      # @param opts [Hash] A hash containing configuration options for the query.
      # @option opts [String, Array<String, Symbol>] :with A string containing the list of variables
      #  returned by the +WITH+ statement. This value can also be an array of strings or symbols.
      #  The default value is the string +comment+,
      #  so that only the +comment+ variable is passed down to the +OPTIONAL_MATCH+ statement.
      # @option opts [Array<Fl::Core::Author>, Fl::Core::Author] :only_authors behaves just like the
      #  equivalent configuration option for {Fl::Framework::Comment::Query#comments_query}, but applied
      #  to subcomments.
      # @option opts [Array<Fl::Core::Author>, Fl::Core::Author] :except_authors behaves just like the
      #  equivalent configuration option for {Fl::Framework::Comment::Query#comments_query}, but applied
      #  to subcomments.
      # @option opts [Array<Fl::Core::Group>, Fl::Core::Group] :only_groups behaves just like the equivalent
      #  configuration option for {Fl::Framework::Comment::Query#comments_query}, but applied to subcomments.
      # @option opts [Array<Fl::Core::Group>, Fl::Core::Group] :except_groups behaves just like the equivalent
      #  configuration option for {Fl::Framework::Comment::Query#comments_query}, but applied to subcomments.
      # @option opts [Integer] :updated_after behaves just like the equivalent
      #  configuration option for {Fl::Framework::Comment::Query#comments_query}, but applied to subcomments.
      # @option opts [Integer] :created_after behaves just like the equivalent
      #  configuration option for {Fl::Framework::Comment::Query#comments_query}, but applied to subcomments.
      # @option opts [Integer] :updated_before behaves just like the equivalent
      #  configuration option for {Fl::Framework::Comment::Query#comments_query}, but applied to subcomments.
      # @option opts [Integer] :created_before behaves just like the equivalent
      #  configuration option for {Fl::Framework::Comment::Query#comments_query}, but applied to subcomments.
      #
      # @return [Neo4j::Core::Query] Returns a query object containing the query to be executed.
      #  By default, the following variables are bound in the query:
      #  - +comment+ is the comment object.
      #  - +subcomment_rel+ is the +COMMENT_FOR+ relationship between comment and subcomment.
      #  - +subcomment+ is the subcomment object.
      #  - +subowner+ is the subcomment's owner. This variable is present only if any of the +only_+ or
      #    +except_+ options are present.
      #  Additional variables may be bound, based on the value of the *:with* option.
      #
      # Just as for #comments_query, the return value can be further modified. This example returns
      # the subcomments from the last N comments, ordered by creation time of the subcomment and grouped in an
      # array; also, only comments from specific authors are returned.
      #  def get_last_comments_and_subcomments(commentable, limit = 10, authors = nil)
      #   opts = {}
      #   opts[:only_authors] = authors unless authors.nil?
      #
      #   cq = commentable.comments_query(opts).order('comment.created_at DESC').limit(limit)
      #   commentable.subcomments_query(cq, opts)\
      #     .with('comment, subcomment')\
      #     .order('comment.created_at DESC, subcomment.created_at DESC')\
      #     .return('comment, collect(subcomment) AS subcomments').order('comment.updated_at DESC')
      #  end
      # (This is more or less the query generated by [#comments_with_subcomments_query}.)

      def subcomments_query(query, opts = {})
        with_list = opts[:with] || 'comment'

        u_lists = _expand_author_lists(opts)
        match = "(comment)<-[subcomment_rel:COMMENT_FOR]-(subcomment:`#{Fl::Comment::Comment.name}`)"
        where_clause = ''
        where_params = {}
        if !u_lists[:only_ids].nil? || !u_lists[:except_ids].nil?
          match << "<-[:IS_OWNER_OF]-(subowner:`#{Fl::Core::Author.name}`)"
        end
        if !u_lists[:only_ids].nil?
          where_clause << ' AND ' if where_clause.length > 0
          where_clause << '(id(subowner) IN {s_only_ids})'
          where_params[:s_only_ids] = u_lists[:only_ids]
        elsif !u_lists[:except_ids].nil?
          where_clause << ' AND ' if where_clause.length > 0
          where_clause << '(NOT id(subowner) IN {s_except_ids})'
          where_params[:s_except_ids] = u_lists[:except_ids]
        end

        ts = _date_filter_timestamps(opts)
        if ts[:c_after_ts]
          where_clause << ' AND ' if where_clause.length > 0
          where_clause << '(subcomment.created_at > {sc_after_ts})'
          where_params[:sc_after_ts] = ts[:c_after_ts]
        end
        if ts[:u_after_ts]
          where_clause << ' AND ' if where_clause.length > 0
          where_clause << '(subcomment.updated_at > {su_after_ts})'
          where_params[:su_after_ts] = ts[:u_after_ts]
        end
        if ts[:c_before_ts]
          where_clause << ' AND ' if where_clause.length > 0
          where_clause << '(subcomment.created_at < {sc_before_ts})'
          where_params[:sc_before_ts] = ts[:c_before_ts]
        end
        if ts[:u_before_ts]
          where_clause << ' AND ' if where_clause.length > 0
          where_clause << '(subcomment.updated_at < {su_before_ts})'
          where_params[:su_before_ts] = ts[:u_before_ts]
        end

        q = query.with(with_list).optional_match(match)
        q = q.where(where_clause, where_params) if where_clause.length > 0

        q
      end

      # Utility method to fetch comments and subcomments.
      # This method uses {Fl::Framework::Comment::Query#comments_query} and {#subcomments_query} to generate a query, including a call
      # to +return+ to bind the selection variables.
      #
      # @param opts [Hash] A hash containing configuration options for the query.
      # @option opts [Integer] :max_comments The maximum number of comments to return.
      #  Defaults to all comments.
      # @option opts [Integer] :max_subcomments The maximum number of subcomments (per comment) to return.
      #  Defaults to all subcomments.
      # @option opts [Hash] :comment_opts A hash of configuration options to pass to {Fl::Framework::Comment::Query#comments_query}.
      #  Defaults to an empty hash.
      # @option opts [String] :comment_order A string containing the <tt>ORDER BY</tt> clause for the comments.
      #  Defaults to <tt>comment.created_at DESC</tt>, so that the comments are ordered by creation time, 
      #  with the most recent one listed first.
      # @option opts [Hash] :subcomment_opts A hash of configuration options to pass to {#subcomments_query}.
      #  Defaults to an empty Hash.
      # @option opts [String] :subcomment_order A string containing the <tt>ORDER BY</tt> clause for the
      #  subcomments.
      #  Defaults to <tt>subcomment.created_at DESC</tt>, so that the subcomments are ordered by creation time,
      #  wit the most recent one listed first.
      # @option opts [String] :return A string containing the <tt>RETURN</tt> clause for the query.
      #  Defaults to <tt>comment, collect(subcomment) AS subcomments</tt> (or an equivalent format), so that
      #  the query returns one row per comment, a +struct+ whose +comment+ property is the comment object,
      #  and +subcomments+ property an array of subcomments.
      #  Note that, if *:max_subcomments* is defined, this option is ignored and the default value is used.
      #
      # The *:max_comments* option is used to add a +LIMIT+ clause to the comments query, and therefore at
      # most that number of comments is returned by the pattern matching. The *:max_subcomments* option
      # works by adding an extra +WITH+ statement to the query, and limiting the number of returned
      # subcomments via a range; the pattern matching itself always returns all subcomments, but the query
      # overall may trim off a number of the returned rows. What that means is that there is probably
      # no real performance advantage to using *:max_subcomments* (and there may be a penalty instead),
      # and clients may be better off getting the full list and trimming it afterwards. On the other hand,
      # for comments that have a significant amount of subcomments, the extra step of trimming at the server
      # may offset having to send a number of unwanted subcomments with the response.
      # Also, if *:max_subcomments* is defined, the query must be set up so that the +RETURN+ clause
      # returns one comment and a list of subcomments per row, and therefore the *:return* option is
      # ignored.
      #
      # @example Return only the 10 most recent comments:
      #  q = o.comments_with_subcomments_query(max_comments: 10)
      # @example Return the 10 most recent comments by author +u1+:
      #  q = o.comments_with_subcomments_query(max_comments: 10, comment_opts: { only_authors: u1 })
      # @example Return comments and subcomments from author +u1+ only:
      #  q = o.comments_with_subcomments_query(max_comments: 10, comment_opts: { only_authors: u1 },
      #                                        subcomment_opts: { only_authors: u1 })
      # @example Print the last 10 comments and their last 4 subcomments:
      #  sq = o.comments_with_subcomments_query(max_comments: 10, max_subcomments: 4)
      #  sq.each do |row|
      #    c = row.comment
      #    sc = row.subcomments
      #    print("++++ #{c.title} (#{c.author.authorname})\n")
      #    sc.each { |s| print("  ++ #{s.title} (#{s.author.authorname})\n") }
      #  end
      #
      # @return [Neo4j::Core::Query] Returns a query object containing the query to be executed.
      #  By default, the following variables are bound in the query:
      #  - +comment+ is the comment object.
      #  - +subcomments+ is an array containing subcomment objects for +comment+.
      #  Additional variables may be bound, based on the value of the *:return* option.

      def comments_with_subcomments_query(opts = {})
        c_opts = opts[:comment_opts] || {}
        s_opts = opts[:subcomment_opts] || {}

        c_order = opts[:comment_order] || 'comment.created_at DESC'
        t = opts[:subcomment_order] || 'subcomment.created_at DESC'
        s_order = "#{c_order}, #{t}"

        max_comments = opts[:max_comments]
        max_subcomments = opts[:max_subcomments]

        cq = self.comments_query(c_opts).order(c_order)
        cq = cq.limit(max_comments) if max_comments

        sq = self.subcomments_query(cq, s_opts).with('comment, subcomment').order(s_order)
        if max_subcomments
          sq = sq.break.with('comment, collect(subcomment) AS sct')
          s_return = "comment, sct[0..#{max_subcomments}] AS subcomments"
        else
          s_return = opts[:subcomment_return] || 'comment, collect(subcomment) AS subcomments'
        end

        sq.return(s_return).order(c_order)
      end

      # Execute a query to fetch the number of comments associated with an object.
      # The number returned is subject to the configuration options +opts+; for example,
      # if <tt>opts[:only_authors]</tt> is defined, the return value is the number of comments for +self+
      # and created by the given authors.
      #
      # @param opts [Hash] A Hash containing configuration options for the query.
      # @option opts [Array<Object, String>, Object, String] :only_authors See the discussion of this
      #  option in {Fl::Framework::Comment::Query#_expand_author_list}.
      # @option opts [Array<Object>, Object] :except_authors See the discussion of this
      #  option in {Fl::Framework::Comment::Query#_expand_author_list}.
      # @option opts [Array<Object>, Object] :only_groups See the discussion of this
      #  option in {Fl::Framework::Comment::Query#_expand_author_list}.
      # @option opts [Array<Object>, Object] :except_groups See the discussion of this
      #  option in {Fl::Framework::Comment::Query#_expand_author_list}.
      # @option opts [Integer, Time, String] :updated_after selects comments updated after a given time.
      # @option opts [Integer, Time, String] :created_after selects comments created after a given time.
      # @option opts [Integer, Time, String] :updated_before selects comments updated before a given time.
      # @option opts [Integer, Time, String] :created_before selects comments created before a given time.
      # @option opts [Integer] :offset Sets the number of records to skip before returning;
      #  a +nil+ value causes the option to be ignored.
      #  Defaults to 0 (start at the beginning).
      # @option opts [Integer] :limit The maximum number of comments to return;
      #  a +nil+ value causes the option to be ignored.
      #  Defaults to all comments.
      # @option opts [String] :order A string containing the <tt>ORDER BY</tt> clause for the comments;
      #  a +nil+ value causes the option to be ignored.
      #  Defaults to <tt>created_at DESC</tt>, so that the comments are ordered by creation time, 
      #  with the most recent one listed first.
      #
      # @return [Integer] Returns the number of comments that would be returned by the query.

      def comments_count(opts = {})
        q = comments_query(opts)
        (q.nil?) ? 0 : q.count
      end
    end

    # Perform actions when the module is included.
    # - Injects the class methods.
    # - Injects the instance methods.

    def self.included(base)
      base.extend ClassMethods

      base.instance_eval do
      end

      base.class_eval do
        include InstanceMethods
      end
    end
  end
end
