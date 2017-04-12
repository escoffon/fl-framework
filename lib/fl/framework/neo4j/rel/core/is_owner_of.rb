# A Neo4j::ActiveRel class to encapsulate a +IS_OWNER_OF+ relationship.
# This relationship indicates that the start node owns the end node; currently ownership is associated
# with users, so the start node's type could be {Fl::Core::User}, but we set it to {Fl::Core::Actor} for
# generality. The end node type is undefined.
#
# === Properties
# This relationship defines no properties.

class Fl::Framework::Neo4j::Rel::Core::IsOwnerOf
  include Neo4j::ActiveRel

  before_save :_check_rel
  validate :_owned_object

  from_class :any
  to_class   :any
  type 'IS_OWNER_OF'

  # only one IS_OWNER_OF relationship is allowed per object/user
  creates_unique

  private

  def _owned_object
    errors.add(:to_node) unless to_node.respond_to?(:owners) || to_node.respond_to?(:owner)
  end

  def _check_rel
  end
end
