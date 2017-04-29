require 'fl/framework/comment/helper'
require 'fl/framework/comment/commentable'

module Fl::Framework::Comment
  # Mixin module to load common comment functionality.
  # This module defines functionality shared by comment implementations:
  #  module Fl::Framework::Comment::ActiveRecord
  #    class Comment < ApplicationRecord
  #      include Fl::Framework::Comment::Common
  #
  #      # ActiveRecord-specific code ...
  #    end
  #  end

  module Common
    protected

    # A validator to ensure that the comment author has read permission on the comment's commentable.

    class PermissionValidator < ActiveModel::Validator
      # Validation check.
      #
      # @param [Object] record The comment record to validate.

      def validate(record)
        unless record.commentable.blank?
          unless record.commentable.permission?(record.author, :read)
            record.errors[:base] << I18n.tx('fl.framework.comment.comment.model.validate.create.no_commentable_permission')
          end
        end
      end
    end

    # Methods to be registered as class methods of the including module/class.

    module ClassMethods
      # @!group Access control support

      protected

      # The access checker method for +:index+.
      # This method passes the request to the associated commentable using the +:comment_index+ operation.
      #
      # @param op [Fl::Framework::Access::Access::Checker] The requested operation.
      # @param obj [Object] The target of the request.
      # @param actor [Object] The actor requesting permission.
      # @param context The context in which to do the check.
      #  In this case, the context is the commentable object whose comments we want to list.
      #
      # @return [Boolean] Returns a symbol corresponding to the access level granted, or +nil+ if access is
      #  denied.

      def _index_check(op, obj, actor, context = nil)
        context.permission?(actor, Fl::Framework::Comment::Commentable::ACCESS_COMMENT_INDEX)
      end

      # The access checker method for +:create+.
      # This method passes the request to the associated resource using the +:comment_create+ operation.
      #
      # @param op [Fl::Framework::Access::Access::Checker] The requested operation.
      # @param obj [Object] The target of the request.
      # @param actor [Object] The actor requesting permission.
      # @param context The context in which to do the check.
      #  In this case, the context is the commentable object where we want to create a comment.
      #
      # @return [Boolean] Returns a symbol corresponding to the access level granted, or +nil+ if access is
      #  denied.

      def _create_check(op, obj, actor, context = nil)
        context.permission?(actor, Fl::Framework::Comment::Commentable::ACCESS_COMMENT_CREATE)
      end

      # @!endgroup
    end

    # Methods to be registered as instance methods of the including module/class.

    module InstanceMethods
      # @!group Access control support

      public

      # Support for {Fl::Framework::Access::Access}: return the owners of the comment.
      #
      # @return [Array<Object>] Returns an array containing the value of the +author+ association.

      def owners()
        [ self.author ]
      end

      protected

      # The access checker method for +:read+.
      # A comment is viewable if _actor_ has +:read+ access to the commentable (which in our case is the
      # +commentable+ association of _obj_).
      #
      # @param op [Fl::Framework::Access::Access::Checker] The requested operation.
      # @param obj [Object] The target of the request.
      # @param actor [Object] The actor requesting permission.
      # @param context The context in which to do the check.
      #
      # @return [Boolean] Returns a symbol corresponding to the access level granted, or +nil+ if access is
      #  denied.

      def _read_check(op, obj, actor, context = nil)
        obj.commentable.permission?(actor, Fl::Framework::Access::Grants::READ, context)
      end

      # The access checker method for +:write+.
      # Currently always returns +nil+: comments may not be edited after having been created.
      #
      # @param op [Fl::Framework::Access::Access::Checker] The requested operation.
      # @param obj [Object] The target of the request.
      # @param actor [Object] The actor requesting permission.
      # @param context The context in which to do the check.
      #  In this case, the context is the commentable object whose comments we want to list.
      #
      # @return [Boolean] Returns a symbol corresponding to the access level granted, or +nil+ if access is
      #  denied.

      def _write_check(op, obj, actor, context = nil)
        nil
      end

      # The access checker method for :destroy.
      # Returns +:private+ if _actor_ is the comment's owner, +nil+ otherwise.
      #
      # @param op [Fl::Framework::Access::Access::Checker] The requested operation.
      # @param obj [Object] The target of the request.
      # @param actor [Object] The actor requesting permission.
      # @param context The context in which to do the check.
      #  In this case, the context is the commentable object whose comments we want to list.
      #
      # @return [Boolean] Returns a symbol corresponding to the access level granted, or +nil+ if access is
      #  denied.

      def _destroy_check(op, obj, actor, context = nil)
        return nil unless actor
        (actor.id == obj.author.id) ? :private : nil
      end

      # @!endgroup

      # @!group Title management

      protected

      # @!visibility private
      TITLE_LENGTH = 40

      # Set up the comment state before validation.
      # This method populates the *:title* attribute, if necessary, from the contents.

      def _before_validation_title_checks
        populate_title_if_needed(:contents, TITLE_LENGTH)
      end

      # Set up the comment state before saving.
      # This method populates the *:title* attribute, if necessary, from the contents.

      def _before_save_title_checks
        populate_title_if_needed(:contents, TITLE_LENGTH)
      end

      # @!endgroup

      # @!group Model hash

      protected

      # @!visibility private
      DEFAULT_HASH_KEYS = [ :commentable, :author, :title, :contents ]

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
        [ Fl::Framework::Access::Grants::READ, Fl::Framework::Access::Grants::WRITE,
          Fl::Framework::Access::Grants::DESTROY,
          Fl::Framework::Attachment::Attachable::ACCESS_ATTACHMENT_INDEX,
          Fl::Framework::Attachment::Attachable::ACCESS_ATTACHMENT_CREATE
        ]
      end

      # Build a Hash representation of the comment.
      #
      # @param actor [Object] The actor for which we are building the hash representation.
      # @param keys [Array<Symbol>] The keys to place in the hash.
      # @param opts [Hash] Options for the method; none are used by this method.
      #
      # @return [Hash] Returns a Hash containing the comment representation.
      # - *:commentable* A Hash containing the two keys *:id* and *:type*, respectively the id and class name
      #   of the commentable object for which the comment was created.
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
      # - *:contents* The contents of the comment.

      def to_hash_local(actor, keys, opts = {})
        to_hash_opts = opts[:to_hash] || {}
        c = self.commentable
        u = self.author

        rv = {}
        keys.each do |k|
          case k
          when :commentable
            rv[k] = c.to_hash(actor, verbosity: :id)
          when :author
            author_opts = to_hash_opts_with_defaults(to_hash_opts[:author], {
                                                       verbosity: :id,
                                                       include: [ :username, :full_name, :avatar ]
                                                     })
            rv[k] = u.to_hash(actor, author_opts)
          else
            rv[k] = self.send(k) if self.respond_to?(k)
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
    #   {Fl::Framework::Comment::Helper}, and {Fl::Framework::Comment::Commentable}.
    #   Because the includes are executed in the _base_, the functionality is loaded in the comment
    #   implementation class.
    # - Also includes the module {InstanceMethods} to register the instance methods.
    # - Registers attribute filters for +:title+ and +:contents+: the title is converted to text only,
    #   and contents are stripped of dangerous HTML.
    # - Registers access checkers for +:index+, +:create+, +:read+, +:write+, and +:destroy+.
    # - Registers a +before_validation+ callback to set up the title for validation;
    #   see {InstanceMethods#_before_validation_title_checks}.
    # - Registers a +before_save+ callback to set up the title for saving;
    #   see {InstanceMethods#_before_save_title_checks}.
    # - Adds validation rules:
    #   - *:commentable*, *:author*, and *:contents* must be present.
    #   - Minimum content length for *:contents* is 1.
    #   - Maximum content length for *:title* is 100.
    #   - Validate with {PermissionValidator}
    #
    # @param [Class, Module] base The including class or module; note that this module expect to be 
    #  included from a class definition for comments.

    def self.included(base)
      base.extend ClassMethods

      base.send(:include, Fl::Framework::Core::AttributeFilters)
      base.send(:include, Fl::Framework::Access::Access)
      base.send(:include, Fl::Framework::Core::TitleManagement)
      base.send(:include, Fl::Framework::Core::ModelHash)
      base.send(:include, Fl::Framework::Comment::Helper)
      base.send(:include, Fl::Framework::Comment::Commentable)

      base.send(:include, InstanceMethods)

      base.class_eval do
        # Filtered attributes

        filtered_attribute :title, [ base.const_get(:FILTER_HTML_STRIP_DANGEROUS_ELEMENTS),
                                     base.const_get(:FILTER_HTML_TEXT_ONLY) ]
        filtered_attribute :contents, base.const_get(:FILTER_HTML_STRIP_DANGEROUS_ELEMENTS)

        # access control

        access_op :index, :_index_check
        access_op :create, :_create_check
        access_op :read, :_read_check
        access_op :write, :_write_check
        access_op :destroy, :_destroy_check

        # Validation

        validates_presence_of :commentable, :author, :contents
        validates_length_of :contents, :minimum => 1
        validates_length_of :title, :maximum => 100
        validates_with PermissionValidator

        before_validation :_before_validation_title_checks

        # Title

        before_save :_before_save_title_checks
      end
    end
  end
end
