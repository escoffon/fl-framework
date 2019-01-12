module Fl::Framework::Attachment
  # Namespace for ActiveStorage support.

  module ActiveStorage
  end
end

require 'fl/framework/attachment/active_storage/macros'
require 'fl/framework/attachment/active_storage/validation'

module Fl::Framework::Attachment
  module ActiveStorage

    # Perform actions when the module is included.
    # - Includes {Fl::Framework::Attachment::ActiveStorage::Macros} and
    #   {Fl::Framework::Attachment::ActiveStorage::Validation}

    def self.included(base)
      base.include Macros
      base.include Validation
    end
  end
end
