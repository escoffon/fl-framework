module Fl::Framework::Attachment
  # Namespace for attachments on Active Record objects.

  module ActiveRecord
  end
end

require 'fl/framework/attachment/active_record/registration'
require 'fl/framework/attachment/active_record/attachable'
require 'fl/framework/attachment/active_record/base'
require 'fl/framework/attachment/active_record/image'
