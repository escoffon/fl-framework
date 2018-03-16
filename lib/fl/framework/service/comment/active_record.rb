require 'fl/framework/comment'
require 'fl/framework/service/comment'

# Namespace for service objects for comments.
# Comment service objects come in Active Record and Neo4j implementations.

module Fl::Framework::Service::Comment
  # Service object for comments that use an Active Record database.
  # This service manages comments associated with a commentable; one of the constructor arguments is the
  # actual class of the commentable.

  class ActiveRecord < Fl::Framework::Service::Nested
    self.model_class = Fl::Framework::Comment::ActiveRecord::Comment

    # Initializer.
    #
    # @param commentable_class [Class] The class object for the commentable; this is saved as the owner class.
    # @param actor [Object] The actor on whose behalf the service operates. It may be +nil+.
    # @param params [Hash] Processing parameters; this is typically the +params+ hash from a controller.
    # @param controller [ActionController::Base] The controller (if any) that created the service object;
    #  this parameter gives access to the request context.
    # @param cfg [Hash] Configuration options. See {Fl::Framework::Service::Base#initialize}.

    def initialize(commentable_class, actor, params = nil, controller = nil, cfg = {})
      super(commentable_class, actor, params, controller, cfg)
    end

    # @attribute [r] commentable_class
    # This is synctactic sugar that wraps {#owner_class}.
    # @return [Class] Returns the class object for the commentable.

    alias commentable_class owner_class

    # Get and check the commentable.
    # This is synctactic sugar that wraps {#get_and_check_owner}.
    #
    # @param [Symbol,nil] op The operation for which to request permission.
    # @param [Symbol, Array<Symbol>] idname The name or names of the key in _params_ that contain the object
    #  identifier for the owner.
    # @param [Hash] params The parameters where to look up the +:id+ key used to fetch the object.
    #
    # @return [Object, nil] Returns an object, or +nil+.

    alias get_and_check_commentable get_and_check_owner

    # Run a query and return results and pagination controls.
    # This method calls {Fl::Framework::Service::Base#init_query_opts} to build the query parameters, and then
    # {#index_query} to generate the query to use.
    #
    # @param [Object] commentable The commentable for which to get comments.
    # @param query_opts [Hash] Query options to merge with the contents of <i>_q</i> and <i>_pg</i>.
    #  This is used to define service-specific defaults.
    # @param _q [Hash, ActionController::Parameters] The query parameters.
    # @param _pg [Hash, ActionController::Parameters] The pagination parameters.
    #
    # @return [Hash, nil] If a query is generated, it returns a Hash containing two keys:
    #  - *:results* are the results from the query.
    #  - *:count* is the number of comments actually available; the query results may be limited by
    #    pagination.
    #  - *:_pg* are the pagination controls returned by {Fl::Framework::Service::Base#pagination_controls}.
    #  If no query is generated (in other words, if {#index_query} fails), it returns +nil+.

    def index(commentable, query_opts = {}, _q = {}, _pg = {})
      qo = init_query_opts(query_opts, _q, _pg)
      q = index_query(commentable, qo)
      if q
        r = q.to_a
        {
          result: r,
          _pg: pagination_controls(r, qo, self.params)
        }
      else
        nil
      end
    end

    # Get create parameters.
    #
    # @param p [Hash,ActionController::Parameters] The parameters from which to extract the create parameters
    #  subset.
    #
    # @return [ActionController::Parameters] Returns the create parameters.

    def create_params(p = nil)
      # :author is implicit in the current user
      cp = strong_params(p).require(:comment).permit(:title, :contents)

      cp[:author] = actor

      cp
    end

    protected

    # Build a query to list comments.
    # This method uses the _commentable_ {Fl::Framework::Comment::Query#comment_query} to build a query to
    # return comments associated with the commentable.
    # It uses the value of _query\\_opts_ merged with the value of +:query_opts+ in {#params}. (And therefore
    # +:query_opts+ in {#params} is a set of default values for the query.)
    # Note that this means that service clients can customize the query to return a subset of the available
    # comments, for example to return just the comments from a specific author.
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
    # @return If the query options are empty, the method returns the +comments+ association; if they are
    #  not empty, it returns an association relation.
    #  If the {#actor} does not have +:comment_index+ access, the return value is +nil+.

    def index_query(commentable, query_opts = {})
      return nil unless commentable.permission?(self.actor,
                                                Fl::Framework::Comment::Commentable::ACCESS_COMMENT_INDEX)

      commentable.comments_query(query_opts)
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
      return nil unless commentable.permission?(self.actor, Fl::Framework::Comment::Commentable::ACCESS_COMMENT_INDEX)
      commentable.comments_count(query_opts)
    end
  end
end
