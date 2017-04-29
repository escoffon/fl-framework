module Fl::Framework::Test
  # Helper functions for testing attachments.

  module AttachmentTestHelper
    # Create an upload file parameter.
    # The return value can be passed to model constructors or updaters as the value of Paperclip attachments.
    #
    # @param path [String] The path to the file.
    # @param content_type [String] The file's content type; if passed as +nil+, the method uses the
    #  +mimemagic+ gem to sniff out the content type from the file contents (not from the extension!).
    # @param binary [Boolean] Passed to the Rack::Test::UploadedFile constructor.
    #
    # @return [Rack::Test::UploadedFile] Returns an instance of Rack::Test::UploadedFile, which is eventually
    #  converted to a ActionDispatch::Http::UploadedFile, which is what Paperclip expects.
    #
    # @example 

    def self.make_uploaded_file(path, content_type = nil, binary = false)
      if content_type.nil?
        File.open(path) { |f| content_type = MimeMagic.by_magic(f).type }
      end

      Rack::Test::UploadedFile.new(path, content_type, binary)
    end
  end
end

