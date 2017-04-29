require 'fl/framework/query'

module Fl::Framework::Attachment
  # Query support for attachments and attachables.
  # This module defines a number of general support methods used by the ORM-specific query functionality.
  #
  # @note The module is currently empty, as all methods originally here were moved to the common query
  #  module {Fl::Framework::Query}. It does, however, include the comon query module.

  module Query
    # Includes the common query method ({Fl::Framework::Query}).
    #
    # @param [Module, Class] base The including module or class.

    def self.included(base)
      base.send(:include, Fl::Framework::Query)
    end
  end
end
