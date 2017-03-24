module Fl::Framework
  # Helper methods for Paperclip.

  module PaperclipHelper
    # Convert a URL returned by Paperclip so that it is valid.
    # Paperclip 4.x URL encodes the ? in the URl to %3F, and that royally screws up the
    # clients, which don't expect URL-encoded values. I'm not even sure that the URL encoding
    # is a good idea here.
    # So, we roll it back out.
    #
    # Note that 4.3 has fixed this problem. I guess people agreed with me that this behavior was
    # not correct. Therefore, this function is no longer needed, but after all the work I did to
    # put it in, I'll leave the calls in, just in case...
    #
    # @param url [String] The URL to convert.
    #
    # @return [String, nil] The converted URL, or +nil+ if _url_ is nil.

    def self.convert_paperclip_url(url)
      if url.nil?
        url
      else
        url.gsub('%3F', '?').gsub('%3f', '?')
      end
    end

    # Convert a URL returned by Paperclip so that it is valid.
    # See {Fl::Framework::PaperclipHelper.convert_paperclip_url}.
    #
    # @param url [String] The URL to convert.
    #
    # @return [String, nil] The converted URL, or +nil+ if _url_ is nil.

    def convert_paperclip_url(url)
      Fl::Framework::PaperclipHelper.convert_paperclip_url(url)
    end
  end
end
