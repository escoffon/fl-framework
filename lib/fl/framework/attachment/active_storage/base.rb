module Fl::Framework::Attachment::ActiveStorage
  # Helper for ActiveStorage.

  module Base
    # Methods to be registered as class methods of the including module/class.

    module ClassMethods
      # @!method attachment_options(aname = nil)
      #   Get the attachment style options registered with the class.
      #   If *aname* is `nil`, the method returns the attachment options from all attachments.
      #   Otherwise, it returns the options for the requested attachment.
      #   @param aname [String,Symbol,ActiveStorage::Attached::One,nil] The name of the attachment,
      #    or all attachments if `nil`. If the value is a `ActiveStorage::Attached::One`, the attachment
      #    name is derived from its `name` property.
      #   @return [Hash] Returns a hash as described above.
      #    If *aname* is `nil`, keys are attachment names and values are hashes containing the options
      #    that were passed to `has_one_attached` for that attachment.
      #    If *aname* is not `nil`, the hash contains the options that were passed to `has_one_attached`.
        
      def attachment_options(aname = nil)
      end

      # @!method attachment_styles(aname = nil)
      #   Get the attachment styles registered with the class.
      #   If *aname* is `nil`, the method returns the variant styles from all attachments.
      #   Otherwise, it returns the variant styles for the requested attachment.
      #   @param aname [String,Symbol,ActiveStorage::Attached::One,nil] The name of the attachment,
      #    or all attachments if `nil`. If the value is a `ActiveStorage::Attached::One`, the attachment
      #    name is derived from its `name` property.
      #   @return [Hash] Returns a hash as described above.
      #    If *aname* is `nil`, keys are attachment names and values are hashes containing the styles
      #    associated with that attachment.
      #    If *aname* is not `nil`, keys are style names and values are hashes containing the variant
      #    options; if *aname* is not a registered attachment, an empty hash is returned.
        
      def attachment_styles(aname = nil)
      end

      # @!method attachment_style(aname, sname)
      #   Get a style for an attachment.
      #   @param aname [String,Symbol] The name of the attachment.
      #   @param sname [String,Symbol] The name of the style to look up.
      #   @return [Hash] Returns a hash containing the requested style; if no such style is present,
      #    returns an empty hash.
        
      def attachment_style(aname, sname)
      end
    end

    # The methods in this module are installed as instance method of the including class.

    module InstanceMethods
      # Get the variant for an attachment based on a style name.
      # If *sname* is a string or a symbol, the method looks it up in the styles that were registered for
      # attachment *aname*, and generates a variant based on those processing parameters.
      # Otherwise, it generates the variant using *sname* as the processing parameters.
      #
      # @param aname [String,Symbol,ActiveStorage::Attached::One] The name of the attachment, or the
      #  attachment proxy.
      # @param sname [String,Symbol,Hash] The name of the style to look up, or a hash of processing
      #  parameters.
      #
      # @return [Hash] Returns a hash containing the variant attributes for the given style;
      #  if *sname* is not a registered name, returns an empty hash.
      
      def attachment_variant(aname, sname)
        a = (aname.is_a?(ActiveStorage::Attached::One)) ? aname : send(aname)
        pp = (sname.is_a?(Symbol) || sname.is_a?(String)) ? self.class.attachment_style(aname, sname) : sname
        a.variant(pp)
      end

      # Get the URL path component for the blob (the original file).
      #
      # @param aname [String,Symbol,ActiveStorage::Attached::One] The name of the attachment, or the
      #  attachment proxy.
      #
      # @return [String] Returns a string containing the path component of the URL to the blob.

      def attachment_blob_path(aname)
        a = (aname.is_a?(ActiveStorage::Attached::One)) ? aname : send(aname)
        Rails.application.routes.url_helpers.rails_blob_path(a, only_path: true)
      end

      # Get the URL for the blob (the original file).
      #
      # @param aname [String,Symbol,ActiveStorage::Attached::One] The name of the attachment, or the
      #  attachment proxy.
      # @param opts [Hash] Options for the method; a common option is **:host**, to specify the host
      #  name (which may include the scheme component `http` or `https`).
      #
      # @return [String] Returns a string containing the URL to the blob.

      def attachment_blob_url(aname, *opts)
        a = (aname.is_a?(ActiveStorage::Attached::One)) ? aname : send(aname)
        Rails.application.routes.url_helpers.rails_blob_url(a, *opts)
      end

      # Get the URL path component for a given variant, by style.
      # If *sname* is a string or a symbol, the method looks it up in the styles that were registered for
      # attachment *aname*, and generates the variant path based on those processing parameters.
      # Otherwise, it generates the variant path using *sname* as the processing parameters.
      #
      # @param aname [String,Symbol] The name of the attachment.
      # @param sname [String,Symbol,Hash,ActiveStorage::Variant] The name of the style to look up, a hash
      #  of variant parameters, or a variant.
      #
      # @return [String] Returns a string containing the path component of the variant corresponding
      #  to style *sname*.

      def attachment_variant_path(aname, sname)
        v = (sname.is_a?(ActiveStorage::Variant)) ? sname : attachment_variant(aname, sname)
        Rails.application.routes.url_helpers.rails_blob_representation_path(v.blob.signed_id,
                                                                            v.variation.key,
                                                                            v.blob.filename)
      end

      # Get the URL to a given variant, by style.
      # If *sname* is a string or a symbol, the method looks it up in the styles that were registered for
      # attachment *aname*, and generates the variant URL based on those processing parameters.
      # Otherwise, it generates the variant URL using *sname* as the processing parameters.
      #
      # @param aname [String,Symbol] The name of the attachment.
      # @param sname [String,Symbol,Hash,ActiveStorage::Variant] The name of the style to look up, a hash
      #  of variant parameters, or a variant.
      # @param opts [Hash] Options for the method; a common option is **:host**, to specify the host
      #  name (which may include the scheme component `http` or `https`).
      #
      # @return [String] Returns a string containing the URL of the variant corresponding
      #  to style *sname*.
          
      def attachment_variant_url(aname, sname, *opts)
        v = (sname.is_a?(ActiveStorage::Variant)) ? sname : attachment_variant(aname, sname)
        Rails.application.routes.url_helpers.rails_blob_representation_url(v.blob.signed_id,
                                                                           v.variation.key,
                                                                           v.blob.filename,
                                                                           *opts)
      end
    end

    # Perform actions when the module is included.
    #
    # - Injects the class methods.
    # - Injects the instance methods.
    
    def self.included(base)
      base.instance_eval do
        alias has_one_attached_orig has_one_attached
      end
      
      # This is done explicitly below, to get the scope right.
      # The ClassMethods are actually there for doumentation purposes
      # base.extend ClassMethods

      base.instance_eval do
      end

      base.class_eval do
        @@attachment_options = { }
        @@attachment_styles = { }
        
        def self.attachment_options(aname = nil)
          return @@attachment_options if aname.nil?

          ak = case aname
               when ActiveStorage::Attached::One
                 aname.name.to_sym
               when String
                 aname.to_sym
               when Symbol
                 aname
               else
                 aname
               end
          @@attachment_options[ak] || { }
        end
        
        def self.attachment_styles(aname = nil)
          return @@attachment_styles if aname.nil?

          ak = case aname
               when ActiveStorage::Attached::One
                 aname.name.to_sym
               when String
                 aname.to_sym
               when Symbol
                 aname
               else
                 aname
               end
          s = @@attachment_styles[ak]
          case s
          when Hash
            s
          when Proc
            # if :styles was registered as a proc, AND if aname is an attachment proxy, then we can
            # attempt to resolve the styles based on the proc.

            if aname.is_a?(ActiveStorage::Attached::One)
              s.call(aname, attachment_options(aname))
            else
              { }
            end
          else
            { }
          end
        end

        def self.attachment_style(aname, sname)
          attachment_styles(aname)[sname.to_sym] || { }
        end
        
        include InstanceMethods
      end
    end
  end
end
