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
  #
  # The processor also adds watermarks to the thumbnails (but not to the original) if the +watermark+
  # option is defined.

  class Floopnail < Thumbnail
    # @!attribute keep_size
    # The value of the +keep_size+ configuration option.

    attr_accessor :keep_size

    # @!attribute bg_color
    # The value of the +bg_color+ configuration option.

    attr_accessor :bg_color

    # @!attribute watermark
    # The value of the +watermark+ configuration option.

    attr_accessor :watermark

    # @!attribute watermark_opacity
    # The value of the +watermark_opacity+ configuration option.

    attr_accessor :watermark_opacity

    # Initializer.
    #
    # @param file The file to process.
    # @param options [Hash] Options for the processor; see the documentation for Paperclip::Processor for
    #  options handled by the superclass.
    # @option options [Boolean] :keep_size If set, the thumbnail is generated as described in the class
    #  documentation. Defaults to +false+.
    # @option options [String] :bg_color The background color to use when generating a +keep_size+ image.
    #  Defaults to 'xc:transparent'.
    # @option options [String] :watermark The path to a file containing a watermark to tile into the
    #  generated thumbnail. This path is relative to the Rails root. A missing *:watermark* option implies
    #  that the thumbnails will not be watermarked.
    # @option options [String, Number] :watermark_opacity A value between 0 and 100 for the opacity of the
    #  watermark; 0 means transparent, 100 fully opaque. Defaults to 20.
    # @param attachment Not sure what this is; it's in the Paperclip::Thumbnail initializer signature.

    def initialize(file, options = {}, attachment = nil)
      rv = super(file, options, attachment)

      @keep_size = (options.has_key?(:keep_size)) ? options[:keep_size] : false
      @bg_color	= (options.has_key?(:bg_color)) ? options[:bg_color] : ''
      if @bg_color.length < 1
        @bg_color = 'xc:transparent'
      end
      @watermark = options[:watermark]
      @watermark_opacity = (options.has_key?(:watermark_opacity)) ? options[:watermark_opacity] : '20'

      rv
    end

    # Performs the conversion of the file into a thumbnail. Returns the Tempfile that contains the new image.
    #
    # This implementation sets the +source_file_options+ and +convert_options+ values as needed for the
    # thumbnail, and then calls the superclass implementation.
    #
    # @return Returns a Tempfile object containing the generated thumbnail.

    def make()
      if @keep_size
        @source_file_options = [ "-size", "#{@target_geometry.width.to_i}x#{@target_geometry.height.to_i}", "#{@bg_color}" ]
        @convert_options = [ "-gravity", "center", "-composite" ]
      end

      tn = super
      if @watermark.is_a?(String)
        # There is a watermark, which is expected to be rooted in Rails.root.

        p = File.join(Rails.root, @watermark)
        if File.exist?(p)
          begin
            filename = [ "#{@basename}_wm", @format ? ".#{@format}" : "" ].join
            dst = TempfileFactory.new.generate(filename)

            parameters = [ '-dissolve', @watermark_opacity.to_s, '-tile' ]
            parameters << ':watermark'
            parameters << ':source'
            parameters << ':dest'

            parameters = parameters.flatten.compact.join(" ").strip.squeeze(" ")

            success = composite(parameters, {
                                  :watermark => p,
                                  :source => tn.path,
                                  :dest => File.expand_path(dst.path)
                                })
          rescue Cocaine::ExitStatusError => e
            raise Paperclip::Error, "There was an error processing the thumbnail for #{@basename}" if @whiny
          rescue Cocaine::CommandNotFoundError => e
            raise Paperclip::Errors::CommandNotFoundError.new("Could not run the `convert` command. Please install ImageMagick.")
          end

          # The new return value is dst, and we can close tn

          tn.close
          tn = dst
        else
          Rails.logger.warn("Floopnail cannot find watermark file #{@watermark}")
        end
      end

      tn
    end

    # Runs the +composite+ command.
    # See Paperclip.run for details on the available options.
    #
    # @param arguments [String] The arguments to pass to the +composite+ command.
    # @param local_options [Hash] Passed to Paperclip.run.
    
    def composite(arguments = "", local_options = {})
      Paperclip.run('composite', arguments, local_options)
    end

    protected

    private
  end
end
