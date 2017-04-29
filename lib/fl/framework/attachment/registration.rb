module Fl::Framework::Attachment
  # A class to manage mappings from MIME types to attachment object subclasses.
  # Instances of this class manage a mapping from MIME types to the attachment object subclass used to
  # store the attachments in the database.
  # The map stores class implementations for various ORMs as well as for various MIME types; it also
  # understands "globbed" MIME types like +image/*+.

  class ClassRegistry
    # @!visibility private
    @@_registry = nil

    # The identifier for Active Record objects.

    ORM_ACTIVE_RECORD = :activerecord

    # The identifier for Neo4j objects.

    ORM_NEO4J = :neo4j

    # Get the global class registry.
    # This method returns a global class registry, which is typically what clients use.
    #
    # @return [Fl::Framework::Attachment::ClassRegistry] Returns the singleton instance of the registry.

    def self.registry()
      @@_registry = self.new unless @@_registry
      @@_registry
    end

    # Initializer.
    #
    # @param [Hash] map An initial value for the map. Keys are MIME types or globbed types, values
    #  are either class objects, or hashes if multiple ORMs are supported.
    #
    # @example Initialization with two ORMs
    #  r = Fl::Framework::Attachment::ClassRegistry.new({
    #        'image/*' => {
    #            activerecord: Fl::Framework::Attachment::ActiveRecord::Image,
    #            neo4j: Fl::Framework::Attachment::Neo4j::Image
    #        }
    #      })

    def initialize(map = {})
      @map = (map.is_a?(Hash)) ? map : {}
    end

    # Register a MIME type.
    #
    # @param [String] mime The MIME type; can be a globbed type like +image/*+.
    # @param [Class] klass The class to register.
    # @param [Symbol] orm The ORM to use.

    def register(mime, klass, orm = ORM_ACTIVERECORD)
      k = @map[mime]
      if k
        k[orm] = klass
      else
        @map[mime] = { orm => klass }
      end
    end

    # Given a MIME type, return the corresponding class object if one is registered.
    # The method first tries to match _mime_ exactly; if no match is found, it then tries the
    # globbed version, and finally a "global glob" (+*/*+).
    #
    # @param [String] mime The MIME type to look up.
    # @param [Symbol] orm The ORM to use.
    #
    # @return [Class, nil] Returns a class object on a match, +nil+ otherwise.

    def lookup(mime, orm = ORM_ACTIVE_RECORD)
      k = _lookup(mime, orm)
      return k if k.is_a?(Class)

      m = mime.split('/').first + '/*'
      k = _lookup(m, orm)
      return k if k.is_a?(Class)

      m = '*/*'
      k = _lookup(m, orm)
      (k.is_a?(Class)) ? k : nil
    end

    private

    def _lookup(mime, orm)
      h = @map[mime]
      if h.is_a?(Hash) && h.has_key?(orm)
        return h[orm]
      end

      nil
    end
  end

  # Mixin module that defines the generic registration API for attachments.
  # The core of the registration API is implemented in ORM-specific modules, since it uses ORM-specific
  # implementations of the Paperclip gem.
  # However, the ORM-independent API is implemented here.
  #
  # These registration methods are used to set up attachment suclasses:
  # - {ClassMethods#alias_attachment} defines an alternate (and subclass-specific) name for the
  #   Paperclip attachment attribute.
  # - {ClassMethods#register_mime_types} registers the MIME types that a subclass can handle.
  #
  # @example Class definition of a image class
  #  class Image < Fl::Framework::Attachment::ActiveRecord::Base
  #    activerecord_attachment :attachment, _type: :fl_framework_image, _alias: :image
  #    set_attachment_alias :image
  #    register_mime_types 'image/*' => :activerecord
  #  end

  module Registration
    # The methods in this module will be installed as class methods of the including class.

    module ClassMethods
      # Create an alias for an attachment.
      # This class method creates aliases for the Paperclip attachment methods; it is used to access a
      # Paperclip attachment with a different name from the one it was used at registration time.
      # It is therefore equivalent to the *:_alias* option in
      # {Fl::Framework::Attachment::ActiveRecord::ClassMethods#activerecord_attachment} and
      # {Fl::Framework::Attachment::Neo4j::ClassMethods#neo4j_attachment}.
      #
      # @param new_name [Symbol] The attachment's new name.
      # @param old_name [Symbol] The attachment's original name; if +nil+, +:attachment+ is used.
      #
      # @todo Move +alias_attachment+ to a common module.

      def alias_attachment(new_name, old_name = nil)
        if new_name.is_a?(Symbol)
          old_name = (old_name.is_a?(Symbol)) ? old_name : :attachment

          re = Regexp.new("#{old_name}")
          sn = old_name.to_s
          sa = new_name.to_s
          (self.instance_methods.select { |m| m =~ re }).each do |m|
            ms = m.to_s
            unless ms[0] == '_'
              # We alias anything that starts with the original attachment name; the important ones
              # are <name>, <name>=, and <name>?

              ma = ms.sub(sn, sa).to_sym
              self.class_eval("alias #{ma} #{m}")
            end
          end
        end
      end

      # Register MIME types for an attachment subclass.
      #
      # @param [Hash] types A hash of MIME types and ORMs. The keys are MIME types, and values are
      #  ORM symbols, or arrays or ORM symbols.

      def register_mime_types(types)
        cr = Fl::Framework::Attachment::ClassRegistry.registry

        types.each do |tk, tv|
          av = (tv.is_a?(Array)) ? tv : [ tv ]
          av.each do |orm|
            cr.register(tk, self, orm)
          end
        end
      end
    end

    # The methods in this module are installed as instance method of the including class.

    module InstanceMethods
    end

    # Perform actions when the module is included.
    # - Injects the class methods and instance methods.
    #
    # @param [Module] base The module or class that included this module.

    def self.included(base)
      base.extend ClassMethods

      base.instance_eval do
      end

      base.class_eval do
        include InstanceMethods
      end
    end
  end
end
