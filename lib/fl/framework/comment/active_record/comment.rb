require 'fl/framework/application_record'
require 'fl/framework/comment/common'
require 'fl/framework/attachment/attachable'
require 'fl/framework/attachment/active_record'

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
  # - *attachments* is the list of attachments associated with this comment.

  class Comment < Fl::Framework::ApplicationRecord
    include Fl::Framework::Access::Access
    include Fl::Framework::Comment::Common
    include Fl::Framework::Attachment::Attachable
    include Fl::Framework::Attachment::ActiveRecord::Attachable

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

    # has_attachments defines the :attachments association

    # @!attribute [rw] attachments
    # The attachments for this comment.
    # Currently allows just image attachments (MIME type +image/*+).
    # @return [ActiveRecord::Associations::CollectionProxy] Returns an ActiveRecord association listing
    #  attachments.

    has_attachments :attachments, only: 'image/*'

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

    # The centralized access checker method.
    # All supported operations are checked here.
    #
    # @param op [Fl::Framework::Access::Access::Checker] The requested operation.
    # @param obj [Object] The target of the request.
    # @param actor [Object] The actor requesting permission.
    # @param context The context in which to do the check.
    #
    # @return [Boolean] Returns a symbol corresponding to the access level granted, or +nil+ if access is
    #  denied. The following operations are supported:
    #  - *:index* returns +:public+, since comments are publicly accessible.
    #  - *:create* returns +nil+ if _actor_ is +nil+; otherwise, it returns +:public+.
    #    rrently, anyone can comment a comment.
    #  - *:read* returns +:public+, since comments are publicly accessible.
    #  - *:write* returns +nil+, since we currently don't allow editing.
    #  - *:destroy* returns +nil+, since we currently don't allow deletion.
    #  - *:comment_index* returns +:public+, since anybody can get the comments for a comment.
    #  - *:comment_create* returns +nil+ if _actor_ is +nil+; otherwise, it returns +:public+.
    #    Anybody can comment on a comment, but they must be logged in.
    #  - *:attachment_index* returns +:public+, since anybody can get the attachments for a comment.
    #  - *:attachment_create* returns +nil+ if _actor_ is +nil+; otherwise, it returns +:public+.
    #    Anybody can add attachments to a comment, but they must be logged in.
    #    We may make this more restrictive later.

    def self.default_access_checker(op, obj, actor, context = nil)
      print("++++++++++ check #{op.op} - #{actor} - #{context}\n")
      case op.op
      when Fl::Framework::Access::Grants::INDEX
        :public
      when Fl::Framework::Access::Grants::CREATE
        (actor.nil?) ? nil : :public
      when Fl::Framework::Access::Grants::READ
        :public
      when Fl::Framework::Access::Grants::WRITE
        nil
      when Fl::Framework::Access::Grants::DESTROY
        nil
      when Fl::Framework::Comment::Commentable::ACCESS_COMMENT_INDEX
        :public
      when Fl::Framework::Comment::Commentable::ACCESS_COMMENT_CREATE
        (actor.nil?) ? nil : :public
      when Fl::Framework::Attachment::Attachable::ACCESS_ATTACHMENT_INDEX
        :public
      when Fl::Framework::Attachment::Attachable::ACCESS_ATTACHMENT_CREATE
        # We may need to change this: only author can attach, which means we need to add author to campgrounds
        (actor.nil?) ? nil : :public
      else
        nil
      end
    end
  end
end
