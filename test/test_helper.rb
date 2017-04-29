# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require File.expand_path("../../test/dummy/config/environment.rb", __FILE__)
ActiveRecord::Migrator.migrations_paths = [File.expand_path("../../test/dummy/db/migrate", __FILE__)]
#ActiveRecord::Migrator.migrations_paths << File.expand_path('../../db/migrate', __FILE__)
require "rails/test_help"

# Filter out Minitest backtrace while allowing backtrace from other libraries
# to be shown.
Minitest.backtrace_filter = Minitest::BacktraceFilter.new


# Load fixtures from the engine
if false && ActiveSupport::TestCase.respond_to?(:fixture_path=)
  ActiveSupport::TestCase.fixture_path = File.expand_path("../fixtures", __FILE__)
  ActionDispatch::IntegrationTest.fixture_path = ActiveSupport::TestCase.fixture_path
  ActiveSupport::TestCase.file_fixture_path = ActiveSupport::TestCase.fixture_path + "/files"
  ActiveSupport::TestCase.fixtures :all
end

# I18n load paths

root = File.dirname(File.dirname(__FILE__))
I18n.load_path += Dir[File.join(root, 'config', 'locales', 'fl', 'framework', '*.{rb,yml}').to_s]

class ApplicationController
  def current_user()
    print("++++++++++ current_user\n")
    nil
  end
end

module Fl::Framework::Test
  # Utilities for testing.
  # This module is included by both {TestCase} and {ControllerTestCase}, so if the test cases are
  # subclasses of either class, there is no need to include it.

  module Extensions
    # The methods in this module are installed as class methods of the including class.

    module ClassMethods
    end

    # The methods in this module are installed as class methods of the including class.

    module InstanceMethods
      # Get object identifiers.
      # Given an array of objects or hashes in _ol_, map it to an array of object identifiers.
      #
      # @param [Array<Object,Hash>] ol An array of objects or hashes.
      #
      # @return [Array<Number,nil>] Returns an array whose elements are the identifiers for the
      #  corresponding elements in _ol_. Elements in _ol_ that don't have an identifier are mapped to +nil+.

      def obj_ids(ol)
        ol.map do |o|
          case o
          when Hash
            (o[:id]) ? o[:id] : o['id']
          else
            (o.respond_to?(:id)) ? o.id : nil
          end
        end
      end
    end

    # Loads the class and instance methods.

    def self.included(base)
      base.extend ClassMethods

      base.instance_eval do
      end

      base.class_eval do
        include InstanceMethods
      end
    end
  end
end

module Fl::Framework::Test
  # Base class for Fl::Framework tests (non-controller).

  class TestCase < ActiveSupport::TestCase
    include Fl::Framework::Test::Extensions
#    include FactoryGirl::Syntax::Methods

    setup do
    end

    teardown do
    end
  end

  # Base class for Fl::Framework controller tests.

  class ControllerTestCase < ActionDispatch::IntegrationTest
    include Fl::Framework::Test::Extensions
#    include FactoryGirl::Syntax::Methods

    setup do
    end

    teardown do
    end
  end
end
