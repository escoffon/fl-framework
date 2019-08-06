# This class is marked as an actor

class TestActor < ApplicationRecord
  include Fl::Framework::Core::ModelHash
  include Fl::Framework::Actor::Actor
  include Fl::Framework::Access::Actor

  is_actor title: :my_name
  
  validates :name, presence: true

  # This is for testing the actor API

  def my_name()
    self.name
  end
  
  protected
  
  def to_hash_options_for_verbosity(actor, verbosity, opts)
    if (verbosity != :id) && (verbosity != :ignore)
      {
        :include => [ :name ]
      }
    else
      {}
    end
  end

  def to_hash_local(actor, keys, opts = {})
    to_hash_opts = opts[:to_hash] || {}

    rv = {
    }
    keys.each do |k|
      rv[k] = self.send(k) if self.respond_to?(k)
    end

    rv
  end
end
