require 'fl/framework/core/attribute_filters'
require 'fl/framework/access/access'
require 'fl/framework/core/title_management'
require 'fl/framework/core/model_hash'
require 'fl/framework/attachment/helper'

module Fl::Framework::Attachment
  # Mixin module to load common attachment functionality.
  # This module defines functionality shared by attachment implementations:
  #  module Fl::Framework::Attachment::ActiveRecord
  #    class Base < ApplicationRecord
  #      include Fl::Framework::Attachment::Common
  #
  #      # ActiveRecord-specific code ...
  #    end
  #  end
  #
  # == Access control
  # Attachments support the {Fl::Framework::Access::Access} API, but implement it as forwards to the
  # attachable as follows:
  # - *:index* forwards the request to the context (which is assumed to be the attachable), using
  #   the *:read* permission; see {ClassMethods#_index_check}.
  # - *:create* forwards the request to the context (which is assumed to be the candidate attachable), using
  #   the *:write* permission; see {ClassMethods#_create_check}.
  # - *:read* forwards the request to the attachable, using  the *:read* permission;
  #   see {InstanceMethods#_read_check}.
  # - *:write* grants access to the attachment's author by returning +:private+, and denies it to anyone else.
  #   See {InstanceMethods#_write_check}.
  # - *:destroy* grants access to the attachment's author by returning +:private+, and denies it to anyone else.
  #   see {InstanceMethods#_destroy_check}.
  # - *:download* forwards the request to the attachable, using  the *:read* permission;
  #   see {InstanceMethods#_download_check}.
  #
  # == Paperclip attachments
  # Because the base class for ActiveRecord ({ActiveRecord::Base}) uses Single Table Inheritance (STI),
  # it defines a general Paperclip attachment attribute called, unimaginatively, +:attachment+.
  # This means that all subclasses use that attribute name for teir attachment, which is less than ideal.
  # (The Neo4j class {Neo4j::Base} does not need to do so, but 
  # follows the same pattern of a common property for behavior consistency.)
  # In order to address this problem, subclasses can define an alias for the attachment attribute when
  # they declare the attachment; see the discussion in {ActiveRecord::Base}. 
  # In that case, they should also override {InstanceMethods#attachment_alias} so that the appropriate key
  # is placed in the hash representation. For example:
  #   class MyAttachment < Fl::Framework::Attachment::ActiveRecord::Base
  #     activerecord_attachment attachment, _type: :image, _alias: :picture
  #     set_attachment_alias :picture
  #   end
  # (At some point we may merge the definition of +attachment_alias+ into the +alias_attachment+
  # implementation.)
  # The model hash methods described later add the value returned by {InstanceMethods#attachment_alias} to
  # the default list of keys to be returned, so that the Paperclip attachment is returned as +:picture+
  # rather than +:attachment+.
  #
  # The method {InstanceMethods#normalize_attachment_attribute} is used to convert a class-specific
  # Paperclip attachment parameter name to the generic name +:attachment+.
  #
  # == Title management
  # The module sets up callbacks to extract the title from the caption if necessary.
  #
  # == Model hash
  # The module implements model hash functionality to generate a hash representation of the attachment object.
  #
  # == Attribute filtering
  # The +:title+ attribute is converted to text only (no HTML markup), and dangerous HTML markup is
  # stripped from the +:caption: attribute.
  #
  # == Validation
  # The module adds a number of validations.

  module Common
    protected

    # A validator to ensure that the attachable implements an access API.

    class AttachableAccessValidator < ActiveModel::Validator
      # Validates the record.
      # If _record_ is associated with an attachable, it must respond to the +:permission?+ method.
      # If it does not, an error is placed in the attachment's +errors+ hash.
      #
      # @param [Fl::Framework::Attachment::ActiveRecord::Base] record The attachment to validate.

      def validate(record)
        unless record.attachable.blank?
          unless record.attachable.respond_to?(:permission?)
            record.errors[:base] << I18n.tx('fl.framework.attachment.base.model.validate.master_no_access_api',
                                            mclass: record.attachable.class.name)
          end
        end
      end
    end

    # Methods to be registered as class methods of the including module/class.

    module ClassMethods
      # @!group Attachment support

      # Set the name of the attachment attribute.
      #
      # @param [Symbol] name A symbol containing the class-specific alias of the attachment attribute.
      #  See the discussion in {Fl::Framework::Attachment::Common}.

      def set_attachment_alias(name)
        @attachment_alias = name
      end

      # Get the name of the attachment attribute.
      #
      # @return [Symbol] Returns a symbol containing the class-specific alias of the attachment attribute.
      #  See the discussion in {Fl::Framework::Attachment::Common}.

      def attachment_alias()
        @attachment_alias
      end

      # @!endgroup

      # @!group Access control support

      protected

      # Access checker for the *:index* operation
      #
      # @param op [Fl::Framework::Access::Access::Checker] The requested operation (*:index*).
      # @param obj [Object] The target of the request.
      # @param actor [Object] The actor requesting permission.
      # @param context The context in which to do the check; here, it is expected to be the attachable.
      #
      # @return [Symbol, nil, Boolean] Forwards the call to the context, using the *:read* permission:
      #  _actor_ can list attachments if it has read access to the attachable.

      def _index_check(op, obj, actor, context = nil)
        context.permission?(actor, Fl::Framework::Access::Grants::READ)
      end

      # Access checker for the *:create* operation
      #
      # @param op [Fl::Framework::Access::Access::Checker] The requested operation (*:create*).
      # @param obj [Object] The target of the request.
      # @param actor [Object] The actor requesting permission.
      # @param context The context in which to do the check; here, it is expected to be the potential
      #  attachable.
      #
      # @return [Symbol, nil, Boolean] Forwards the call to the context, using the *:write* permission:
      #  _actor_ can add attachments if it has write access to the attachable.

      def _create_check(op, obj, actor, context = nil)
        context.permission?(actor, Fl::Framework::Access::Grants::WRITE)
      end

      # @!endgroup
    end

    # Methods to be registered as instance methods of the including module/class.

    module InstanceMethods
      # @!group Attachment support

      protected

      # The name of the Paperclip attachment attribute as stored in the STI table.

      ATTACHMENT_ATTRIBUTE_NAME = :attachment

      # Get the name of the attachment attribute.
      # The instance method calls the class method by the same name;
      # see {Fl::Framework::Attachment::Common::ClassMethods#attachment_alias}.
      #
      # @return [Symbol] Returns a symbol containing the class-specific alias of the attachment attribute.
      #  See the discussion in {Fl::Framework::Attachment::Common}.

      def attachment_alias()
        self.class.attachment_alias()
      end

      # Normalize the Paperclip attachment attribute parameter.
      # For example, the hash <code>{ picture: paperclip_attachment, caption: 'The caption' }</code>
      # is converted to <code>{ attachment: paperclip_attachment, caption: 'The caption' }</code>.
      # This example assumes that {#attachment_alias} returns +:picture+.
      #
      # @param [Hash] params A hash of parameters.
      #
      # @return [Hash] Returns a hash where the class-specific Paperclip attachment has been renamed to
      #  the base class attachment name ({ATTACHMENT_ATTRIBUTE_NAME}).

      def normalize_attachment_attribute(params)
        name = attachment_alias()
        if (name != ATTACHMENT_ATTRIBUTE_NAME) && params.has_key?(name)
          params[ATTACHMENT_ATTRIBUTE_NAME] = params.delete(name)
        end

        params
      end

      # @!endgroup

      # @!group Access control support

      public

      # Support for {Fl::Framework::Access::Access}: return the owners of the attachment.
      #
      # @return [Array<Object>] Returns an array containing the value of the +author+ association.

      def owners()
        [ self.author ]
      end

      protected

      # Access checker for the *:read* operation
      #
      # @param op [Fl::Framework::Access::Access::Checker] The requested operation (*:read*).
      # @param obj [Object] The target of the request.
      # @param actor [Object] The actor requesting permission.
      # @param context The context in which to do the check.
      #
      # @return [Symbol, nil, Boolean] Forwards the call to the attachable, using the *:read* permission:
      #  _actor_ can read the attachment if it has read access to the attachable.

      def _read_check(op, obj, actor, context = nil)
        obj.attachable.permission?(actor, Fl::Framework::Access::Grants::READ, context)
      end

      # Access checker for the *:write* operation
      #
      # @param op [Fl::Framework::Access::Access::Checker] The requested operation (*:write*).
      # @param obj [Object] The target of the request; in our case, the attachment.
      # @param actor [Object] The actor requesting permission.
      # @param context The context in which to do the check.
      #
      # @return [Symbol, nil, Boolean] Returns +:private+ if _actor_ is the same as the attachment's author,
      #  +nil+ otherwise: only the attachment's author can modify it.

      def _write_check(op, obj, actor, context = nil)
        if actor && (actor.class == obj.author.class) && (actor.id == obj.author.id)
          :private
        else
          nil
        end
      end

      # Access checker for the *:destroy* operation
      #
      # @param op [Fl::Framework::Access::Access::Checker] The requested operation (*:destroy*).
      # @param obj [Object] The target of the request; in our case, the attachment.
      # @param actor [Object] The actor requesting permission.
      # @param context The context in which to do the check.
      #
      # @return [Symbol, nil, Boolean] Returns +:private+ if _actor_ is the same as the attachment's author,
      #  +nil+ otherwise: only the attachment's author can modify it.

      def _destroy_check(op, obj, actor, context = nil)
        if actor && (actor.class == obj.author.class) && (actor.id == obj.author.id)
          :private
        else
          nil
        end
      end

      # Access checker for the *:download* operation
      #
      # @param op [Fl::Framework::Access::Access::Checker] The requested operation (*:download*).
      # @param obj [Object] The target of the request.
      # @param actor [Object] The actor requesting permission.
      # @param context The context in which to do the check.
      #
      # @return [Symbol, nil, Boolean] Forwards the call to the attachable, using the *:read* permission:
      #  _actor_ can download the attachment file if it has read access to the attachable.

      def _download_check(op, obj, actor, context = nil)
        obj.attachable.permission?(actor, Fl::Framework::Access::Grants::READ, context)
      end

      # @!endgroup

      # @!group Title management

      protected

      # @!visibility private
      TITLE_LENGTH = 40

      # Set up the attachment state before validation.
      # This method populates the *:title* attribute, if necessary, from the contents.

      def _before_validation_title_checks
        populate_title_if_needed(:contents, TITLE_LENGTH)
      end

      # Set up the attachment state before saving.
      # This method populates the *:title* attribute, if necessary, from the contents.

      def _before_save_title_checks
        populate_title_if_needed(:contents, TITLE_LENGTH)
      end

      # @!endgroup

      # @!group Model hash

      protected

      # @!visibility private
      TO_HASH_ATTACHMENT_SIZES = [ :xlarge, :large, :medium, :small, :thumb, :iphone ]

      # @!visibility private
      DEFAULT_HASH_KEYS = [ :attachable, :author, :title, :caption, :processing ]

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
            :include => (DEFAULT_HASH_KEYS | [ attachment_alias() ])
          }
        elsif (verbosity == :verbose) || (verbosity == :complete)
          {
            :include => (DEFAULT_HASH_KEYS | [ attachment_alias() ] | [])
          }
        else
          {}
        end
      end

      # Return the default list of operations for which to check permissions.
      # This implementation returns the array <tt>[ :read, :write, :destroy, :download ]</tt>; we add :read
      # because attachments can be picked up from the controller independently of the attachable (the actions 
      # +:show+, +:edit+, +:update+, and +:destroy+ are not nested in the attachable).
      #
      # @return [Array<Symbol>] Returns an array of Symbol values that list the operations for which
      #  to obtain permissions.

      def to_hash_operations_list
        [ Fl::Framework::Access::Grants::READ, Fl::Framework::Access::Grants::WRITE,
          Fl::Framework::Access::Grants::DESTROY, Fl::Framework::Attachment::ACCESS_DOWNLOAD ]
      end

      # Build a Hash representation of the attachment.
      #
      # @param actor [Object] The actor for which we are building the hash representation.
      # @param keys [Array<Symbol>] The keys to place in the hash.
      # @param opts [Hash] Options for the method; none are used by this method.
      #
      # @return [Hash] Returns a Hash containing the attachment representation.
      # - *:attachable* A Hash containing the two keys *:id* and *:type*, respectively the id and class name
      #   of the attachable object for which the attachment was created.
      # - *:author* Information about the author; a Hash containing these keys (if supported):
      #   - *:id* The id.
      #   - *:username* The login name.
      #   - *:full_name* The full name.
      #   - *:avatar* A hash containing the URLs to the owner's avatar; the hash contains the keys *:list*,
      #     *:thumb*, *:medium*, *:large*, and *:xlarge*.
      # - *:created_at* When created, as a UNIX timestamp.
      # - *:updated_at* When last updated, as a UNIX timestamp.
      # - *:permissions* An array containing permissions on this comment.
      # - *:title* The comment title.
      # - *:caption* The attachment caption.
      # - The Paperclip attachment; the key is obtained from {#attachment_alias}.

      def to_hash_local(actor, keys, opts = {})
        to_hash_opts = opts[:to_hash] || {}
        c = self.attachable
        u = self.author

        rv = {}
        keys.each do |k|
          case k
          when :attachable
            rv[k] = c.to_hash(actor, verbosity: :id)
          when :author
            author_opts = to_hash_opts_with_defaults(to_hash_opts[:author], {
                                                       verbosity: :id,
                                                       include: [ :username, :full_name, :avatar ]
                                                     })
            rv[k] = u.to_hash(actor, author_opts)
          when :processing
            rv[k] = (self.respond_to?(:processing?)) ? self.processing? : false
          else
            if self.respond_to?(k)
              v = self.send(k)
              if v.is_a?(Paperclip::Attachment)
                sizes = (opts.has_key?(:image_sizes)) ? opts[:image_sizes] : TO_HASH_ATTACHMENT_SIZES
                rv[k] = to_hash_image_attachment(v, sizes)
              else
                rv[k] = v
              end
            end
          end
        end

        rv
      end

      # @!endgroup
    end

    # Include hook.
    # This method performs the following operations:
    # - Registers the methods in {ClassMethods} as class methods of _base_.
    # - In the context of the _base_ (and therefore of the comment class), includes the modules
    #   {Fl::Framework::Core::AttributeFilters}, {Fl::Framework::Access::Access},
    #   {Fl::Framework::Core::TitleManagement}, {Fl::Framework::Core::ModelHash},
    #   {Fl::Framework::Attachment::Helper}, and {Fl::Framework::Attachment::Attachable}.
    #   Because the includes are executed in the _base_, the functionality is loaded in the comment
    #   implementation class.
    # - Also includes the module {InstanceMethods} to register the instance methods.
    # - Registers attribute filters for +:title+ and +:caption+: the title is converted to text only,
    #   and captions are stripped of dangerous HTML.
    # - Registers access checkers for +:index+, +:create+, +:read+, +:write+, +:destroy+, and +:download+.
    # - Registers a +before_validation+ callback to set up the title for validation;
    #   see {InstanceMethods#_before_validation_title_checks}.
    # - Registers a +before_save+ callback to set up the title for saving;
    #   see {InstanceMethods#_before_save_title_checks}.
    # - Adds validation rules:
    #   - *:attachable*, *:author*, and *:attachment* must be present.
    #   - Maximum content length for *:title* is 100.
    #   - Validate with {AttachableAccessValidator}
    #
    # @param [Class, Module] base The including class or module; note that this module expect to be 
    #  included from a class definition for comments.

    def self.included(base)
      base.extend ClassMethods

      base.send(:include, Fl::Framework::Core::AttributeFilters)
      base.send(:include, Fl::Framework::Access::Access)
      base.send(:include, Fl::Framework::Core::TitleManagement)
      base.send(:include, Fl::Framework::Core::ModelHash)
      base.send(:include, Fl::Framework::Attachment::Helper)
#        base.send(:include, Fl::Framework::Attachment::Attachable)

      base.send(:include, InstanceMethods)

      base.class_eval do
        # Filtered attributes

        filtered_attribute :title, [ base.const_get(:FILTER_HTML_STRIP_DANGEROUS_ELEMENTS),
                                     base.const_get(:FILTER_HTML_TEXT_ONLY) ]
        filtered_attribute :caption, base.const_get(:FILTER_HTML_STRIP_DANGEROUS_ELEMENTS)

        # access control

        access_op :index, :_index_check
        access_op :create, :_create_check
        access_op :read, :_read_check
        access_op :write, :_write_check
        access_op :destroy, :_destroy_check
        access_op Fl::Framework::Attachment::ACCESS_DOWNLOAD, :_download_check, scope: :instance

        # Validation

        validates_presence_of :attachable, :author, :attachment
        validates_length_of :title, :maximum => 100
        validates_with AttachableAccessValidator

        before_validation :_before_validation_title_checks

        # Title

        before_save :_before_save_title_checks
      end
    end
  end
end
