class TestDatumTwo < ApplicationRecord
  include Fl::Framework::Core::ModelHash
  
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

  # this model is listable

  is_listable summary: :my_title

  belongs_to :owner, class_name: 'TestActor'

  validates :owner, :title, :value, presence: true

  protected

  def self.default_access_checker(op, obj, actor, context = nil)
    # temporary until we work out the new access code
    :public
    # case op.op
    # when :read
    #   :public
    # when :write
    #   (actor.id == obj.owner.id) ? :private : nil
    # else
    #   nil
    # end
  end

  def my_title()
    "my title: #{self.title}"
  end
  
  def to_hash_options_for_verbosity(actor, verbosity, opts)
    if (verbosity != :id) && (verbosity != :ignore)
      if verbosity == :minimal
        {
          :include => [ :title, :value ]
        }
      else
        {
          :include => [ :owner, :title, :value ]
        }
      end
    else
      {}
    end
  end

  def to_hash_local(actor, keys, opts = {})
    to_hash_opts = opts[:to_hash] || {}

    rv = {
    }
    keys.each do |k|
      case k.to_sym
      when :owner
        if self.owner
          o_opts = to_hash_opts_with_defaults(to_hash_opts[:owner], { verbosity: :minimal })
          rv[:owner] = self.owner.to_hash(actor, o_opts)
        else
          rv[:owner] = nil
        end
      else
        rv[k] = self.send(k) if self.respond_to?(k)
      end
    end

    rv
  end
end
