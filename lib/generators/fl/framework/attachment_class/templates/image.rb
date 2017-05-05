<%= @open_module %>
  # An Active Record attachment that contains an image file.
  #
  # === Attributes
  # This class defines the following properties:
  # - +image+ is a Paperclip attachment used to access the image. See the documentation for Paperclip
  #   at {https://github.com/thoughtbot/paperclip}.
  #   The value is a Paperclip::Attachment.
  #   Note that this attribute is registered as +:attachment+, with alias +:image+.
  #
  # === Associations
  # This class defines no additional associations.

  class <%=@class_name%> < Fl::Framework::Attachment::ActiveRecord::Base
    # @!visibility private
    ATTACHMENT_ALIAS = :image

    # @!visibility private
    ATTACHMENT_TYPE = :fl_framework_image

    # to turn on delayed processing, add the option '_delayed: true'
    activerecord_attachment :attachment, _type: ATTACHMENT_TYPE, _alias: ATTACHMENT_ALIAS
    set_attachment_alias ATTACHMENT_ALIAS
    register_mime_types 'image/*' => :activerecord

    validates_attachment_content_type :attachment, content_type: /\Aimage/
    validates_presence_of :attachment

    # Initializer.
    #
    # @param attrs [Hash] A hash of initialization parameters.
    #  See {Base#initialize} for a description.

    def initialize(attrs = {})
      super(attrs)
    end

    # Get the attachment type.
    #
    # @return [Symbol] Returns +:fl_framework_image+ to indicate that this is an image attachment.

    def self.attachment_type()
      ATTACHMENT_TYPE
    end
  end
<%= @close_module %>
