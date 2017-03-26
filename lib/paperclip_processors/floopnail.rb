# This is the root module for Paperclip code.
# Third party code like processors also need to reside within this module.

module Paperclip
  # Handles thumbnailing images that are uploaded.
  # This version of the original Paperclip::Thumbnail processor resizes the image as Paperclip::Thumbnail
  # does. However, if the +keep_size+ option is defined, it composes the resized image onto a background
  # at the resize size as given.

  class Floopnail < Processor
    attr_accessor :current_geometry, :target_geometry, :format, :whiny, :convert_options, :source_file_options

    # List of formats that we need to preserve animation
    ANIMATED_FORMATS = %w(gif)

    # Creates a Thumbnail object set to work on a given file.
    # It will attempt to transform the image into one defined by +target_geometry+
    # which is a "WxH"-style string. +format+ will be inferred from the +file+
    # unless specified. Thumbnail creation will raise no errors unless
    # +whiny+ is true (which it is, by default. If +convert_options+ is
    # set, the options will be appended to the convert command upon image conversion.
    #
    # If +keep_size+ is set, the file will be processed differently.
    # The image is resized as usual, but then it is composed onto a background image at the resized size;
    # the background color can be provided with the +bg_color+ option.
    # The resized image is centered on the background (using -gravity center). This behavior results in
    # images of a given size, containing resized images that may or may not cover the size, but whose
    # aspect ratio may have been kept (if the +geometry+ option sets it up that way).
    #
    # @param file The file to process.
    # @param options [Hash] Options for the processor.
    # @option options [String] :geometry the desired width and height of the thumbnail (required)
    # @option options :file_geometry_parser an object with a method named +from_file+ that takes an image
    #  file and produces its geometry and a +transformation_to+. Defaults to Paperclip::Geometry.
    # @option options :string_geometry_parser an object with a method named +parse+ that takes a string and
    #  produces an object with +width+, +height+, and +to_s+ accessors. Defaults to Paperclip::Geometry.
    # @option options :source_file_options flags passed to the +convert+ command that influence how the source
    #  file is read
    # @option options :convert_options flags passed to the +convert+ command that influence how the image is
    #   processed
    # @option options [Boolean] :keep_size controls the resizing behavior, as described in the method intro.
    #  Defaults to +false+.
    # @option options [String] :bg_color a string containing the representation of the filler color used
    #  when *:keep_size+* is +true+. Defaults to +xc:transparent+.
    # @option options [Boolean] :whiny whether to raise an error when processing fails. Defaults to +true+.
    # @option options [String] :format the desired filename extension.
    # @option options [Boolean] :animated whether to merge all the layers in the image. Defaults to +true.+
    # @param attachment Not used.

    def initialize(file, options = {}, attachment = nil)
      super

      geometry             = options[:geometry] # this is not an option
      @file                = file
      @crop                = geometry[-1,1] == '#'
      @target_geometry     = (options[:string_geometry_parser] || Geometry).parse(geometry)
      @current_geometry    = (options[:file_geometry_parser] || Geometry).from_file(@file)
      @source_file_options = options[:source_file_options]
      @convert_options     = options[:convert_options]
      @whiny               = options[:whiny].nil? ? true : options[:whiny]
      @format              = options[:format]
      @animated            = options[:animated].nil? ? true : options[:animated]

      @source_file_options = @source_file_options.split(/\s+/) if @source_file_options.respond_to?(:split)
      @convert_options     = @convert_options.split(/\s+/)     if @convert_options.respond_to?(:split)

      @current_format      = File.extname(@file.path)
      @basename            = File.basename(@file.path, @current_format)

      @keep_size	   = (options.has_key?(:keep_size)) ? options[:keep_size] : false
      @bg_color		   = (options.has_key?(:bg_color)) ? options[:bg_color] : ''
      if @bg_color.length < 1
        @bg_color = 'xc:transparent'
      end
    end

    # Returns true if the +target_geometry+ is meant to crop.
    def crop?
      @crop
    end

    # Returns true if the image is meant to make use of additional convert options.
    def convert_options?
      !@convert_options.nil? && !@convert_options.empty?
    end

    # Performs the conversion of the +file+ into a thumbnail. Returns the Tempfile
    # that contains the new image.
    def make
      src = @file
      dst = Tempfile.new([@basename, @format ? ".#{@format}" : @current_format])
      dst.binmode

      begin
        parameters = make_params.flatten.compact.join(" ").strip.squeeze(" ")

        success = Paperclip.run("convert", parameters, :source => "#{File.expand_path(src.path)}#{'[0]' unless animated?}", :dest => File.expand_path(dst.path))
      rescue Cocaine::ExitStatusError => e
        raise PaperclipError, "There was an error processing the thumbnail for #{@basename}" if @whiny
      rescue Cocaine::CommandNotFoundError => e
        raise Paperclip::CommandNotFoundError.new("Could not run the `convert` command. Please install ImageMagick.")
      end

      dst
    end

    # Returns the command ImageMagick's +convert+ needs to transform the image
    # into the thumbnail.
    def transformation_command
      scale, crop = @current_geometry.transformation_to(@target_geometry, crop?)
      trans = []
      trans << "-coalesce" if animated?
      trans << "-resize" << %["#{scale}"] unless scale.nil? || scale.empty?
      trans << "-crop" << %["#{crop}"] << "+repage" if crop
      trans
    end

    protected

    # Return true if the format is animated
    def animated?
      @animated && ANIMATED_FORMATS.include?(@current_format[1..-1]) && (ANIMATED_FORMATS.include?(@format.to_s) || @format.blank?)
    end

    private

    def make_params
      parameters = []
      parameters << source_file_options
      if @keep_size
        parameters << "-size" << "#{@target_geometry.width.to_i}x#{@target_geometry.height.to_i}" << "#{@bg_color}"
      end
      parameters << ":source"
      parameters << transformation_command
      parameters << convert_options
      if @keep_size
        parameters << "-gravity" << "center" << "-composite"
      end
      parameters << ":dest"

      parameters
    end
  end
end
