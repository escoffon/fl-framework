module Fl::Framework::Attachment::ActiveStorage
  # Helper for ActiveStorage.
  # If this module is included, wrappers for the module helpers are insstalled as instance methods
  # of the including class. For example, an instance method called `to_hash_attachment_styles`
  # is defined that wraps around a call to {.to_hash_attachment_styles}.
  
  module Helper
    # Expand the *styles* option for an ActiveStorage hash representation.
    # This method expands and filters the variant styles as appropriate for the given attachment.
    # Any styles not supported by the attachment are filtered out, except that `:all`
    # is converted to all the supported styles.
    #
    # @param attachment [ActiveStorage::Attached::One] The attachment proxy; this is the value of the
    #  attachment attribute registered with `has_one_attached`.
    # @param styles [Array, String, Symbol] The list of styles to return.
    #  A string value is a comma-separated list of style names.
    #  Each element of the array value is either a style name, or a hash containing processing parameters
    #  for a variant.
    #  The symbol `:all` indicates that all supported styles should be returned.
    #
    # @return [Array<Symbol,Hash>] Returns an array where each element is either the name of a valid
    #  style, or a hash containing variant parameters.

    def self.to_hash_attachment_styles(attachment, styles = :all)
      known_styles = attachment.record.class.attachment_styles(attachment.name)
      sl = case styles
           when String
             styles.split(/\s*,\s*/).map { |sn| sn.to_sym }
           when Array
             styles.reduce([ ]) do |acc, sn|
               if sn.is_a?(Symbol)
                 acc.push(sn)
               elsif sn.is_a?(String)
                 acc.push(sn.to_sym)
               elsif sn.is_a?(Hash)
                 acc.push(sn)
               end
               acc
             end
           when :all
             known_styles.keys
           else
             [ ]
           end
      
      rv = sl.reduce([ ]) do |acc, sn|
        if sn.is_a?(Symbol)
          acc.push(sn) if known_styles.has_key?(sn)
        else
          acc.push(sn)
        end
        acc
      end
      
      # :original is always returned, and it is the blob

      rv.push(:original)

      rv
    end

    # Generate a `to_hash` representation of an attachment.
    # This method generates a representation for an ActiveStorage single attachment (one that was
    # defined via the `has_one_attached` directive).
    #
    # @param attachment [ActiveStorage::Attached::One] The attachment proxy; this is the value of the
    #  attachment attribute registered with `has_one_attached`.
    # @param styles [Array, String, Symbol] The list of styles to return.
    #  A string value is a comma-separated list of style names.
    #  Each element of the array value is either a style name, or a hash containing processing parameters
    #  for a variant.
    #  The symbol `:all` indicates that all supported styles should be returned.
    #
    # @return [Hash,nil] If *attachment* is not currently attached, returns `nil`.
    #  Otherwise, returns a hash containing the following keys:
    #
    #  - **:type** is a string containing the (virtual) class name `ActiveStorage::Attachment`.
    #  - **:urls** is an array of hashes, where each hash contains two keys: **:style** is the style
    #    name or hash, **:url** the corresponding URL.
    #    The `:original` style contains the URL to the original file (the *blob* URL in ActiveStorage
    #    parlance).
    #  - **:content_type** is a string containing the MIME type for the original.
    #  - **:original_file_name** is a string containing the original file name for the attachment.
    #  - **:original_byte_size** is a string containing the original byte size for the attachment.
    #  - **:updated_at** is a timestamp containing the time the image was last modified.
    #
    #  Not all of these keys may be present, but +:urls+ is always present.

    def self.to_hash_attachment_variants(attachment, styles = :all)
      return nil unless attachment.attached?
      
      record = attachment.record
      aname = attachment.name.to_sym
      blob = attachment.record.send("#{aname}_blob")
      
      urls = to_hash_attachment_styles(attachment, styles).reduce([ ]) do |acc, s|
        if s == :original
          acc << {
            style: s,
            url: record.attachment_blob_path(aname)
          }
        else
          acc << {
            style: s,
            url: record.attachment_variant_path(aname, s)
          }
        end

        acc
      end

      h = {
        type: 'ActiveStorage::Attachment',
        urls: urls,
        content_type: attachment.content_type,
        original_filename: attachment.filename.sanitized,
        original_byte_size: blob.byte_size
      }
      
      [ :created_at, :updated_at ].each do |k|
        if blob.respond_to?(k)
          tz = ActiveSupport::TimeZone.new('UTC')
          h[k] = tz.at(blob.send(k))
        end
      end

      h
    end

    # Perform actions when the module is included.
    #
    # - Registers instance methods with the same name and functionality as the module helper methods.
    
    def self.included(base)
      base.class_eval do
        def to_hash_attachment_styles(attachment, styles = :all)
          Fl::Framework::Attachment::ActiveStorage::Helper.to_hash_attachment_styles(attachment, styles)
        end

        def to_hash_attachment_variants(attachment, styles = :all)
          Fl::Framework::Attachment::ActiveStorage::Helper.to_hash_attachment_variants(attachment, styles)
        end
      end
    end
  end
end
