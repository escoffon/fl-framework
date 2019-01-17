require 'fl/framework/access/access'
if defined?(ActiveRecord)
  require 'fl/framework/attachment/active_record/base'
end
if defined?(Neo4j)
  require 'fl/framework/neo4j/association_proxy_cache'
  require 'fl/rel/attachment/attached_to'
end

module Fl::Framework::Attachment
  # A registry of MIME types that are allowed by an association.
  # Instances of this class maintain a list of MIME types for file content that can be
  # added to an association. An instance of the registry is automatically installed as an instance
  # variable of the association by the {Attachable::ClassMethods#has_attachments} directive.

  class TypeRegistry
    # Initializers.
    #
    # @param cfg [Hash] A hash containing configuration parameters.
    #  Note that, if neither *:only* nor *:except* are defined, all classes are allowed.
    # @option cfg [String, Array<String>] :only A MIME type, or an array of MIME types that define the list of
    #  content types that can be added to an association. This option is a whitelist of attachment types that
    #  are allowed by an association. Globbed MIME types (+image/*+) are also allowed.
    # @option cfg [String, Array<String>] :except A MIME type, or an array of MIME types that define the list
    #  ofcontent types that can *not* be added to an association. This option is a blacklist of attachment
    #  types that are not allowed by an association.
    #  If a class is listed in both *:except* and *:only*, it is forbidden (*:except* has higher priority
    #  than *:only*). Globbed MIME types (+image/*+) are also allowed.

    def initialize(cfg = {})
      @only = normalize_list(cfg[:only])
      @except = normalize_list(cfg[:except])
    end

    # Check if a content type can be added to the attributes.
    # The permission algorithm is:
    #
    # 1. See if *type* is in the whitelist, including by globbed types. For example, if *type*
    #    is +image/png+, we look up +image/png+, +image/*+, and +*/*+.
    # 2. If not in the whitelist, it is not allowed.
    # 3. Check the blacklist now, using the same matching algorithm.
    # 4. If in the blacklist, it is not allowed.
    # 5. If we make it here, it is allowed.
    #
    # @param [String] type A MIME type.
    #
    # @return [Boolean] Returns `true` if *type* can be added, `false` if not.
    
    def allow?(type)
      found = (@only.nil?) ? true : lookup(type, @only)
      return false unless found

      found = (@except.nil?) ? true : lookup(type, @except)
      return false if found

      true
    end

    private

    def normalize_list(l)
      return nil if l.nil?

      l = [ l ] unless l.is_a?(Array)
      l.select { |t| t.is_a?(String) }
    end

    def lookup(type, list)
      return true if list.include?(type)

      t = type.split('/').first + '/*'
      return true if list.include?(t)

      return true if list.include?('*/*')

      false
    end
  end

  # Extension module for use by objects that need to implement attachment management.
  # This module defines common functionality for all model classes that use attachments; these objects are
  # accessed as the *attachable* from the attachment objects.
  #
  # Note that inclusion of this module is not enough to turn on attachment management: the class method
  # {ClassMethods#has_attachments} must be called to indicate that this class
  # supports attachments; for example, for Neo4j:
  #
  # ```
  # class MyClass
  #   include Neo4j::ActiveNode
  #   include Fl::Framework::Attachment::Neo4j::Attachable
  #
  #   has_attachments orm: :neo4j
  # end
  # ```
  # and for Active Record:
  #
  # ```
  # class MyClass < ApplicationRecord
  #   include Fl::Framework::Attachment::ActiveRecord::Attachable
  #
  #   has_attachments only: [ Fl::Framework::Attachment::ActiveRecord::Image, MyAttachment ]
  # end
  # ```
  # (`:activerecord` is the default ORM.)
  # The reason we do this is that the {ClassMethods#has_attachments} method
  # is configurable, and different classes may want to customize attachment management.
  #
  # The {Attachable} module defines generic code; there are also ORM-specific modules that implement
  # specialized functionality like the creation of query objects.

  module Attachable
    # Access operation: list attachments associated with an attachable.
    ACCESS_ATTACHMENT_INDEX = :attachment_index

    # Access operation: create a attachment associated with an attachable.
    ACCESS_ATTACHMENT_CREATE = :attachment_create

    # The methods in this module will be installed as class methods of the including class.

    module ClassMethods
      # Extension methods for attachment associations.
      # The methods in this module are added to the association defined by {ClassMethods#has_attachments}.
      # For example, if we have a class like this:
      #
      # ```
      # class MyObject
      #   include Fl::Framework::Attachment::Attachable
      #   has_attachments :images
      # end
      # ```
      # then the **images** association also responds to `allow?`.

      module AssociationExtensions
        # Check if an attachment with given content type can be added to the association.
        #
        # @param [String] type A MIME type.
        #
        # @return [Boolean] Returns `true` if *type* can be added, `false` if not.

        def allow?(type)
          name = self.proxy_association.reflection.name
          owner = self.proxy_association.owner

          r = owner.class.send(:type_registry_for, name)
          (r) ? r.allow?(type) : true
        end
      end

      # Add attachable behavior to a model.
      # This class method registers the APIs used to manage attachments:
      #
      # - Ensures that the attachable has included the {Fl::Framework::Access::Access} module.
      # - Adds an association to track attachments; this association depends on the selected ORM.
      # - If the ORM is Neo4j, includes the module {Fl::Framework::Neo4j::AssociationProxyCache}.
      # - Stores the list of allowed attachment classes from the *:only* and *:except* options.
      # - For Active Record, adds the methods in {AssociationExtensions} to the association, and updates
      #   `<<`, `push`, and `concat` to check if the operation is allowed by the *:only* and *:except*
      #   options. If not allowed, the attachment objects are not added to the association.
      # - Define the {#attachable?} method to return `true` to indicate that the class supports attachments.
      # - Loads the instance methods from {Attachable::InstanceMethods}.
      #
      # @overload has_attachments(name, cfg)
      #  Creates an association to manage attachments; the association name is *name*.
      #  @param name [Symbol] The association name.
      #  @param cfg [Hash] A hash containing configuration parameters.
      #   Note that, if neither *:only* nor *:except* are defined, all classes are allowed.
      #  @option cfg [Symbol] :orm is the ORM to use. Currently, we support two ORMs: +:activerecord+
      #   for Active Record, and +:neo4j+ for the Neo4j graph database.
      #   The default value is +:activerecord+.
      #  @option cfg [Symbol, String] :class_name If the ORM is +:activerecord+, this is the class name to use.
      #   The default is {Fl::Framework::Attachment::ActiveRecord::Base}.
      #  @option cfg [Symbol, String] :rel_class If the ORM is +:neo4j+, this is the relationship class to use
      #   for the association.
      #   The default is {Fl::Framework::Neo4j::Rel::Attachment::AttachedTo}, which uses the `ATTACHED_TO`
      #   relationship.
      #  @option cfg [Symbol] :dependent How to dispose of dependent objects (the attachments). This is
      #   passed to the association. Defaults to +:destroy+.
      # @option cfg [String, Array<String>] :only A MIME type, or an array of MIME types that define the list of
      #  content types that can be added to the association. This option is a whitelist of attachment types that
      #  are allowed by this association. Globbed MIME types (+image/*+) are also allowed.
      # @option cfg [String, Array<String>] :except A MIME type, or an array of MIME types that define the list
      #  ofcontent types that can *not* be added to the association. This option is a blacklist of attachment
      #  types that are not allowed by this association.
      #  If a class is listed in both *:except* and *:only*, it is forbidden (*:except* has higher priority
      #  than *:only*). Globbed MIME types (+image/*+) are also allowed.
      # @overload has_attachments(name)
      #  Creates an association whose name is *name*, using default configuration values.
      #  @param name [Symbol] The association name.
      # @overload has_attachments(cfg)
      #  Creates an association named `attachments` with the given configuration.
      #  @param cfg [Hash] A hash containing configuration parameters; see above for details.
      # @overload has_attachments()
      #  When used with no arguments, the method creates an association called `attachments` and with
      #  default configuration values.

      def has_attachments(*args)
        # turning on attachments requires that the attachable includes the access module

        unless self.include?(Fl::Framework::Access::Access)
          raise "internal error: class #{self.name} must include Fl::Framework::Access::Access to support attachments"
        end

        cfg = {
          orm: :activerecord,
          class_name: :'Fl::Framework::Attachment::ActiveRecord::Base',
          rel_class: :'Fl::Rel::Attachment::AttachedTo',
          dependent: :destroy,
          only: [],
          except: []
        }

        case args.count
        when 0
          name = :attachments
        when 1
          if args[0].is_a?(Hash)
            name = :attachments
            cfg.merge!(args[0])
          else
            name = args[0].to_sym
          end
        else
          name = args[0].to_sym
          h = args[1]
          if h.is_a?(Hash)
            cfg.merge!(h)
          end
        end

        orm = if cfg.has_key?(:orm)
                case cfg[:orm]
                when :activerecord, :neo4j
                  cfg[:orm]
                else
                  :activerecord
                end
              else
                :activerecord
              end

        cfg.delete(:orm)

        cfg[:as] = :attachable if orm == :activerecord

        # The type registry goes in a class instance variable so that subclasses don't affect it.

        @type_registries = {} unless defined?(@type_registries)
        @type_registries[name] = TypeRegistry.new({ only: cfg.delete(:only), except: cfg.delete(:except) })

        # This association tracks the attachments associated with an object.

        case orm
        when :activerecord
          cfg.delete(:rel_class)
          has_many(name, nil, cfg) do
            include AssociationExtensions

            def <<(obj)
              super(obj) if allow?(obj)
            end

            def push(obj)
              super(obj) if allow?(obj)
            end

            def concat(ary)
              can_concat = true
              ary.each { |o| can_concat = false if !allow?(o) }
              super(ary) if can_concat
            end
          end
        when :neo4j
          has_many :in, name, cfg
          unless included(Fl::Framework::Neo4j::AssociationProxyCache)
            include Fl::Framework::Neo4j::AssociationProxyCache
          end
        end

        unless included(Fl::Framework::Attachment::Attachable::InstanceMethods)
          include Fl::Framework::Attachment::Attachable::InstanceMethods
        end

        def attachable?()
          true
        end
      end

      # Check if this object manages attachments.
      # The default implementation returns `false`; {#has_attachments} overrides it to return `true`.
      #
      # @return [Boolean] Returns `true` if the object manages attachments.
        
      def attachable?
        false
      end

      protected

      # Get the type registry for a given association name.
      #
      # @param [Symbol, String] name The association name.
      #
      # @return [TypeRegistry, nil] Returns the type registry associated with this association, or `nil`
      #  if none was found.

      def type_registry_for(name = :attachments)
        @type_registries = {} unless @type_registries.is_a?(Hash)
        @type_registries[name.to_sym]
      end
    end

    # The methods in this module are installed as instance method of the including class.

    module InstanceMethods
      # Check if this object manages attachments.
      # Forwards the call to the class method
      # {Fl::Framework::Attachment::Attachable::ClassMethods#attachable?}.
      #
      # @return [Boolean] Returns `true` if the object manages attachments.
        
      def attachable?
        self.class.attachable?
      end
    end

    # Perform actions when the module is included.
    #
    # - Injects the class methods. Instance methods will be injected if {ClassMethods#has_attachments}
    #   is called.

    def self.included(base)
      base.extend ClassMethods

      base.instance_eval do
      end

      base.class_eval do
        # include InstanceMethods
      end
    end
  end
end
