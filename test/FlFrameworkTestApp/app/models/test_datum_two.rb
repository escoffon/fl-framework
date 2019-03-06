class TestDatumTwo < ApplicationRecord
  include Fl::Framework::Core::ModelHash

  # this model is listable

  is_listable summary: :my_title

  belongs_to :owner, class_name: 'TestActor'

  validates :owner, :title, :value, presence: true

  protected

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
