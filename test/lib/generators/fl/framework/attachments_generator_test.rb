require 'test_helper'
require 'generators/attachments/attachments_generator'

module Fl::Framework
  class AttachmentsGeneratorTest < Rails::Generators::TestCase
    tests AttachmentsGenerator
    destination Rails.root.join('tmp/generators')
    setup :prepare_destination

    # test "generator runs without errors" do
    #   assert_nothing_raised do
    #     run_generator ["arguments"]
    #   end
    # end
  end
end
