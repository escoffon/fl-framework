module Fl::Framework
  # The namespace module for comment framework code.

  module Comment
  end
end

require 'fl/framework/comment/query'
require 'fl/framework/comment/commentable'
require 'fl/framework/comment/common'
require 'fl/framework/comment/helper'
if defined?(ActiveRecord)
  require 'fl/framework/comment/active_record'
end
if defined?(Neo4j)
  require 'fl/framework/comment/neo4j'
end
