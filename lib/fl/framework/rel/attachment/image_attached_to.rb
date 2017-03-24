# Neo4j::ActiveRel implementation of the +IMAGE_ATTACHED_TO+ relationship.
# This relationship is used to associate an attachment containing image data with its master object.
# The end node is the master object, and the start node is the attachment.
# Start nodes are {Fl::Attachment::Image} instances, and end nodes are typically {Fl::Asset::Base}
# instances, but this is not enforced.
#
# === Properties
# No properties defined.

class Fl::Framework::Rel::Attachment::ImageAttachedTo
  include Neo4j::ActiveRel

  from_class :'Fl::Framework::Attachment::Neo4j::Image'
  to_class   :any
  type 'IMAGE_ATTACHED_TO'

  validate :_check_end_node

  private

  def _check_end_node
  end
end
