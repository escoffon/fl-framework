module Fl::Framework::Service
  # Namespace for service objects for comments.
  # Comment service objects come in Active Record and Neo4j implementations.

  module Comment
  end
end

require 'fl/framework/service/comment/active_record'
if Module.const_defined?('Neo4j')
  require 'fl/framework/service/comment/neo4j'
end
