module Fl::Framework::Comment
  # The namespace module for ActiveRecord-specific comment framework code.

  module ActiveRecord
  end
end

require 'fl/framework/comment/active_record/commentable'
require 'fl/framework/comment/active_record/comment'
