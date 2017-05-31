module Fl::Framework::Service
  # Service object for comments.
  # This service manages comments associated with a commentable; one of the constructor arguments is the
  # actual class of the commentable.

  class Comment < Fl::Framework::Service::Base
    self.model_class = Fl::Framework::Comment::Neo4j::Comment

    # Initializer.
    #
    # @param commentable_class [Class] The class object for the commentable.
    # @param actor [Object] The actor on whose behalf the service operates. It may be +nil+.
    # @param params [Hash] Processing parameters; this is typically the +params+ hash from a controller.
    # @param controller [ActionController::Base] The controller (if any) that created the service object;
    #  this parameter gives access to the request context.
    # @param cfg [Hash] Configuration options. See {Fl::Framework::Service::Base.initialize}.

    def initialize(commentable_class, actor, params = {}, controller = nil, cfg = {})
      @commentable_class = commentable_class

      super(actor, params, controller, cfg)
    end

    # @attribute [r] commentable_class
    #
    # @return [Class] Returns the class object for the commentable.

    def commentable_class()
      @commentable_class
    end

    # Look up a commentable in the database, and check if the service's actor has permissions on it.
    # This method uses the +:commentable_id+ entry in the {#params} to look up the object in the database
    # (using the commentable model class as the context for +find+).
    # If it does not find the object, it sets the status to {Fl::Framework::Service::NOT_FOUND} and returns
    # +nil+.
    # If it finds the object, it then calls {Fl::Access::Access::InstanceMethods#permission?} to
    # confirm that the actor has _op_ access to the object.
    # If the permission call fails, it sets the status to {Fl::Framework::Service::FORBIDDEN} and returns the
    # object.
    # Otherwise, it sets the status to {Fl::Framework::Service::OK} and returns the object.
    #
    # @param [Symbol] op The operation for which to request permission. If +nil+, no access check is performed
    #  and the call is the equivalent of a simple database lookup.
    # @param [Symbol, Array<Symbol>] idname The name or names of the key in _params_ that contain the object
    #  identifier for the commentable. A +nil+ value defaults to +:commentable_id+.
    # @param [Hash] params The parameters where to look up the +:id+ key used to fetch the object.
    #  If +nil+, use the _params_ value that was passed to the constructor.
    #
    # @return [Object, nil] Returns an object, or +nil+. Note that a non-nil return value is not a guarantee
    #  that the check operation succeded.

    def get_and_check_commentable(op, idname = nil, params = nil)
      idname = idname || :commentable_id
      idname = [ idname ] unless idname.is_a?(Array)
      found_id = nil
      params = params || self.params


      obj = nil
      idname.each do |idn|
        if params.has_key?(idn)
          begin
            obj = self.commentable_class.find(params[idn])
            found_id = idn
            break
          rescue Neo4j::ActiveNode::Labels::RecordNotFound => ex
            obj = nil
          end
        end
      end

      if obj.nil?
        self.set_status(Fl::Framework::Service::NOT_FOUND,
                        I18n.tx(localization_key('not_found'), id: idname.join(',')))
        return nil
      end

      self.clear_status if allow_op?(obj, op, nil, found_id)
      obj
    end

    # Build a query to list comments.
    # This method uses the _commentable_ association +comments+ to build a query to return comments
    # associated with the commentable.
    # It uses the value of _query\\_opts_ merged with the value of +:query_opts+ in {#params}. (And therefore
    # +:query_opts+ in {#params} is a set of default values for the query.)
    #
    # @param commentable [Object] A commentable object that is expected to respond to +comments+.
    # @param query_opts [Hash] A hash of query options that will be merged into the defaults from
    #  {#params}, if any.
    #  The method also processes the following.
    # @option query_opts [String] :order The +ORDER BY+ clause. Because the query returns objects in the
    #  +c+ variable, each entry in the clause is scoped to +c.+ if necessary. For example, a value of
    #  <tt>title ASC, updated_at DESC</tt> is converted to <tt>c.title ASC, c.updated_at DESC</tt>.
    # @option query_opts [String, Integer] :limit The +LIMIT+ clause.
    # @option query_opts [String, Integer] :skip The +SKIP+ clause.
    #
    # @return Returns a Neo4j Query object or query proxy containing the following variables:
    #  - +c+ The comments.
    #  If the {#actor} does not have +:comment_index+ access, the return value is +nil+.

    def index_query(commentable, query_opts = {})
      return nil unless commentable.permission?(self.actor, Fl::Comment::Commentable::ACCESS_COMMENT_INDEX)

      q_opts = _init_query_opts(query_opts)

      q = commentable.comments.query_as(:c)

      if q_opts.has_key?(:order)
        s = q_opts[:order].split(',').map do |e|
          t = e.strip
          (t.start_with?('c.')) ? t : 'c.' + t
        end
        q = q.order(s.join(', '))
      end

      if q_opts.has_key?(:limit)
        q = q.limit(q_opts[:limit])
      end

      if q_opts.has_key?(:offset)
        q = q.skip(q_opts[:offset])
      end

      q
    end

    # Build a query to count comments.
    # This method uses the _commentable_ association +comments+ to build a query to return a count of comments
    # associated with the commentable.
    # It uses the value of _query\\_opts_ merged with the value of +:query_opts+ in {#params}. (And therefore
    # +:query_opts+ in {#params} is a set of default values for the query.)
    # However, it strips any *:offset*, *:limit*, and *:order* keys from the query options before generating
    # the query object via a call to {#index_query}.
    # It then and adds a +count+ clause to the query.
    #
    # @param commentable [Object] A commentable object that is expected to respond to +comments+.
    # @param query_opts [Hash] A hash of query options that will be merged into the defaults from
    #  {#params}, if any.
    #
    # @return Returns a Neo4j Query object or query proxy containing the following variables:
    #  - +ccount+ (Note the double 'c') is the count of comments.
    # If the {#actor} does not have +:comment_index+ access, the return value is +nil+.

    def count_query(commentable, query_opts = {})
      return nil unless commentable.permission?(self.actor, Fl::Comment::Commentable::ACCESS_COMMENT_INDEX)

      # These are currently not needed, but were left in for possible later use

      #q_opts = _init_query_opts(query_opts)
      #q_opts.delete(:offset)
      #q_opts.delete(:limit)
      #q_opts.delete(:order)

      q = commentable.comments.query_as(:c)

      # and here is where we would use q_opts

      q
    end

    # Run a query and return results and pagination controls.
    # This method calls {Fl::Framework::Service::Base#init_query_opts} to build the query parameters, and then
    # {#index_query} to generate the query to use.
    #
    # @param [Object] commentable The commentable for which to get comments.
    #
    # @return [Hash, nil] If a query is generated, it returns a Hash containing two keys:
    #  - *:results* are the results from the query.
    #  - *:count* is the number of comments actually available; the query results may be limited by
    #    pagination.
    #  - *:_pg* are the pagination controls returned by {Fl::Framework::Service::Base#pagination_controls}.
    #  If no query is generated (in other words, if {#index_query} fails), it returns +nil+.

    def index(commentable)
      iqo = init_query_opts(nil, self.params)
      cqo = iqo.dup
      cqo.delete(:offset)
      cqo.delete(:limit)
      cqo.delete(:order)
      iq = index_query(commentable, iqo)
      cq = count_query(commentable, cqo)
      if iq && cq
        {
          result: iq.pluck('DISTINCT c'),
          count: cq.pluck('count(c)')[0],
          _pg: pagination_controls(iqo, self.params)
        }
      else
        nil
      end
    end

    # Create a comment for a commentable object.
    # This method looks up the commentable by id, using the {#commentable_class} value, and checks that
    # the current user has +:read+ privileges on it, and then creates a comment for it.
    #
    # @param data [Hash] Comment data.
    # @option data [String] :contents The comment contents; this is a required value.
    # @option data [String] :title The comment title; if not present, the title is extracted from the
    #  first 40 character of the contents.
    # @param idname [Symbol] The name of the key in _params_ that contains the commentable's identifier.
    #  A value of +nil+ is converted to +:commentable_id+.
    # @param params [Hash] The parameters to use; if +nil+, the parameters that were passed to the
    #  constructor are used.
    #
    # @return [Fl::Comment] Returns an instance of {#Fl::Comment}. Note that a non-nil
    #  return value here does not indicate a successful call: clients need to check the object's status
    #  to confirm that it was created (for example, call +valid?+).

    def create(data, idname = nil, params = nil)
      idname = idname || :commentable_id
      params = params || self.params

      commentable = get_and_check_commentable(Fl::Comment::Commentable::ACCESS_COMMENT_CREATE, idname)
      if success?
        comment = commentable.add_comment(self.actor, data[:contents], data[:title])
        if commentable.errors.count > 0
          set_status(Fl::Framework::Service::UNPROCESSABLE_ENTITY,
                     I18n.tx('fl.asset.service.comment.cannot_create', id: commentable.id),
                     commentable.errors)
        else
          # adding a comment is considered an update

          commentable.updated_at = Time.now.to_i
          commentable.save
        end
      else
        comment = nil
      end

      comment
    end

    private

    def _init_query_opts(query_opts)
      q_opts = (self.params[:query_opts]) ? self.params[:query_opts].merge(query_opts) : query_opts.dup

      q_opts.delete(:limit) if q_opts.has_key?(:limit) && (q_opts[:limit].to_i < 0)

      q_opts
    end
  end
end
