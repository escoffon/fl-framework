module Fl::Framework::Comment::Neo4j
  # Implementation of the comment object for a Neo4j database.
  #
  # === Properties
  # This class defines the following properties:
  # - +title+ is a string containing a title for the comment.
  # - +contents+ is a astring containing the contents of the comment.
  # - +created_at+ is an Integer containing the UNIX creation time.
  # - +updated_at+ is an Integer containing the UNIX modification time.
  #
  # === Associations
  # Fl::Framework::Comment::Neo4j::Comment defines a number of associations:
  # - *commentable* is the object associated with this comment (the _commentable_ object).
  # - *author* is the entity (typically a user) that created the comment.
  # - *comments* is the list of comments associated with this comment (and therefore, the comment's
  #   subcomments that make up the conversation about the comment).

  class Comment
    include Neo4j::ActiveNode

    include Fl::Framework::Comment::Access
    include Fl::Framework::Comment::Validation
    include Fl::Framework::Comment::ModelHash
    include Fl::Framework::Comment::TitleManagement
    include Fl::Framework::Comment::AttributeFilters
    include Fl::Framework::Comment::Helper
    include Fl::Framework::Comment::Commentable

    # @!attribute [rw] title
    # The comment title; typically generated from the first (40) character of the contents.
    # @return [String] Returns the comment title.
    property :title, type: String

    # @!attribute [rw] contents
    # The comment contents.
    # @return [String] Returns the comment contents.
    property :contents, type: String

    # @!attribute [rw] created_at
    # The time when the comment was created.
    # @return [Integer] Returns the timestamp of the creation time of the comment.
    property :created_at, type: Integer

    # @!attribute [rw] updated_at
    # The time when the comment was updated.
    # @return [Integer] Returns the timestamp of the modification time of the comment.
    property :updated_at, type: Integer

    # @!attribute [r] commentable
    # The object to which the comment is attached.
    # @return [Object] Returns the object to which the comment is attached. This object is expected
    #  to have included the {Fl::Framework::Comment::Commentable} module and registered via
    #  {Fl::Framework::Comment::Commentable#has_comments}.
    has_one :out, :commentable, rel_class: :'Fl::Framework::Neo4j::Rel::Core::CommentFor'

    # @!attribute [r] author
    # The entity that created the comment, and therefore owns it.
    # @return [Object] Returns the object that created the comment.
    has_one :in, :author, rel_class: :'Fl::Framework::Neo4j::Rel::Core::IsOwnerOf'

    # has_comments defines the :comments association

    # @!attribute [rw] comments
    # The comments for this comment.
    # It is possible to comment on a comment.
    # @return [Neo4j::ActiveNode::Query] Returns a Neo4j ActiveNode association listing comments.

    has_comments

    before_create :_populate_timestamps
    before_save :_update_updated_at

    # Initializer.
    #
    # @param attrs [Hash] A hash of initialization parameters.
    # @option attrs [Object, Hash, String] :author The comment author. The value is resolved via a call
    #  to {Fl::Framework::Comment::Comment::Helper.author_from_parameter}.
    # @option attrs [Object, Hash, String] :commentable The associated commentable. The value is resolved via
    #  a call to {Fl::Framework::Comment::Comment::Helper.commentable_from_parameter}.
    # @option attrs [String] :contents The comment contents.
    # @option attrs [String] :title The comment title; if not given, the first 40 characters of the content
    #  are used.

    def initialize(attrs = {})
      begin
        attrs[:author] = Fl::Framework::Comment::Helper.author_from_parameter(attrs)
      rescue => exc
        self.errors[:author] << exc.message
      end

      begin
        attrs[:commentable] = Fl::Framework::Comment::Helper.commentable_from_parameter(attrs)
      rescue => exc
        self.errors[:commentable] << exc.message
      end

      @needs_updated_at = true

      super(attrs)
    end

    # @!visibility private
    alias _original_created_at= created_at=

    # @!visibility private
    alias _original_updated_at= updated_at=

    # Set the creation time.
    #
    # @param ctime The creation time; this can be an integer UNIX timestamp, or a TimeWithZone instance.

    def created_at=(ctime)
      ctime = ctime.to_i unless ctime.is_a?(Integer)
      self._original_created_at=(ctime)
    end

    # Set the update time.
    #
    # @param utime The update time; this can be an integer UNIX timestamp, or a TimeWithZone instance.

    def updated_at=(utime)
      @needs_updated_at = false
      utime = utime.to_i unless utime.is_a?(Integer)
      self._original_updated_at=(utime)
    end

    private

    def _populate_timestamps()
      ts = Time.new.to_i
      _original_created_at=(ts) if self.created_at.blank?
      _original_updated_at=(ts) if self.updated_at.blank?
    end

    def _update_updated_at()
      if @needs_updated_at
        ts = Time.new.to_i
        _original_updated_at=(ts)
      end
      @needs_updated_at = true
    end
  end
end
