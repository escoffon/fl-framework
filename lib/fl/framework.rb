# The top-level Floopstreet module; provides the root namespace for Floopstreet code.

module Fl
  # The namespace for Floopstreet framework code.

  module Framework
  end
end

require 'fl/framework/access'
require 'fl/framework/service'
require 'fl/framework/controller'
require 'fl/framework/model_hash'
require 'fl/framework/attachment'
require 'fl/framework/paperclip_helper'
require 'fl/framework/attribute_filters'
require 'fl/framework/html_helper'
require 'fl/framework/test'
