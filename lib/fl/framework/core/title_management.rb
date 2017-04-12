module Fl::Framework::Core
  # Extension module to mix in title management functionality.

  module TitleManagement
    # The methods in this module will be installed as class methods of the including class.

    module ClassMethods
    end

    # The methods in this module are installed as instance method of the including class.

    module InstanceMethods
      protected

      # Populate an empty title from the contents of another attribute.
      # This method checks if the +:title+ attribute is empty, and if so populates it with the first +len+
      # characters of another attribute.
      #
      # @param attr_name [Symbol] The name of the other attribute.
      # @param len [Integer] The number of characters to extract.

      def populate_title_if_needed(attr_name, len = 40)
        title = self.read_attribute(:title)
        if title.nil? || (title.length < 1)
          write_attribute(:title, extract_title(read_attribute(attr_name), len))
        end
      end

      # Extract a title from HTML contents.
      #
      # @param contents [String] A string containing the contents from which to extract the title.
      # @param max [Integer] The maximum number of characters in the title.
      #
      # @return [String] Returns a string that contains the text nodes of +contents+, up to the first
      #  +max+ characters.

      def extract_title(contents, max = 40)
        return '' unless contents

        doc = Nokogiri::HTML(contents)
        doc.search('script').each { |e| e.remove }
        b = doc.search('body')
        return '' unless b[0]
        s = ''
        b[0].search('text()').each do |e|
          s << e.serialize
          if s.length > max
            break
          end
        end

        if s.length > max
          s = s[0, max] + '...'
        end

        s
      end
    end

    # Perform actions when the module is included.
    # - Injects the class and instance methods.

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
