module Fl
  module Framework
    class ApplicationRecord < ActiveRecord::Base
      self.abstract_class = true
    end
  end
end
