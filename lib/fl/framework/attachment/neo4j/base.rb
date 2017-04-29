require 'fl/framework/attachment/registration'
require 'fl/framework/attribute_filters'
require 'fl/framework/model_hash'
require 'fl/framework/core/title_management'
require 'fl/framework/access'
if defined?(Neo4j)
  require 'fl/framework/rel/attachment/attached_to'
end

module Fl::Framework::Attachment::Neo4j
  # Base class for attachments for Neo4j databases.
  # Attachments always appear in the database associated with another object.
  # This association is managed through the +ATTACHED_TO+ relationship, and in the code via
  # {Fl::Framework::Rel::Attachment::AttachedTo}.
  #
  # Attachments implement the access control API in {Fl::Framework::Access::Access}, but forward permission
  # calls to the attachable object as follows:
  # - *:index* permission is granted if the user has +:read+ access to the context (which is the attachable).
  # - *:create* permission is granted if the user has +:write+ access to the context (which is the potential
  #   attachable).
  # - *:read* permission is granted if the user has +:read+ access to the attachable.
  # - *:write* permission is granted if the user has +:write+ access to the attachable.
  # - *:destroy* permission is granted if the user has +:write+ access to the attachable.
  # - {Fl::Framework::Attachment::ACCESS_DOWNLOAD} (*:download*) permission is granted if the user has
  #   +:read+ access to the attachable.
  # This implies that the attachable object must also implement the {Fl::Framework::Access::Access} interface.
  #
  # === Properties
  # This class defines the following properties:
  # - +title+ is a string containing a title for the attachment.
  # - +description+ is a string containing a description of the attachment.
  # - +created_at+ is an Integer containing the UNIX creation time.
  # - +updated_at+ is an Integer containing the UNIX modification time.
  #
  # === Associations
  # This class defines the following associations:
  # - *attachable* is the object that controls the attachment.

  class Base
    # @!visibility private
    class AttachableAccessValidator < ActiveModel::Validator
      # @!visibility private
      def validate(record)
        unless record.attachable.blank?
          unless record.attachable.respond_to?(:permission?)
            record.errors[:base] << I18n.tx('fl.attachment.base.model.validate.attachable_no_access_api',
                                            mclass: record.attachable.class.name)
          end
        end
      end
    end

    include Neo4j::ActiveNode
    include Fl::Framework::Attachment::Registration

    include Fl::Framework::AttributeFilters
    include Fl::Framework::ModelHash
    include Fl::Framework::Core::TitleManagement
    include Fl::Framework::Access::Access

    # @!visibility private
    TITLE_LENGTH = 40

    # @!visibility private
    DEFAULT_HASH_KEYS = [ :attachable, :title, :description ]

    property :title, type: String
    property :description, type: String

    property :created_at, type: Integer
    property :updated_at, type: Integer

    # @!attribute [rw] attachable
    # The association linking to the attachable object for the attachment.
    #
    # @overload attachable
    #  @return Returns the attachment's attachable object.
    # @overload attachable=(m)
    #  Set the attachable object.
    #  This implementation wraps around the original setter to perform the following operations:
    #  1. call {#will_change_attachable} and return immeditely if the method returns a false value.
    #  2. set the new attachable to _o_.
    #  3. call *association_proxy_cache.clear* on the old attachable, so that any cached attachment
    #     associations are cleared.
    #  4. call *association_proxy_cache.clear* on the new attachable, so that any cached attachment
    #     associations are cleared.
    #  5. call {#did_change_attachable}.
    #  Clearing the association proxy caches is a bit brutal, but it keeps the attachment lists in sync.
    #
    #  @param m [Object] The new attachable.

    has_one :out, :attachable, rel_class: :'Fl::Framework::Rel::Attachment::AttachedTo'

    before_destroy :_delete_attachable_relationship

    validates_presence_of :attachable
    validates_with AttachableAccessValidator

    before_validation :_before_validation_checks
    before_save :_before_save_checks
    after_save :_reset_attachable_cache

    filtered_attribute :title, [ FILTER_HTML_STRIP_DANGEROUS_ELEMENTS, FILTER_HTML_TEXT_ONLY ]
    filtered_attribute :description, FILTER_HTML_STRIP_DANGEROUS_ELEMENTS

    access_op :index, :_index_check
    access_op :create, :_create_check
    access_op :read, :_read_check
    access_op :write, :_write_check
    access_op :destroy, :_destroy_check
    access_op Fl::Framework::Attachment::ACCESS_DOWNLOAD, :_download_check, scope: :instance

    # Initializer.
    # The +attachable+ attribute is resolved to an object if passed as a dictionary
    # containing the object class and object id.
    #
    # @param attrs [Hash] A hash of initialization parameters.
    # @option attrs [Object, Hash] :attachable is the attachable object; this can be passed either as an object,
    #  or as a Hash containing the two keys *:id* and *:type*.
    # @option attrs [String] :title is the title for the attachment. The value may be +nil+.
    # @option attrs [String] :description is the description for the attachment. The value may be +nil+.

    def initialize(attrs = {})
      if attrs.has_key?(:attachable)
        begin
          attrs[:attachable] = self.class.convert_attachable(attrs, :attachable)
        rescue => exc
          self.errors[:attachable] << exc.message
          attrs.delete(:attachable)
        end
      end

      # why do we save the attachable? Because the :attachable association actually uses a different object
      # instance to store the attachable, and therefore the one that was passed is not the one returned
      # by a call to self.attachable. As a consequence, calls like self.attachable.association_proxy_cache.clear
      # do not have the desired effect, since they are made to the association object rather than the
      # one that was passed in. So we remember what was passed in and make the calls on it as needed.

      @_attachable = attrs[:attachable]

      super(attrs)
    end

    # @!visibility private
    alias _original_created_at= created_at=
    # @!visibility private
    alias _original_updated_at= updated_at=

    # Set the creation time.
    #
    # @param ctime The creation time; this can be an integer UNIX timestamp, or a TimeWithZone instance.

    def created_at=(ctime)
      ctime = ctime.to_i unless ctime.is_a?(Integer)
      self._original_created_at=(ctime)
    end

    # Set the update time.
    #
    # @param utime The update time; this can be an integer UNIX timestamp, or a TimeWithZone instance.

    def updated_at=(utime)
      utime = utime.to_i unless utime.is_a?(Integer)
      self._original_updated_at=(utime)
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

    def attachable=(o)
      if self.will_change_attachable(@_attachable, o)
        self._original_attachable=(o)
        @_attachable.association_proxy_cache.clear if @_attachable.respond_to?(:association_proxy_cache)
        o.association_proxy_cache.clear if o.respond_to?(:association_proxy_cache)
        self.did_change_attachable(@_attachable, o)
        @_attachable = o
      end
    end

    # Add the attachment to a attachable object.
    # This method performs the following operations:
    # - removes itself from the current attachable object, if any.
    # - saves the attachable object if it has not yet been persisted; this is required before a new
    #   +ATTACHED_TO+ relationship is created.
    # - saves +self+ if not persisted, for the same reason as above.
    # - sets the new *:attachable* value, which creates a new +ATTACHED_TO+ relationship.
    #
    # @param attachable [Object] The new attachable object.

    def attach_to_object(attachable)
      self.attachable = attachable
    end

    # Convert a attachable parameter to an object.
    # 1. If _p_ is a hash, see if it contains the key in _key_.
    # 2. If it does, get the value and start the conversion from 1.
    # 3. If it does not, see if it contains the two keys +:id+ and +:type+, and use those to get the
    #    attachable from the database.
    # 4. If the value is not a hash, check if it responds to +permission?+, and if so return the value.
    # 5. Otherwise, return +nil+
    #
    # @param p [Hash, Object] The parameter value.
    # @param key [Symbol] The key to look up, if _p_ is a Hash.
    #
    # @return Returns an object, or +nil+ if no object was found.
    #
    # @raise if _p_ maps to a +nil+, or if _p_ is neither a Hash nor an object.

    def self.convert_attachable(p, key = :attachable)
      if p.is_a?(Hash)
        k = key.to_sym
        if p.has_key?(k)
          convert_attachable(p[k], key)
        else
          p_class = p[:type]
          unless p_class
            raise I18n.tx('fl.attachment.base.model.conversion.missing_key', :key => 'type')
          else
            begin
              klass = p_class.constantize
            rescue => exc
              raise I18n.tx('fl.attachment.base.model.conversion.bad_attachable_class', :class => p_class)
            end

            p_id = p[:id]
            unless p_id
              raise I18n.tx('fl.attachment.base.model.conversion.missing_key', :key => 'id')
            else
              klass.find(p_id)
            end
          end
        end
      else
        (p.respond_to?(:permission?)) ? p : nil
      end
    end

    protected

    # The attachable will change.
    # The base implementation is empty; subclasses can override to add logic to the set operation.
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

    # Given a verbosity level, return predefined hash options to use.
    #
    # @param actor [Object] The actor for which we are building the hash representation.
    # @param verbosity [Symbol] The verbosity level; see #to_hash.
    # @param opts [Hash] The options that were passed to #to_hash.
    #
    # @return [Hash] Returns a hash containing default options for +verbosity+.

    def to_hash_options_for_verbosity(actor, verbosity, opts)
      if (verbosity == :minimal) || (verbosity == :standard)
        {
          :include => DEFAULT_HASH_KEYS
        }
      elsif (verbosity == :verbose) || (verbosity == :complete)
        {
          :include => DEFAULT_HASH_KEYS | []
        }
      else
        {}
      end
    end

    # Return the default list of operations for which to check permissions.
    # This implementation returns the array <tt>[ :read, :write, :destroy ]</tt>; we add :read because
    # comments can be picked up from the controller independently of the commentable (the actions 
    # +:show+, +:edit+, +:update+, and +:destroy+ are not nested in the commentable).
    #
    # @return [Array<Symbol>] Returns an array of Symbol values that list the operations for which
    #  to obtain permissions.

    def to_hash_operations_list
      [ ]
    end

    # Build a Hash representation of the attachment.
    #
    # @param actor [Object] The actor for which we are building the hash representation.
    # @param keys [Array<Symbol>] The keys to place in the hash.
    # @param opts [Hash] Options for the method.
    #
    # @return [Hash] Returns a Hash containing the attachment representation.
    # - *:attachable* A Hash containing the two keys +:id+ and +:type+, respectively the id and class name
    #   of the object for which this is an attachment.
    # - *:title* The attachment title.
    # - *:description* The attachment description.
    # - *:created_at* When created, as a UNIX timestamp.
    # - *:updated_at* When last updated, as a UNIX timestamp.

    def to_hash_local(actor, keys, opts = {})
      m = self.attachable

      rv = {}
      keys.each do |k|
        case k
        when :attachable
          rv[k] = m.to_hash(actor, verbosity: :id)
        else
          rv[k] = self.send(k) if self.respond_to?(k)
        end
      end

      rv
    end

    # Destroy callback to clear the +ATTACHED_TO+ relationship.
    # If this relationship is not removed, deletion of the node will fail.

    # @!visibility private
    def _delete_attachable_relationship()
      self.query_as(:a).match('(a)-[r:ATTACHED_TO]->(m)').delete(:r).exec()
    end

    private

    def _before_validation_checks
      populate_title_if_needed(:description, TITLE_LENGTH) unless self.description.blank?
    end

    def _before_save_checks
      populate_title_if_needed(:description, TITLE_LENGTH) unless self.description.blank?
    end

    def _reset_attachable_cache()
      @_attachable.association_proxy_cache.clear if @_attachable.respond_to?(:association_proxy_cache)
    end

    def self._index_check(op, obj, user, context = nil)
      context.permission?(user, Fl::Framework::Access::Grants::READ)
    end

    def self._create_check(op, obj, user, context = nil)
      context.permission?(user, Fl::Framework::Access::Grants::WRITE)
    end

    def _read_check(op, obj, user, context = nil)
      obj.attachable.permission?(user, Fl::Framework::Access::Grants::READ, context)
    end

    def _write_check(op, obj, user, context = nil)
      obj.attachable.permission?(user, Fl::Framework::Access::Grants::WRITE, context)
    end

    def _destroy_check(op, obj, user, context = nil)
      obj.attachable.permission?(user, Fl::Framework::Access::Grants::WRITE, context)
    end

    def _download_check(op, obj, user, context = nil)
      obj.attachable.permission?(user, Fl::Framework::Access::Grants::READ, context)
    end
  end
end
