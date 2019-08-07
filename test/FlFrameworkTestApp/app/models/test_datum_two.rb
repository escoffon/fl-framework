# TestDatumTwo is a listable asset with custom methods; the listable and asset support is turned on off-class

class TestDatumTwo < ApplicationRecord
  include Fl::Framework::Core::ModelHash
  include Fl::Framework::Access::Target

  belongs_to :owner, class_name: 'TestActor'

  validates :owner, :title, :value, presence: true

  protected

  def my_title()
    "my title: #{self.title}"
  end

  def my_owner()
    self.owner
  end

  def my_owner=(o)
    self.owner = o
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

# just for fun (and for testing), make the class listable after the definition

Fl::Framework::List::Helper.make_listable(TestDatumTwo, summary: :my_title)

# and similarly make it an asset

Fl::Framework::Asset::Helper.make_asset(TestDatumTwo, owner: :my_owner)
