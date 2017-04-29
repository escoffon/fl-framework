require 'fl/framework/access'

module Fl::Framework::Comment
  # Extension module for use by objects that need to implement comment management.
  # This module defines common functionality for all model classes that use comments; these objects are
  # accessed as the _commentable_ from the comment objects.
  #
  # Note that inclusion of this module is not enough to turn on comment management: the class method
  # {Commentable::ClassMethods#has_comments} must be called to indicate that this class
  # supports comments; for example, for Neo4j:
  #  class MyClass
  #    include Neo4j::ActiveNode
  #    include Fl::Framework::Comment::Commentable
  #    include Fl::Framework::Comment::Neo4j::Commentable
  #
  #    has_comments orm: :neo4j
  #  end
  # and for Active Record:
  #  class MyClass < ApplicationRecord
  #    include Fl::Framework::Comment::Commentable
  #
  #    has_comments
  #  end
  # (+:activerecord+ is the default ORM.)
  # The reason we do this is that the {Commentable::ClassMethods#has_comments} method
  # is configurable, and different classes may want to customize comment management.
  #
  # The {Commentable} module defines generic code; there are also ORM-specific modules that implement
  # specialized functionality like the creation of query objects.

  module Commentable
    # Access operation: list comments associated with a commentable.
    ACCESS_COMMENT_INDEX = :comment_index

    # Access operation: create a comment associated with a commentable.
    ACCESS_COMMENT_CREATE = :comment_create

    # The methods in this module will be installed as class methods of the including class.

    module ClassMethods
      # Add commentable behavior to a model.
      # This class method registers the APIs used to manage comments:
      # - Ensures that the commentable has included the {Fl::Framework::Access::Access} module.
      # - Adds the +comments+ association to track comments; the association depends on the selected ORM.
      # - Defines the +build_comment+ methods, a wrapper around the constructor for the comment class
      #   appropriate for the selected ORM. The argument to this method is a hash of parameters to pass to
      #   the comment class constructor. For example, calling +build_comment+ on a commentable configured for
      #   ActiveRecord returns an instance of {Fl::Framework::Comment::ActiveRecord::Comment}.
      # - If the ORM is Neo4j, includes the module {Fl::Framework::Neo4j::AssociationProxyCache}.
      # - Loads the instance methods from {Commentable::InstanceMethods}.
      # - Registers new access checkers for the following operations: +:comment_index+, +:comment_create+.
      #   These are registered as the two methods
      #   {Fl::Comment::Commentable::InstanceMethods#_comment_index_check} and
      #   {Fl::Comment::Commentable::InstanceMethods#_comment_create_check}, respectively.
      #   Implementations can redefine the methods to change the access check behavior.
      # - Define the {#commentable?} method to return +true+ to indicate that the class supports comments.
      #
      # @param cfg [Hash] A hash containing configuration parameters.
      # @option cfg [Symbol] :orm is the ORM to use. Currently, we support two ORMs: +:activerecord+
      #  for Active Record, and +:neo4j+ for the Neo4j graph database.
      #  The default value is +:activerecord+.
      # @option cfg [Symbol, String, Proc] :summary is the summary method to use.
      #  This is a symbol or string containing the name of the method
      #  called by the #box_item_summary method to get the summary for the object.
      #  It can also be a Proc that takes no arguments and returns a string.
      #  Defaults to :title.

      def has_comments(cfg = {})
        # turning on comments requires that the commentable includes the access module

        unless self.include?(Fl::Framework::Access::Access)
          raise "internal error: class #{self.name} must include Fl::Framework::Access::Access to support comments"
        end

        if cfg.has_key?(:summary)
          case cfg[:summary]
          when Symbol, Proc
            @@summary_method = cfg[:summary]
          else
            @@summary_method = :title
          end
        else
          @@summary_method = :title
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

        # This association tracks the comments associated with an object.

        case orm
        when :activerecord
          has_many :comments, as: :commentable, class_name: :'Fl::Framework::Comment::ActiveRecord::Comment', dependent: :destroy
          def build_comment(h)
            Fl::Framework::Comment::ActiveRecord::Comment.new(h)
          end
        when :neo4j
          has_many :in, :comments, rel_class: :'Fl::Framework::Neo4j::Rel::Core::CommentFor', dependent: :destroy
          include Fl::Framework::Neo4j::AssociationProxyCache
          def build_comment(h)
            Fl::Framework::Comment::Neo4j::Comment.new(h)
          end
        end

        unless included(Fl::Framework::Comment::Commentable::InstanceMethods)
          include Fl::Framework::Comment::Commentable::InstanceMethods
        end

        def commentable?
          true
        end

        # register the access checkers

        access_op Fl::Framework::Comment::Commentable::ACCESS_COMMENT_INDEX, :_comment_index_check
        access_op Fl::Framework::Comment::Commentable::ACCESS_COMMENT_CREATE, :_comment_create_check
      end

      # Check if this object manages comments.
      # The default implementation returns +false+; {#has_comments} overrides it to return +true+.
      #
      # @return [Boolean] Returns +true+ if the object manages comments.
        
      def commentable?
        false
      end
    end

    # The methods in this module are installed as instance method of the including class.

    module InstanceMethods
      # Check if this object manages comments.
      # Forwards the call to the class method {Fl::Framework::Comment::Commentable::ClassMethods#commentable?}.
      #
      # @return [Boolean] Returns +true+ if the object manages comments.
        
      def commentable?
        self.class.commentable?
      end

      # Get the object's summary.
      # This method calls the value of the configuration option :summary to #is_boxable to get the
      # object summary.
      #
      # @return [String] Returns the object summary.

      def comment_summary()
        p = self.class.boxable_summary_method
        case p
        when Proc
          p.call()
        when Symbol
          self.send(p)
        when String
          self.send(p.to_sym)
        else
          ''
        end
      end

      # Add a comment.
      # This method creates a new comment owned by _author_ and associated with +self+.
      # If the comment is created, the association proxy cache entry for +:comments+ is cleared, so that
      # the new comment is picked up (this is done for Neo4j only).
      # If the comment creation fails, any errors from the comment object are copied over to +self+,
      # prefixed by the string +comment_+ (for example, a +base+ error in the comment is mapped to
      # +comment_base+ in the commentable).
      #
      # @param author [Object] The comment author, who will be its owner.
      # @param contents [String] The contents of the comment.
      # @param title [String] The title of the comment; if +nil+, the title is extracted from the first
      #  40 text elements of the contents.
      #
      # @return [Object, nil] Returns the new comment if it was created successfully, +nil+ otherwise.

      def add_comment(author, contents, title = nil)
        h = {
          author: author,
          commentable: self,
          contents: contents
        }

        h[:title] = title unless title.nil?

        c = self.class.build_comment(h)
        if c.save
          if self.respond_to?(:clear_association_proxy_cache_entry)
            clear_association_proxy_cache_entry(:comments)
          end
          c
        else
          c.errors.each do |ek, ev|
            self.errors.add("comment_#{ek}", ev)
          end
          nil
        end
      end

      protected

      # The access checker method for +:comment_index+.
      # The default implementation returns the +:read+ permission for _obj_: if _actor_ has read access
      # to the object, it can also list its comments.
      #
      # @param op [Fl::Framework::Access::Access::Checker] The requested operation.
      # @param obj [Object] The target of the request.
      # @param actor [Object] The actor requesting permission.
      # @param context The context in which to do the check.
      #
      # @return [Symbol, nil] Returns a symbol corresponding to the access level granted, or +nil+ if
      #  access was denied.

      def _comment_index_check(op, obj, actor, context = nil)
        obj.permission?(actor, Fl::Framework::Access::Grants::READ, context)
      end

      # The access checker method for +:comment_create+.
      # The default implementation returns the +:read+ permission for _obj_: if _actor_ has read access
      # to the object, it can also add to its comments.
      #
      # @param op [Fl::Framework::Access::Access::Checker] The requested operation.
      # @param obj [Object] The target of the request.
      # @param actor [Object] The actor requesting permission.
      # @param context The context in which to do the check.
      #
      # @return [Symbol, nil] Returns a symbol corresponding to the access level granted, or +nil+ if
      #  access was denied.

      def _comment_create_check(op, obj, actor, context = nil)
        obj.permission?(actor, Fl::Framework::Access::Grants::READ, context)
      end
    end

    # Perform actions when the module is included.
    # - Injects the class methods. Instance methods will be injected if {ClassMethods#has_comments} is called.

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
