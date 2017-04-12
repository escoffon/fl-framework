require 'test_helper'
require 'generators/comments/comments_generator'

module Fl::Framework
  class CommentsGeneratorTest < Rails::Generators::TestCase
    tests CommentsGenerator
    destination Rails.root.join('tmp/generators')
    setup :prepare_destination

    # test "generator runs without errors" do
    #   assert_nothing_raised do
    #     run_generator ["arguments"]
    #   end
    # end
  end
end
