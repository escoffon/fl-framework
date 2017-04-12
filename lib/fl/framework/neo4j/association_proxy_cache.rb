module Fl::Framework::Neo4j
  # Add methods for managing the association proxy cache in a Neo4j::ActiveNode.
  # This module registers instance methods to manage the association proxy cache a bit more granularly than
  # the ones provided by Neo4j::ActiveNode (or at least, they provide a less verbose API).

  module AssociationProxyCache
    # The methods in this module will be installed as class methods of the including class.

    module ClassMethods
    end

    # The methods in this module will be installed as instance methods of the including class.

    module InstanceMethods
      # Clear the entry in the association proxy cache for a given association.
      #
      # @param name [String, Symbol] The association name.

      def clear_association_proxy_cache_entry(name)
        if respond_to?(:association_proxy_cache) && respond_to?(:association_proxy_hash)
          association_proxy_cache.delete(association_proxy_hash(name))
        end
      end
    end

    # Perform actions when the module is included.
    # - Insures that the including class has also included Neo4j::ActiveNode.
    # - Injects the class and instance methods.

    def self.included(base)
      raise "#{base.name} must include Neo4j::ActiveNode" unless base.include?(Neo4j::ActiveNode)

      base.extend ClassMethods

      base.instance_eval do
      end

      base.class_eval do
        include InstanceMethods
      end
    end
  end
end
