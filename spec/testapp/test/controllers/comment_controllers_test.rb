require 'test_helper'

class CommentControllersTest < Fl::Framework::Test::ControllerTestCase
  #  include Fl::Framework::Engine.routes.url_helpers

  # At some point we'll integrate with FactoryGirl

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

  def make_data()
    a1, a2, a3, a4 = make_actors()

    d1 = TestDatumOne.new(owner: a1, title: 'D1')
    d1_c1_a1 = d1.add_comment(a1, 'D1 - C1 - A1')
    d1_c2_a2 = d1.add_comment(a2, 'D1 - C2 - A2')
    d1_c3_a1 = d1.add_comment(a1, 'D1 - C3 - A1')
    d1_c4_a4 = d1.add_comment(a4, 'D1 - C4 - A4')

    d2 = TestDatumOne.new(owner: a2, title: 'D2')
    d2_c1_a2 = d2.add_comment(a2, 'D2 - C1 - A2')
    d2_c2_a4 = d2.add_comment(a4, 'D2 - C2 - A4')
    d2_c3_a3 = d2.add_comment(a3, 'D2 - C3 - A3')
    d2_c4_a4 = d2.add_comment(a4, 'D2 - C4 - A4')

    [ d1, d2 ]
  end

  setup do
#    @comment = fl_framework_comments(:one)
  end

  test 'index' do
    d1, d2 = make_data()

    print("++++++++++ #{test_datum_one_comments_url(d1)}\n")
    get test_datum_one_comments_url(d1, format: :json)
    assert_response :success
  end
end
