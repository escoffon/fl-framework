module Fl::Framework::Service
  # Namespace for service objects for attachments.
  # Attachment service objects come in Active Record and Neo4j implementations.

  module Attachment
  end
end

require 'fl/framework/attachment/active_record'
require 'fl/framework/service/attachment/active_record'
if Module.const_defined?('Neo4j')
  require 'fl/framework/service/attachment/neo4j'
end
