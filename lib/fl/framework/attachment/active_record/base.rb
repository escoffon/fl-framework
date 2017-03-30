module Fl::Framework::Attachment::ActiveRecord
  # Base class for attachments on ActiveRecord objects.
  # Attachments always appear in the database associated with another object, which is referred to as the
  # attachment's _master_.
  #
  # Attachments implement the access control API in {Fl::Framework::Access::Access}, but forward permission
  # calls to the master object as follows:
  # - *:index* permission is granted if the user has +:read+ access to the context (which is the master).
  # - *:create* permission is granted if the user has +:write+ access to the context (which is the potential
  #    master).
  # - *:read* permission is granted if the user has +:read+ access to the master.
  # - *:write* permission is granted if the user has +:write+ access to the master.
  # - *:destroy* permission is granted if the user has +:write+ access to the master.
  # - {Fl::Framework::Attachment::ACCESS_DOWNLOAD} (*:download*) permission is granted if the user has
  #   +:read+ access to the master.
  #
  # === Attributes
  # This class defines the following attributes:
  # - +title+ is a string containing a title for the attachment.
  # - +description+ is a string containing a description of the attachment.
  # - +created_at+ is an Integer containing the UNIX creation time.
  # - +updated_at+ is an Integer containing the UNIX modification time.
  #
  # === Associations
  # This class defines the following associations:
  # - *master* is the object that controls the attachment.

  class Base
    # @!visibility private
    class MasterAccessValidator < ActiveModel::Validator
      # @!visibility private
      def validate(record)
        unless record.master.blank?
          unless record.master.respond_to?(:permission?)
            record.errors[:base] << I18n.tx('fl.attachment.base.model.validate.master_no_access_api',
                                            mclass: record.master.class.name)
          end
        end
      end
    end

    include Neo4j::ActiveNode
    include Fl::Attachment::Registration

    include Fl::AttributeFilters
    include Fl::ModelHash
    include Fl::Core::TitleManagement
    include Fl::Access::Access

    # @!visibility private
    TITLE_LENGTH = 40

    # @!visibility private
    DEFAULT_HASH_KEYS = [ :master, :title, :description ]

    property :title, type: String
    property :description, type: String

    property :created_at, type: Integer
    property :updated_at, type: Integer

    # @!attribute [rw] master
    # The association linking to the master object for the attachment.
    #
    # @overload master
    #  @return Returns the attachment's master object.
    # @overload master=(m)
    #  Set the master object.
    #  This implementation wraps around the original setter to perform the following operations:
    #  1. call {#will_change_master} and return immeditely if the method returns a false value.
    #  2. set the new master to _o_.
    #  3. call *association_proxy_cache.clear* on the old master, so that any cached attachment
    #     associations are cleared.
    #  4. call *association_proxy_cache.clear* on the new master, so that any cached attachment
    #     associations are cleared.
    #  5. call {#did_change_master}.
    #  Clearing the association proxy caches is a bit brutal, but it keeps the attachment lists in sync.
    #
    #  @param m [Object] The new master.

    has_one :out, :master, rel_class: :'Fl::Rel::Attachment::AttachedTo'

    before_destroy :_delete_master_relationship

    validates_presence_of :master
    validates_with MasterAccessValidator

    before_validation :_before_validation_checks
    before_save :_before_save_checks
    after_save :_reset_master_cache

    filtered_attribute :title, [ FILTER_HTML_STRIP_DANGEROUS_ELEMENTS, FILTER_HTML_TEXT_ONLY ]
    filtered_attribute :description, FILTER_HTML_STRIP_DANGEROUS_ELEMENTS

    access_op :index, :_index_check
    access_op :create, :_create_check
    access_op :read, :_read_check
    access_op :write, :_write_check
    access_op :destroy, :_destroy_check
    access_op Fl::Attachment::ACCESS_DOWNLOAD, :_download_check, scope: :instance

    # Initializer.
    # The +master+ attribute is resolved to an object if passed as a dictionary
    # containing the object class and object id.
    #
    # @param attrs [Hash] A hash of initialization parameters.
    # @option attrs [Object, Hash] :master is the master object; this can be passed either as an object,
    #  or as a Hash containing the two keys *:id* and *:type*.
    # @option attrs [String] :title is the title for the attachment. The value may be +nil+.
    # @option attrs [String] :description is the description for the attachment. The value may be +nil+.

    def initialize(attrs = {})
      if attrs.has_key?(:master)
        begin
          attrs[:master] = self.class.convert_master(attrs, :master)
        rescue => exc
          self.errors[:master] << exc.message
          attrs.delete(:master)
        end
      end

      # why do we save the master? Because the :master association actually uses a different object
      # instance to store the master, and therefore the one that was passed is not the one returned
      # by a call to self.master. As a consequence, calls like self.master.association_proxy_cache.clear
      # do not have the desired effect, since they are made to the association object rather than the
      # one that was passed in. So we remember what was passed in and make the calls on it as needed.

      @_master = attrs[:master]

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
    alias _original_master= master=

    def master=(o)
      if self.will_change_master(@_master, o)
        self._original_master=(o)
        @_master.association_proxy_cache.clear if @_master.respond_to?(:association_proxy_cache)
        o.association_proxy_cache.clear if o.respond_to?(:association_proxy_cache)
        self.did_change_master(@_master, o)
        @_master = o
      end
    end

    # Add the attachment to a master object.
    # This method performs the following operations:
    # - removes itself from the current master object, if any.
    # - saves the master object if it has not yet been persisted; this is required before a new
    #   +ATTACHED_TO+ relationship is created.
    # - saves +self+ if not persisted, for the same reason as above.
    # - sets the new *:master* value, which creates a new +ATTACHED_TO+ relationship.
    #
    # @param master [Object] The new master object.

    def attach_to_object(master)
      self.master = master
    end

    # Convert a master parameter to an object.
    # 1. If _p_ is a hash, see if it contains the key in _key_.
    # 2. If it does, get the value and start the conversion from 1.
    # 3. If it does not, see if it contains the two keys +:id+ and +:type+, and use those to get the
    #    master from the database.
    # 4. If the value is not a hash, check if it responds to +permission?+, and if so return the value.
    # 5. Otherwise, return +nil+
    #
    # @param p [Hash, Object] The parameter value.
    # @param key [Symbol] The key to look up, if _p_ is a Hash.
    #
    # @return Returns an object, or +nil+ if no object was found.
    #
    # @raise if _p_ maps to a +nil+, or if _p_ is neither a Hash nor an object.

    def self.convert_master(p, key = :master)
      if p.is_a?(Hash)
        k = key.to_sym
        if p.has_key?(k)
          convert_master(p[k], key)
        else
          p_class = p[:type]
          unless p_class
            raise I18n.tx('fl.attachment.base.model.conversion.missing_key', :key => 'type')
          else
            begin
              klass = p_class.constantize
            rescue => exc
              raise I18n.tx('fl.attachment.base.model.conversion.bad_master_class', :class => p_class)
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

    # The master will change.
    # The base implementation is empty; subclasses can override to add logic to the set operation.
    #
    # @param old [Object] The old master.
    # @param new [Object] The new master.
    #
    # @return [Boolean] Return +true+ to proceed with the set, +false+ to veto the operation.

    def will_change_master(old, new)
      true
    end

    # The master did change.
    # The base implementation is empty; subclasses can override to add logic to the set operation.
    #
    # @param old [Object] The old master.
    # @param new [Object] The new master.

    def did_change_master(old, new)
    end

    # Given a verbosity level, return predefined hash options to use.
    #
    # @param verbosity [Symbol] The verbosity level; see #to_hash.
    # @param opts [Hash] The options that were passed to #to_hash.
    #
    # @return [Hash] Returns a hash containing default options for +verbosity+.

    def to_hash_options_for_verbosity(verbosity, opts)
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
    # @param user [Fl::Core::User] The user for which (whom?) we are building the hash representation. Some
    #  models may return different contents, based on the requesting user.
    #  See the documentation for {Fl::ModelHash#to_hash}.
    # @param keys [Array<Symbol>] The keys to place in the hash.
    # @param opts [Hash] Options for the method; none are used by {Fl::Comment::Comment}.
    #
    # @return [Hash] Returns a Hash containing the attachment representation.
    # - *:master* A Hash containing the two keys +:id+ and +:type+, respectively the id and class name
    #   of the object for which this is an attachment.
    # - *:title* The attachment title.
    # - *:description* The attachment description.
    # - *:created_at* When created, as a UNIX timestamp.
    # - *:updated_at* When last updated, as a UNIX timestamp.

    def to_hash_local(user, keys, opts = {})
      m = self.master

      rv = {}
      keys.each do |k|
        case k
        when :master
          rv[k] = m.to_hash(user, verbosity: :id)
        else
          rv[k] = self.send(k) if self.respond_to?(k)
        end
      end

      rv
    end

    # Destroy callback to clear the +ATTACHED_TO+ relationship.
    # If this relationship is not removed, deletion of the node will fail.

    # @!visibility private
    def _delete_master_relationship()
      self.query_as(:a).match('(a)-[r:ATTACHED_TO]->(m)').delete(:r).exec()
    end

    private

    def _before_validation_checks
      populate_title_if_needed(:description, TITLE_LENGTH) unless self.description.blank?
    end

    def _before_save_checks
      populate_title_if_needed(:description, TITLE_LENGTH) unless self.description.blank?
    end

    def _reset_master_cache()
      @_master.association_proxy_cache.clear if @_master.respond_to?(:association_proxy_cache)
    end

    def self._index_check(op, obj, user, context = nil)
      context.permission?(user, Fl::Access::Grants::READ)
    end

    def self._create_check(op, obj, user, context = nil)
      context.permission?(user, Fl::Access::Grants::WRITE)
    end

    def _read_check(op, obj, user, context = nil)
      obj.master.permission?(user, Fl::Access::Grants::READ, context)
    end

    def _write_check(op, obj, user, context = nil)
      obj.master.permission?(user, Fl::Access::Grants::WRITE, context)
    end

    def _destroy_check(op, obj, user, context = nil)
      obj.master.permission?(user, Fl::Access::Grants::WRITE, context)
    end

    def _download_check(op, obj, user, context = nil)
      obj.master.permission?(user, Fl::Access::Grants::READ, context)
    end
  end
end
