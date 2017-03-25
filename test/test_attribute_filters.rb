require 'minitest/autorun'
require 'nokogiri'
require 'fl/framework'
  
class AttributeFilterTest < Minitest::Test
  def test_html_helper_text_only
    html = '<p>This is HTML</p>'
    assert_equal 'This is HTML', Fl::Framework::HtmlHelper.text_only(html)

    html = '<p>This <i>is</i> <b>more <i>complex</i> HTML</b</p>'
    assert_equal 'This is more complex HTML', Fl::Framework::HtmlHelper.text_only(html)

    html = '<p>This <i>is</i> <a href="foo">a <i>link</i></a> in HTML</p>'
    assert_equal 'This is a link in HTML', Fl::Framework::HtmlHelper.text_only(html)

    html = '<p>This is HTML</p>'
    assert_equal 'This', Fl::Framework::HtmlHelper.text_only(html, 4)

    html = '<p>This <i>is</i> <b>more <i>complex</i> HTML</b></p>'
    assert_equal 'This is more c', Fl::Framework::HtmlHelper.text_only(html, 14)

    html = '<p>This <i>is</i> <a href="foo">a <i>link</i></a> in HTML</p>'
    assert_equal 'This is a li', Fl::Framework::HtmlHelper.text_only(html, 12)
  end

  def test_html_helper_strip
    html = '<p>This is HTML</p>'
    assert_equal html, Fl::Framework::HtmlHelper.strip_dangerous_elements(html)

    html = '<p>This <i>is</i> <b>more <i>complex</i> HTML</b></p>'
    assert_equal html, Fl::Framework::HtmlHelper.strip_dangerous_elements(html)

    html = '<p>This <i>is</i> <a href="foo">a <i>link</i></a> in HTML</p>'
    assert_equal '<p>This <i>is</i> <a href="#">a <i>link</i></a> in HTML</p>', Fl::Framework::HtmlHelper.strip_dangerous_elements(html)

    html = '<p>This <i>is</i> <a href="/foo">a <i>link</i></a> in HTML</p>'
    assert_equal html, Fl::Framework::HtmlHelper.strip_dangerous_elements(html)

    html = '<p>This <i>is</i> <a href="http://foo">a <i>link</i></a> in HTML</p>'
    assert_equal html, Fl::Framework::HtmlHelper.strip_dangerous_elements(html)

    html = '<p>This <i>is</i> <a href="https://foo">a <i>link</i></a> in HTML</p>'
    assert_equal html, Fl::Framework::HtmlHelper.strip_dangerous_elements(html)

    html = '<p>Link: <a href="foo"><img src="bar"></a> here</p>'
    assert_equal '<p>Link: <a href="#"><img src=""></a> here</p>', Fl::Framework::HtmlHelper.strip_dangerous_elements(html)

    html = '<p>Link: <a href="/foo"><img src="/bar"></a> here</p>'
    assert_equal html, Fl::Framework::HtmlHelper.strip_dangerous_elements(html)

    html = '<p>Link: <a href="http://foo"><img src="https://bar"></a> here</p>'
    assert_equal html, Fl::Framework::HtmlHelper.strip_dangerous_elements(html)

    html = '<p>Link: <a href="https://foo"><img src="http://bar"></a> here</p>'
    assert_equal html, Fl::Framework::HtmlHelper.strip_dangerous_elements(html)

    html = '<p>Script: <script type="text/javascript">script contents</script> here</p>'
    assert_equal '<p>Script:  here</p>', Fl::Framework::HtmlHelper.strip_dangerous_elements(html)

    html = '<p>Script: <script>script contents</script> here</p>'
    assert_equal '<p>Script:  here</p>', Fl::Framework::HtmlHelper.strip_dangerous_elements(html)

    html = '<p>Object: <object type="text/javaobject">object contents</object> here</p>'
    assert_equal '<p>Object:  here</p>', Fl::Framework::HtmlHelper.strip_dangerous_elements(html)

    html = '<p>Object: <object>object contents</object> here</p>'
    assert_equal '<p>Object:  here</p>', Fl::Framework::HtmlHelper.strip_dangerous_elements(html)
  end
end
