require 'fl/framework/application_record'
require 'fl/framework/comment/common'

module Fl::Framework::Comment::ActiveRecord
  # Implementation of the comment object for an ActiveRecord database.
  # It will need the migration +create_fl_framework_comments+.
  #
  # === Attributes
  # This class defines the following attributes:
  # - +title+ is a string containing a title for the comment.
  # - +contents+ is a astring containing the contents of the comment.
  # - +created_at+ is an Integer containing the UNIX creation time.
  # - +updated_at+ is an Integer containing the UNIX modification time.
  #
  # === Associations
  # Fl::Framework::Core::Comment::ActiveRecord::Comment defines a number of associations:
  # - *commentable* is the object associated with this comment (the _commentable_ object).
  # - *author* is the entity (typically a user) that created the comment.
  # - *comments* is the list of comments associated with this comment (and therefore, the comment's
  #   subcomments that make up the conversation about the comment).

  class Comment < Fl::Framework::ApplicationRecord
    include Fl::Framework::Comment::Common

    self.table_name = 'fl_framework_comments'

    # @!attribute [rw] title
    # The comment title; typically generated from the first (40) character of the contents.
    # @return [String] Returns the comment title.

    # @!attribute [rw] contents
    # The comment contents.
    # @return [String] Returns the comment contents.

    # @!attribute [rw] created_at
    # The time when the comment was created.
    # @return [DateTime] Returns the creation time of the comment.

    # @!attribute [rw] updated_at
    # The time when the comment was updated.
    # @return [DateTime] Returns the modification time of the comment.

    # @!attribute [r] commentable
    # The object to which the comment is attached.
    # @return [Object] Returns the object to which the comment is attached. This object is expected
    #  to have included the {Fl::Framework::Comment::Commentable} module and registered via
    #  {Fl::Framework::Comment::Commentable#has_comments}.
    belongs_to :commentable, polymorphic: true

    # @!attribute [r] author
    # The entity that created the comment, and therefore owns it.
    # @return [Object] Returns the object that created the comment.
    belongs_to :author, polymorphic: true

    # has_comments defines the :comments association

    # @!attribute [rw] comments
    # The comments for this comment.
    # It is possible to comment on a comment.
    # @return [ActiveRecord::Associations::CollectionProxy] Returns an ActiveRecord association listing
    #  comments.

    has_comments

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

      super(attrs)
    end
  end
end
