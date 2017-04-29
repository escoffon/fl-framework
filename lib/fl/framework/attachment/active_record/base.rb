require 'fl/framework/attachment/active_record/registration'
require 'fl/framework/attachment/common'
require 'fl/framework/attachment/helper'

module Fl::Framework::Attachment::ActiveRecord
  # Base class for attachments on ActiveRecord objects.
  # Attachments always appear in the database associated with another object, which is referred to as the
  # attachment's _attachable_.
  #
  # Attachments implement the access control API in {Fl::Framework::Access::Access}, but forward permission
  # calls to the attachable object as described in {Fl::Framework::Attachment::Common}.
  #
  # This base class and its underlying table have been set up for Single Table Inheritance, so that all
  # attachment subtypes can be kept in a single table. STI is appropriate here, because the various
  # subclasses are not expected to vary much (if any) in the set of attributes they support.
  # One consequence of using STI is that the Paperclip attachment's attributes are stored in the common table,
  # and therefore all subclasses must use the common attachment name, which is +:attachment+.
  # This is inconvenient, since different names provide hints to the supported contents of the attachment
  # for each class. Additionally, we cannot associate the Paperclip attachment to the +:attachment+ attributes
  # in the base class (we can't put a call to +activerecord_attachment+ or +neo4j_attachment+ in the
  # base class), since different attachment subclasses will likely want to set different configurations
  # for their Paperclip attachments.
  # So, there are two issues here: first, {Base} does not associate a Paperclip attachment, leaving it to
  # the subclasses to do so; and, second, the subclasses must all associate to the +:attachment+ name.
  # In order to address this situation, the
  # {Fl::Framework::Attachment::ActiveRecord::Registration::ClassMethods#activerecord_attachment}
  # class method supports the *:_alias* option to alias +:attachment+ to a subclass-specific name.
  # For example, a subclass that stores image files could be defined like this:
  #   class MyImageAttachment < Fl::Framework::Attachment::ActiveRecord::Base
  #     activerecord_attachment :attachment, _type: :image, _alias: :image
  #   end
  # and will respond to both +attachment+ and +image+ to manage the Paperclip attachment.
  #
  # Along the same lines, since the base attribute for the Paperclip attachment is +:attachment+,
  # subclasses will have to have to convert attachment parameter names in their +initializer+ and
  # +update_attributes+ methods. However, this class implements {.initializer} and {#update_attributes}
  # to do that conversion, so that subclasses need to call +super+ in the initializer, and have no need
  # to do anything special in +update_attributes+.
  #
  # === Attributes
  # This class defines the following attributes:
  # - +title+ is a string containing a title for the attachment.
  # - +caption+ is a string containing a caption for the attachment.
  # - +created_at+ is an Integer containing the UNIX creation time.
  # - +updated_at+ is an Integer containing the UNIX modification time.
  # Note that the class does not define an +attachment+ attribute.
  #
  # === Associations
  # This class defines the following associations:
  # - *attachable* is the object that controls the attachment.
  # - *author* is the entity (typically a user) that created the attachment.

  class Base < Fl::Framework::ApplicationRecord
    include Fl::Framework::Attachment::ActiveRecord::Registration
    include Fl::Framework::Attachment::Common

    self.table_name = 'fl_framework_attachments'

    # @!attribute [rw] title
    # The attachment's title.
    # @return [String] Returns the attachment title.

    # @!attribute [rw] caption
    # The attachment's caption.
    # @return [String] Returns the attachment caption.

    # @!attribute [rw] attachment
    # The attachment's Paperclip attachment. Technically, this class does not define this attribute,
    # but all subclasses will, so virtually the attribute is present here.
    # @return [String] Returns the attachment's Paperclip attachment.

    # @!attribute [rw] attachable
    # The association linking to the master object for the attachment.
    #
    # @overload attachable
    #  @return Returns the attachment's attachable object.
    # @overload attachable=(a)
    #  Set the attachable object.
    #  This implementation wraps around the original setter to perform the following operations:
    #  1. call {#will_change_attachable} and return immeditely if the method returns a false value.
    #  2. set the new attachable to _a_.
    #  5. call {#did_change_attachable}.
    #
    #  @param a [Object] The new association.

    belongs_to :attachable, polymorphic: true

    # @!attribute [r] author
    # The entity that created the comment, and therefore owns it.
    # @return [Object] Returns the object that created the comment.

    belongs_to :author, polymorphic: true

    # Initializer.
    # The +attachable+ and +author+ attributes are resolved to an object if passed as a dictionary
    # containing the object class and object id, or if passed as a fingerprint.
    #
    # @param attrs [Hash] A hash of initialization parameters.
    # @option attrs [Object, Hash, String] :author The attachment author. The value is resolved via a call
    #  to {Fl::Framework::Comment::Comment::Helper.author_from_parameter}.
    # @option attrs [Object, Hash, String] :attachable is the attachable object; this can be passed either
    #  as an object, a Hash containing the two keys *:id* and *:type*, or a string containing the object's
    #  fingerprint.
    # @option attrs [Object] :attachment The attachment object, which could be a Paperclip::Attachment,
    #  or a ActionDispatch::Http::UploadedFile. Subclasses may use a different name for the attachment
    #  parameter; the initializer calls calls
    #  {Fl::Framework::Attachment::Common::InstanceMethods#normalize_attachment_attribute} to convert
    #  it to an *:attachment* parameter.
    # @option attrs [String] :title is the title for the attachment. The value may be +nil+.
    # @option attrs [String] :caption is the caption for the attachment. The value may be +nil+.

    def initialize(attrs = {})
      begin
        attrs[:author] = Fl::Framework::Attachment::Helper.author_from_parameter(attrs)
      rescue => exc
        self.errors[:author] << exc.message
      end

      begin
        attrs[:attachable] = Fl::Framework::Attachment::Helper.attachable_from_parameter(attrs)
      rescue => exc
        self.errors[:attachable] << exc.message
      end

      attrs = normalize_attachment_attribute(attrs)

      super(attrs)
    end

    # @!visibility private
    alias _original_update_attributes update_attributes

    # Update attributes.
    # This method wraps the call to the original implementation to convert the class-specific attachment
    # name via {Fl::Framework::Attachment::Common::InstanceMethods#normalize_attachment_attribute}.
    #
    # @param [Hash] attrs The attributes to update.

    def update_attributes(attrs)
      attrs = normalize_attachment_attribute(attrs)
      _original_update_attributes(attrs)
    end

    # Get the attachment type.
    # The default implementation raises an exception to force subclasses to override it.
    #
    # @return [Symbol] Returns a symbol that tags the attachment type.

    def self.attachment_type()
      raise "please implement #{self.name}.attachment_type"
    end

    # Get the attachment type.
    # This method simply calls the class method by the same name.
    #
    # @return [Symbol] Returns a symbol that tags the attachment type.

    def attachment_type()
      self.class.attachment_type
    end

    # @visibility private
    alias _original_attachable= attachable=

    # This is here just so that YARD doesn't mark the attribute writeonly.
    def attachable()
      super()
    end

    def attachable=(a)
      if self.will_change_attachable(self.attachable, a)
        old = self.attachable
        self._original_attachable=(a)
        self.did_change_attachable(old, a)
      end
    end

    # Add the attachment to an attachable object.
    # This method currently simply calls {#attachable=}, but we define an API so that in the future
    # we could add functionality to the operation.
    #
    # @param attachable [Object] The new attachable object.

    def attach_to_object(attachable)
      self.attachable = attachable
    end

    protected

    # The attachable will change.
    # The base implementation simply returns +true+; subclasses can override to add logic to the set operation,
    # including vetoing it.
    #
    # @param old [Object] The old attachable.
    # @param new [Object] The new attachable.
    #
    # @return [Boolean] Return +true+ to proceed with the set, +false+ to veto the operation.

    def will_change_attachable(old, new)
      true
    end

    # The attachable did change.
    # The base implementation is empty; subclasses can override to add logic to the set operation.
    #
    # @param old [Object] The old attachable.
    # @param new [Object] The new attachable.

    def did_change_attachable(old, new)
    end
  end
end
