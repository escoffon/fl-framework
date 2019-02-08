module Fl::Framework::List
  # Extension module for use by objects that can be placed in lists.

  module Listable
    # Class methods for listable objects.
    # {ClassMethods#is_listable} is used to indicate that instances of the class can be placed in lists.
    
    module ClassMethods
      # Add listable behavior to a model.
      # A listable model can be added to one or more lists, which it tracks through a `has_many`
      # association named **containers**, which is defined in the body of this method.
      # Therefore, if a model is defined like this:
      #
      # ```
      #   class MyListable < ActiveRecord::Base
      #     is_listable
      #   end
      # ```
      #
      # then instances of `MyListable` include an association named **containers**.
      #
      # This method also includes {Fl::Framework::List::Listable::InstanceMethods} in the calling
      # class. Those instance methods assume that the **containers** association is defined (which
      # it will be).
      #
      # @param [Hash] cfg A hash containing configuration parameters.
      #  The following key/value pairs are supported:
      #
      #  - **:summary** The summary method to use. This is a symbol or string containing the name
      #    of the method called by the {Fl::Framework::List::Listable::InstanceMethods#list_item_summary}
      #    method to get the summary for the object.
      #    It can also be a Proc that takes no arguments and returns a string.
      #    Defaults to **:title**.

      def is_listable(cfg = {})
        if cfg.has_key?(:summary)
          case cfg[:summary]
          when Symbol, Proc
            self.class_variable_set(:@@summary_method, cfg[:summary])
          when String
            self.class_variable_set(:@@summary_method, cfg[:summary].to_sym)
          else
            self.class_variable_set(:@@summary_method, :title)
          end
        else
          self.class_variable_set(:@@summary_method, :title)
        end

        self.instance_eval do
          def listable_summary_method
            self.class_variable_get(:@@summary_method)
          end
        end
        
        # This association tracks the lists (containers) to which this listable object belongs

        has_many :containers, :class_name => 'Fl::Framework::List::ListItem', :as => :listed_object,
      		:dependent => :destroy

        include Fl::Framework::List::Listable::InstanceMethods

        after_save :refresh_object_summaries
      end
    end

    # Instance methods for listable objects.
    # These methods are injected into the class by {ClassMethods#is_listable} and implement functionality
    # to manage list behavior.
    
    module InstanceMethods
      # Check if this model is listable.
      #
      # @return [Boolean] Returns @c true if the model is listable.
      
      def listable?
        true
      end

      # Get the object's summary.
      # This method calls the value of the configuration option **:summary** to
      # {Fl::Framework::List::Listable::InstanceMethods#is_listable} to get the
      # object summary.
      #
      # @return [String] Returns the object summary.

      def list_item_summary()
        p = self.class.listable_summary_method
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

      # Get the lists to which this object belongs.
      # This method is a wrapper around the **containers** assocation.
      #
      # @param [Boolean] reload If `true`, reload the **:containers** association.
      #
      # @return [Array<Fl::Framework::List::List>] Returns an array containing the lists to which
      #  the object beloangs.

      def lists(reload = false)
        self.containers.reload if reload
        self.containers.map { |lo| lo.list }
      end
          
      # Add the object to a list.
      # This method first checks if the object is already in the list, and if not it creates a
      # Fl::Framework::List::ListItem that places it in the list.
      #
      # @param list [Fl::Framework::List::List] The list to which to add `self`; if `self` is already in
      #  *list*, ignore the request.
      # @param owner [Object] The owner of the Fl::Framework::List::ListItem that is potentially created;
      #  if `nil`, use the owner of *list*.
      # @param reload [Boolean] If `true`, the **:containers** association is reloaded so that its state
      #  is consistent with the request.
      #
      # @return [Fl::Framework::List::ListItem,nil] If the object is added to *list*, returns the newly
      #  created instance of Fl::Framework::List::ListItem. Otherwise, returns `nil`.

      def add_to_list(list, owner = nil, reload = false)
        l = Fl::Framework::List::ListItem.find_listable_in_list(self, list)
        if l.nil?
          nowner = (owner) ? owner : list.owner
          li = Fl::Framework::List::ListItem.new(:list => list, :listed_object => self, :owner => nowner)
          if li.save
            # we reload the list objects so that they are in sync with the new state of the object.
            # This is an addtional query that we strictly don't need, but it adds consistency to the API

            self.containers.reload if reload

            li
          else
            nil
          end
        else
          nil
        end
      end

      # Remove the object from a list.
      #
      # @param list [Fl::Framework::List::List] The list from which to remove `self`; if `self` is not
      #  in *list*, ignore the request.
      #
      # @return [Boolean] Returns `true` if the object was removed, `false` otherwise.

      def remove_from_list(list)
        li = Fl::Framework::List::ListItem.query_for_listable_in_list(self, list).first
        if li.nil?
          false
        else
          self.containers.delete(li)
          true
        end
      end

      private

      # Refresh the denormalized object_summary attribute in the list items for this listable.

      def refresh_object_summaries()
        Fl::Framework::List::ListItem.refresh_item_summaries(self)
      end
    end

    # Perform actions when the module is included.
    #
    # - Injects the class methods, to make {ClassMethods#is_listable} available. The instance methods
    #   are injected by {ClassMethods#is_listable}.

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

class ActiveRecord::Base
  # Backstop listable checker.
  # This is the default implementation, which returns `false`, for those models that have not
  # registered as listables.
  #
  # @return [Boolean] Returns `false`; {Fl::Framework::List::Listable::ClassMethods#is_listable} overrides
  #  the implementation to return `true`.
  
  def listable?
    false
  end

  # Backstop list item summary extractor.
  # This is the default implementation, which returns an empty string, for those models that have not
  # registered as listables.
  #
  # @return [String] Returns an empty string; {Fl::Framework::List::Listable::ClassMethods#is_listable}
  #  overrides the implementation to return an appropriate value for the item summary.

  def list_item_summary
    ''
  end

  include Fl::Framework::List::Listable
end
