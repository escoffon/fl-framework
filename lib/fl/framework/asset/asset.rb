module Fl::Framework::Asset
  # Extension module for use by objects to declare that they are assets.

  module Asset
    # Class macros for assets.
    # {ClassMacros#is_asset} is used to indicate that instances of the class should register with the
    # asset system.
    
    module ClassMacros
      # Add asset behavior to a model.
      # An asset model creates a corresponding {Fl::Framework::Asset::AssetRecord} instance to register
      # with the asset system.
      #
      # This method includes {Fl::Framework::Asset::Asset::InstanceMethods} in the calling
      # class. Those instance methods provide functionality used by asset instances.
      #
      # @param [Hash] cfg A hash containing configuration parameters.
      #  The following key/value pairs are supported:
      #
      #  - **:owner** The method that returns the owner of the asset.
      #    EMIL I need to figure this out.
      
      def is_asset(cfg = {})
        if cfg.has_key?(:owner)
          case cfg[:owner]
          when Symbol, Proc
            self.class_variable_set(:@@_owner_method, cfg[:owner])
          when String
            self.class_variable_set(:@@_owner_method, cfg[:owner].to_sym)
          else
            self.class_variable_set(:@@_owner_method, :_builtin_owner)
          end
        else
          self.class_variable_set(:@@_owner_method, :_builtin_owner)
        end

        self.instance_eval do
          def listable_summary_method
            self.class_variable_get(:@@summary_method)
          end
        end
        
        has_one :asset_record, class_name: 'Fl::Framework::Asset::AssetRecord', as: :asset,
      		dependent: :destroy

        include Fl::Framework::Asset::Asset::InstanceMethods

        after_create :create_active_record
      end
    end

    # Instance methods for asset objects.
    # These methods are injected into the class by {ClassMacros#is_asset} and implement functionality
    # to manage asset behavior.
    
    module InstanceMethods
      # Check if this model is an asset.
      #
      # @return [Boolean] Returns `true` if the model is an asset.
      
      def asset?
        true
      end

      protected

      # Callback after an instance is created.
      # This method registers with the asset system by creating a {Fl::Framework::Asset::AssetRecord}.

      def create_active_record()
        ap = Fl::Framework::Asset::AssetRecord.create(asset: self, owner: self.owner)
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
  # Backstop asset checker.
  # This is the default implementation, which returns `false`, for those models that have not
  # registered as assets.
  #
  # @return [Boolean] Returns `false`; {Fl::Framework::Asset::Asset::ClassMacros#is_asset} overrides
  #  the implementation to return `true`.
  
  def asset?
    false
  end
end
