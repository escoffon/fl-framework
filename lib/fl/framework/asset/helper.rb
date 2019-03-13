module Fl::Framework::Asset
  # Helpers for the asset module.
  
  module Helper
    # Enable asset support for a class.
    # Use this method to add asset support to an existing class:
    #
    # ```
    # class TheClass < ActiveRecord::Base
    #   # class definition
    # end
    #
    # Fl::Framework::Asset::Helper.make_asset(TheClass, owner: :my_owner_method)
    # ```
    #
    # @param klass [Class] The class object where asset support is enabled.
    # @param cfg [Hash] A hash containing configuration parameters. See the documentation for
    #  {Fl::Framework::Asset::Asset::ClassMacros.is_asset}.

    def self.make_asset(klass, *cfg)
      klass.send(:include, Fl::Framework::Asset::Asset)
      klass.send(:is_asset, *cfg)
    end
  end
end
