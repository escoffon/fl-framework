require 'test_helper'
require 'generators/js_assets/js_assets_generator'

module Fl::Framework
  class JsAssetsGeneratorTest < Rails::Generators::TestCase
    tests JsAssetsGenerator
    destination Rails.root.join('tmp/generators')
    setup :prepare_destination

    # test "generator runs without errors" do
    #   assert_nothing_raised do
    #     run_generator ["arguments"]
    #   end
    # end
  end
end
