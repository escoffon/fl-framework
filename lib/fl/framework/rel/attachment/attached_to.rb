# Neo4j::ActiveRel implementation of the +ATTACHED_TO+ relationship.
# This relationship is used to associate an attachment with its master object.
# The end node is the master object, and the start node is the attachment.
# Start nodes are {Fl::Attachment::Base} instances, and end nodes are typically {Fl::Asset::Base}
# instances, but this is not enforced.
#
# === Properties
# - *attachment_type* is a string containing the type of attachment; for example, Fl::Attachment::Image
#   registers as a +image+ type.

class Fl::Framework::Rel::Attachment::AttachedTo
  include Neo4j::ActiveRel

  from_class :'Fl::Framework::Attachment::Neo4j::Base'
  to_class   :any
  type 'ATTACHED_TO'

  # @return The attachment type.
  property :attachment_type, type: String

  before_validation :_set_attachment_type

  validates_presence_of :attachment_type
  validate :_check_end_node

  private

  def _check_end_node
  end

  def _set_attachment_type
    self.attachment_type = self.from_node.attachment_type if self.from_node
  end
end
