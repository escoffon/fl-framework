module Fl::Framework
  class AttachmentClassGenerator < Rails::Generators::Base
    TEMPLATES = {
      'ar:image': [ 'image.rb', 'Active Record image attachment stores any image/* type' ]
    }

    tlist = (TEMPLATES.keys.map { |tk| "			# #{tk} (#{TEMPLATES[tk][1]})" }).join("\n")
    desc <<-DESCD
  This generator creates an attachment model file from a standard template.
  You can then modify the model file as needed, for example to enable delayed
  processing of Paperclip image attachments.

  Arguments:
    ATTACHMENT_CLASS	# The name of the model class to generate.

    TEMPLATE_NAME	# The template to use; one of:
#{tlist}

  For example:
    rails generate MyApp::Attachment::Image ar:image

  The generator will create a model file that implements Paperclip image
  storage in Active Record:
    app/models/my_app/attachment/image.rb
DESCD

    source_root File.expand_path('../templates', __FILE__)

    argument :attachment_class, type: :string, desc: '  The name of the attachment class to generate'

    d = <<-DESCT
  The name of the template to use.
  Available templates: #{TEMPLATES.keys.join(', ')}.
DESCT
    argument :template_name, type: :string, desc: d

    def create_controller_file
      tk = template_name.to_sym
      unless TEMPLATES.has_key?(tk)
        say_status('error', "unknown template name: #{template_name}")
        exit(1)
      end

      outfile = File.join(destination_root, 'app', 'models', attachment_class.underscore + '.rb')
      if File.exists?(outfile)
        say_status('skipped', "attachment model file exists: #{outfile}")
      else
        h = _split_class_name(attachment_class)
        @full_class_name = h[:full_class_name]
        @class_name = h[:class_name]
        @module_name = h[:module_name]
        if @module_name.length > 0
          @open_module = "module #{@module_name}"
          @close_module = 'end'
        else
          @open_module = ''
          @close_module = ''
        end
        @label = @class_name.underscore

        say_status('create', "Creating attachment model for #{attachment_class}")
        template(TEMPLATES[tk][0], outfile)
      end
    end

    private

    def _split_class_name(cname)
      parts = cname.split('::')
      {
        full_class_name: cname,
        class_name: parts.pop,
        module_name: parts.join('::'),
        modules: parts
      }
    end
  end
end

