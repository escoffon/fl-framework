class TestDatumOne < ApplicationRecord
  # START added by fl:framework:comments generator
  include Fl::Framework::Access::Access unless include?(Fl::Framework::Access::Access)
  # START added by fl:framework:attachments generator
  include Fl::Framework::Attachment::Attachable
  include Fl::Framework::Attachment::ActiveRecord::Attachable
  has_attachments
  # END added by fl:framework:attachments generator
  include Fl::Framework::Comment::Commentable
  include Fl::Framework::Comment::ActiveRecord::Commentable
  has_comments
  # END added by fl:framework:comments generator

  belongs_to :owner, class_name: 'TestActor'

  validates :owner, :title, presence: true

  protected

  def self.default_access_checker(op, obj, actor, context = nil)
    case op.op
    when :read
      :public
    when :write
      (actor.id == obj.owner.id) ? :private : nil
    else
      nil
    end
  end
end
