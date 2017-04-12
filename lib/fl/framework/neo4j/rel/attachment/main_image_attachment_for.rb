# Neo4j::ActiveRel implementation of the +MAIN_IMAGE_ATTACHMENT_FOR+ relationship.
# This relationship is used to mark an attachment containing image data as the master' main image.
# The end node is the master object, and the start node is the attachment.
# Start nodes are {Fl::Attachment::Image} instances, and end nodes are typically {Fl::Asset::Base}
# instances, but this is not enforced.
#
# === Properties
# No properties defined.

class Fl::Framework::Neo4j::Rel::Attachment::MainImageAttachmentFor
  include Neo4j::ActiveRel

  from_class :'Fl::Framework::Attachment::Neo4j::Image'
  to_class   :any
  type 'MAIN_IMAGE_ATTACHMENT_FOR'

  validate :_check_end_node

  private

  def _check_end_node
  end
end
