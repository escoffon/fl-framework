require 'test_helper'

require 'fl/framework/attachment'

class AttachOne < Fl::Framework::Attachment::ActiveRecord::Base
  register_mime_types 'application/x-attach-one' => :activerecord
end

module Fl::Framework::Test
  class AttachmentTest < TestCase
    test 'class_registry' do
      cr = Fl::Framework::Attachment::ClassRegistry.registry
      assert cr
      
      k = cr.lookup('application/x-attach-one')
      assert_equal AttachOne, k
    end
  end
end
