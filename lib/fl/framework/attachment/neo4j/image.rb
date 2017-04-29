require 'fl/framework/rel/attachment/imageattached_to'

module Fl::Framework::Attachment::Neo4j
  # An attachment that contains an image file.
  # Image attachments are associated via the +ATTACHED_TO+ relationship like all attachments, but they
  # also add the +IMAGE_ATTACHED_TO+ relationship (in the code with
  # {Fl::Framework::Rel::Attachment::ImageAttachedTo}).
  # This makes it possible to query for image attachments without examining the +attachment_type+ node
  # property of the +ATTACHED_TO+ relationship.
  #
  # === Properties
  # This class defines the following properties:
  # - +image+ is a Paperclip attachment used to access the image. See the documentation for Paperclip
  #   at {https://github.com/thoughtbot/paperclip}.
  #   The value is a Paperclip::Attachment.
  #
  # === Associations
  # This class defines no additional associations.

  class Image < Base
    # @!visibility private
    DEFAULT_HASH_KEYS = [ :image ]

    attachment :image, _type: :image, _delayed: true, default_style: :medium
    validates_attachment_content_type :image, content_type: /\Aimage/
    validates_presence_of :image

    before_destroy :_adjust_image_relationships
    after_create :_create_initial_image_association

    # Initializer.
    #
    # @param attrs [Hash] A hash of initialization parameters.
    # @option attrs [ActionDispatch::Http::UploadedFile] :image is the upload file data containing the image.

    def initialize(attrs = {})
      super(attrs)
    end

    # Get the attachment type.
    #
    # @return [Symbol] Returns +:image+ to indicate that this is an image attachment.

    def self.attachment_type()
      :image
    end

    protected

    # The master did change.
    #
    # @param old [Object] The old master.
    # @param new [Object] The new master.

    def did_change_master(old, new)
      if self.persisted?
# EMIL we need to twiddle the main image association for old and new
        _delete_image_relationships()
        _create_image_association_for(new)
      end
    end

    # Given a verbosity level, return predefined hash options to use.
    #
    # @param actor [Object] The actor for which we are building the hash representation.
    # @param verbosity [Symbol] The verbosity level; see #to_hash.
    # @param opts [Hash] The options that were passed to #to_hash.
    #
    # @return [Hash] Returns a hash containing default options for +verbosity+.

    def to_hash_options_for_verbosity(actor, verbosity, opts)
      if (verbosity == :minimal) || (verbosity == :standard)
        rv = super(actor, verbosity, opts)
        rv[:include] = if rv.has_key?(:include)
                         rv[:include] | DEFAULT_HASH_KEYS
                       else
                         DEFAULT_HASH_KEYS
                       end
      elsif (verbosity == :verbose) || (verbosity == :complete)
        rv = super(verbosity, opts)
        rv[:include] = if rv.has_key?(:include)
                         rv[:include] | DEFAULT_HASH_KEYS | []
                       else
                         DEFAULT_HASH_KEYS | []
                       end
      else
        rv = {}
      end

      rv
    end

    # Return the default list of operations for which to check permissions.
    # This implementation returns the array <tt>[ :read, :write, :destroy ]</tt>; we add :read because
    # comments can be picked up from the controller independently of the commentable (the actions 
    # +:show+, +:edit+, +:update+, and +:destroy+ are not nested in the commentable).
    #
    # @return [Array<Symbol>] Returns an array of Symbol values that list the operations for which
    #  to obtain permissions.

    def to_hash_operations_list
      super
    end

    # Build a Hash representation of the image attachment.
    #
    # @param actor The actor for which we are building the hash representation.
    # @param keys [Array<Symbol>] The keys to place in the hash.
    # @param opts [Hash] Options for the method.
    #
    # @return [Hash] Returns a Hash containing the image attachment's representation.
    #  In addition to the keys returned by {Fl::Framework::Attachment::Base#to_hash_local}, the following
    #  keys are added:
    #  - *:image* contains a hash with the following keys:
    #    - *:urls* is a hash where the keys are style names, and the values the corresponding URLs.
    #    - *:content_type* is a string containing the MIME type for the image.
    #    - *:file_name* is a string containing the original file name for the image.
    #    - *:updated_at* is a timestamp containing the time the image was lat modified
    #    - *:processing* is the boolean value @c true or @c false, and it indicates whether or not
    #      the image is still being processed.
    #    Not all of these keys may be present, but :urls is always present.

    def to_hash_local(actor, keys, opts = {})
      rv = super(actor, keys, opts)
      keys.each do |k|
        case k
        when :image
          rv[k] = to_hash_image_attachment(self.image, opts[:image_sizes])
          if Floop.config.support_old_attachment
            rv[:image_content_type] = self.image.content_type
            rv[:image_file_name] = self.image.original_filename
            img = rv[k]
            img[:urls].each { |u_k, u_v| img[u_k] = u_v }
          end
        end
      end

      rv
    end

    private

    def _delete_image_relationships()
      self.query_as(:a).match('(a)-[r:IMAGE_ATTACHED_TO|MAIN_IMAGE_ATTACHMENT_FOR]->(m)').delete(:r).exec
    end

    def _create_image_association_for(m)
      rel = Fl::Framework::Rel::Attachment::ImageAttachedTo.new(from_node: self, to_node: m)
      rel.save!
    end

    def _create_initial_image_association()
      _create_image_association_for(@_master)
    end

    # Destroy callback to clear the +IMAGE_ATTACHED_TO+ relationship.
    # If this relationship is not removed, deletion of the node will fail.
    # Also we should adjust the main_image_attachment for the master if this was the main image,
    # but that is a bit difficult to do because we don't really know what associations the master
    # is using. Therefore, we leave that for the UI.

    def _adjust_image_relationships()
      _delete_image_relationships()
    end
  end
end
