# This is the root module for Paperclip code.
# Third party code like processors also need to reside within this module.

module Paperclip
  # Handles thumbnailing images that are uploaded.
  # This subclass of the Paperclip::Thumbnail processor resizes the image as Paperclip::Thumbnail
  # does.
  #
  # If the +keep_size+ option is set, however, the image will be processed differently.
  # The image is resized as usual, but then it is composed onto a background image at the resized size;
  # the background color can be provided with the +bg_color+ option.
  # The resized image is centered on the background (using -gravity center). This behavior results in
  # images of a given size, containing resized images that may or may not cover the size, but whose
  # aspect ratio may have been kept (if the +geometry+ option sets it up that way).
  #
  # Note also that, if +keep_size+ is +true+, then the value of the +source_file_options+ option is
  # ignored, since the processor will set up its own specialized version.

  class Floopnail < Thumbnail
    # @!attribute keep_size
    # The value of the +keep_size+ configuration option.

    attr_accessor :keep_size

    # @!attribute bg_color
    # The value of the +bg_color+ configuration option.

    attr_accessor :bg_color

    # Initializer.
    #
    # @param file The file to process.
    # @param options [Hash] Options for the processor; see the documentation for Paperclip::Processor for
    #  options handled by the superclass.
    # @option options [Boolean] :keep_size If set, the thumbnail is generated as described in the class
    #  documentation. Defaults to +false+.
    # @option options [String] :bg_color The background color to use when generating a +keep_size+ image.
    #  Defaults to 'xc:transparent'.
    # @param attachment Not sure what this is; it's in the Paperclip::Thumbnail initializer signature.

    def initialize(file, options = {}, attachment = nil)
      super(file, options, attachment)

      @keep_size	   = (options.has_key?(:keep_size)) ? options[:keep_size] : false
      @bg_color		   = (options.has_key?(:bg_color)) ? options[:bg_color] : ''
      if @bg_color.length < 1
        @bg_color = 'xc:transparent'
      end
    end

    # Performs the conversion of the file into a thumbnail. Returns the Tempfile that contains the new image.
    #
    # This implementation sets the +source_file_options+ and +convert_options+ values as needed for the
    # thumbnail, and then calls the superclass implementation.

    def make()
      if @keep_size
        @source_file_options = [ "-size", "#{@target_geometry.width.to_i}x#{@target_geometry.height.to_i}", "#{@bg_color}" ]
        @convert_options = [ "-gravity", "center", "-composite" ]
      end

      super
    end

    protected

    private
  end
end
