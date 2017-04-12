module Fl::Framework::Neo4j::Rel
  # Namespace for Neo4j relationship classes related to attachments.

  module Attachment
  end
end

require 'fl/framework/neo4j/rel/attachment/attached_to'
require 'fl/framework/neo4j/rel/attachment/image_attached_to'
require 'fl/framework/neo4j/rel/attachment/main_image_attachment_for'
