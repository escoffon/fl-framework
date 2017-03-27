module Fl::Framework::Test
  # Helper functions for testing attachments.

  module AttachmentTestHelper
    # Create an upload file parameter.
    # The return value can be passed to model constructors or updaters as the value of Paperclip attachments.
    #
    # @param path [String] The path to the file.
    # @param name [String] The name of the submission parameter, which will be placed in the
    #  +Content-Disposition+ header.
    #
    # @return [ActionDispatch::Http::UploadedFile] Returns an instance of ActionDispatch::Http::UploadedFile,
    #  which is what Paperclip expects.

    def self.make_uploaded_file(path, name = 'image')
      basename = File.basename(path)
      extension = File.extname(path).downcase
      case extension
      when '.jpg'
        type = 'image/jpeg'
      when '.gif'
        type = 'image/gif'
      when '.png'
        type = 'image/png'
      end
      tfile = File.open(path, 'rb')
      ActionDispatch::Http::UploadedFile.new({
                                               :filename => basename,
                                               :type => type,
                                               :head => "Content-Disposition: form-data; name=\"#{name}\"; filename=\"#{basename}\"\r\nContent-Type: #{type}\r\n",
                                               :tempfile => tfile
                                             })
    end
  end
end

