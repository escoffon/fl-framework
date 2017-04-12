module Fl::Framework::Core
  # Helper methods for HTML processing.

  module HtmlHelper
    # Strip dangerous elements from HTML content.
    # This method parses the value and:
    #
    # - Removes any <script> elements.
    # - Removes any <object> elements.
    # - Converts any urls in <a> to #, unless they use the HTTP/HTTPS scheme.
    # - Converts any urls in <img> to an empty string, unless they use the HTTP/HTTPS scheme..
    #
    # @param value [String] The initial value.
    #
    # @return [String] Returns the value, where all dangerous elements have been stripped as described above.

    def self.strip_dangerous_elements(value)
      if value.nil? || (value.length < 1)
        value
      else
        doc = Nokogiri::HTML(value)
        doc.search('script').each { |e| e.remove }
        doc.search('object').each { |e| e.remove }
        doc.search('a').each do |e|
          e['href'] = '#' unless (e['href'] =~ /^https?:/i) || (e['href'] =~ /^\//)
        end
        doc.search('img').each do |e|
          e['src'] = '' unless (e['src'] =~ /^https?:/i) || (e['src'] =~ /^\//)
        end
        b = doc.search('body')
        s = ''
        b[0].children.each { |e| s << e.serialize }
        s
      end
    end

    # Extract text from HTML content.
    # This method parses the value and concatenates the values of the text nodes.
    #
    # @param value [String] The initial value.
    # @param [Number] maxlen The maximum number of characters to extract. Defaults to all characters.
    #
    # @return [String] Returns the value, where all HTML tags have been stripped (well, technically,
    #  where all text nodes have been concatenated).

    def self.text_only(value, maxlen = nil)
      if value.nil? || (value.length < 1)
        value
      else
        doc = Nokogiri::HTML(value)
        b = doc.search('body')
        s = ''
        b[0].search('text()').each do |e|
          break if maxlen.is_a?(Numeric) && (s.length >= maxlen)
          s << e.serialize
        end

        # one last tweak: convert &amp;, &gt;, and &lt; back to the actual characters

        s = convert_character_entities(s)

        (maxlen.is_a?(Numeric) && (s.length > maxlen)) ? s[0,maxlen] : s
      end
    end

    # Convert (some) XML/HTML character entities to text.
    # This method converts +&amp;+, +&gt;+, and +&lt;+ back to the characters +&+, +>+, and +<+.
    #
    # @param t [String] The text to convert.
    #
    # @return [String] Returns a string where the character entities +&amp;+, +&gt;+, and +&lt+; have been
    #  converted back to characters.

    def self.convert_character_entities(t)
      t.gsub('&amp;', '&').gsub('&lt;', '<').gsub('&gt;', '>')
    end
  end
end
