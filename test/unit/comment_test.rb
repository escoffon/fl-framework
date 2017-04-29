require 'test_helper'

module Fl::Framework::Test
  class CommentTest < TestCase
    def make_actors()
      a1 = TestActor.new(name: 'A1')
      assert a1.save

      a2 = TestActor.new(name: 'A2')
      assert a2.save

      a3 = TestActor.new(name: 'A3')
      assert a3.save

      a4 = TestActor.new(name: 'A4')
      assert a4.save

      [ a1, a2, a3, a4 ]
    end

    test 'create' do
      a1, a2 = make_actors()

      d1 = TestDatumOne.new(owner: a1, title: 'D1')
      assert d1.save

      c1 = d1.add_comment(a1, 'C1 - A1')
      assert c1
      assert_equal 'C1 - A1', c1.title
      assert_equal 1, d1.comments.order('created_at DESC').to_a.count
      assert_equal c1.fingerprint, d1.comments.order('created_at DESC').first.fingerprint
      assert_equal a1.fingerprint, c1.author.fingerprint

      c2 = d1.add_comment(a2, 'C2 - A2')
      assert c2
      assert_equal 'C2 - A2', c2.title
      d1.reload
      assert_equal 2, d1.comments.order('created_at DESC').to_a.count
      assert_equal c2.fingerprint, d1.comments.order('created_at DESC').first.fingerprint
      assert_equal a2.fingerprint, c2.author.fingerprint
    end
  end
end
