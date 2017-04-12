# Neo4j::ActiveRel implementation of the +COMMENT_FOR+ relationship.
# The start node is a {Fl::Framework::Comment::Comment::Neo4j}; the end node should include the
# {Fl::Framework::Comment::Commentable} module.
# 
# This relationship is used to associate a comment with an object.
#
# === Properties
# Currently no properties are defined; the creation time in the comment node is used as a timestamp for
# the relationship.

class Fl::Framework::Neo4j::Rel::Core::CommentFor
  include Neo4j::ActiveRel

  validate :_validate_commentable

  from_class :'Fl::Framework::Comment::Comment::Neo4j'
  to_class   :any
  type 'COMMENT_FOR'

  private

  def _validate_commentable
    n = self.to_node
    if !n.class.include?(Fl::Framework::Comment::Commentable)
      self.errors.add(:to_node, I18n.tx('fl.framework.comment.comment.relationship.validate.not_commentable',
                                        n.class.name))
    elsif !n.respond_to?(:comments)
      self.errors.add(:to_node, I18n.tx('fl.framework.comment.comment.relationship.validate.no_comments',
                                        n.class.name))
    end
  end
end
