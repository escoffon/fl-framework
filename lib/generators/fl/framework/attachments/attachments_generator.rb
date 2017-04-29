module Fl::Framework
  class AttachmentsGenerator < Rails::Generators::Base
    source_root File.expand_path('../templates', __FILE__)

    argument :attachable_class, type: :string, default: 'Attachable'

    def create_paperclip_initializer
      name = 'fl_attachments.rb'
      outfile = File.join(destination_root, 'config', 'initializers', name)
      if File.exists?(outfile)
        say_status('skipped', "The Paperclip attachments initializer file already exists: #{outfile}")
      else
        say_status('create', "Creating Paperclip attachments initializer file")
        say_status('', "You will have to modify it as described in the file")
        template(name, outfile)
      end
    end

    def create_controller_file
      outfile = File.join(destination_root, 'app', 'controllers', attachable_class.underscore + '_attachments_controller.rb')
      if File.exists?(outfile)
        say("error: controller file exists: #{outfile}")
        exit(1)
      end

      h = _split_class_name(attachable_class)
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

      say_status('create', "Creating attachments controller for #{attachable_class}")
      say_status('', 'The attachable class will have to be modified to add access checks for the')
      say_status('', 'attachment operations :attachment_index and :attachment_create.')
      template('controller.rb', outfile)
    end

    def add_route
      h = _split_class_name(attachable_class)
      resource_name = h[:class_name].underscore

      route_file = 'config/routes.rb'
      line = nil

      if File.exist?(route_file)
        line = _find_line(route_file, "resources :#{resource_name.pluralize}")
        if line
          # this could be a simple resources rule, so we need to create the block.
          # We assume that the 'resources :campgrounds' is in a logical location (nested inside its modules)

          if line =~ /do\s*$/
            # Since we have a block, just append the partial route, but let's check if it seems to be
            # already there...

            t = _find_line(route_file, "controller: '#{resource_name}_attachments'")
            if t
              say_status('skipped', "there already seems to be a nested :attachments resource for :#{resource_name.pluralize}")
              say_status('', "Will not insert the following routing rule:")
              say_status('', "#{_partial_route()}")
            else
              say_status('modify', "inserting nested :attachments resource after '#{line.strip}'")
              _insert_after_line(route_file, line, _taboffset(_tab(line), <<EOS
  # START added by fl:framework:attachments generator
  #{_partial_route()}
  # END added by fl:framework:attachments generator
EOS
                                                              ))
            end
          else
            # OK not a block: replace it

            say_status('modify', "replacing routing rule '#{line.strip}' with a nested resource rule")
            _replace_line(route_file, line, _taboffset(_tab(line), <<EOS
#{line.chomp.strip} do
  # START added by fl:framework:attachments generator
  #{_partial_route()}
  # END added by fl:framework:attachments generator
end
EOS
                                                       ))
          end
        else
          line = _find_line(route_file, ".routes.draw do")
          if line
            say_status('modify', "inserting :#{resource_name.pluralize} routing rule after '#{line.strip}'")
            tab = _tab(line) + '  '
            _insert_after_line(route_file, line, _taboffset(tab, <<EOS
# START added by fl:framework:attachments generator
#{_full_route().chomp}
# END added by fl:framework:attachments generator
EOS
                                                            ) + "\n")
          else
            say_status('skipped', 'config.routes does not seem to contain a route definition block')
          end
        end
      else
        say_status('skipped', "config/routes.rb was not found.")
        say_status('', "Add the following to your route file:\n#{_full_route()}")
      end
    end

    def enable_attachments
      h = _split_class_name(attachable_class)

      outfile = File.join('app/models', attachable_class.underscore + '.rb')
      if File.exists?(outfile)
        line = _find_line(outfile, "has_attachments")
        if line
          say_status('skipped', "The class #{attachable_class} seems to have already enabled attachments")
        else
          line = _find_line(outfile, "include Fl::Framework::Access::Access")
          if line
              say_status('modify', "Adding attachment support to #{attachable_class}")
              tab = _tab(line)
              _insert_after_line(outfile, line, _taboffset(tab, <<EOS
# START added by fl:framework:attachments generator
include Fl::Framework::Attachment::Attachable
include Fl::Framework::Attachment::ActiveRecord::Attachable
has_attachments
# END added by fl:framework:attachments generator
EOS
                                                           ))
          else
            line = _find_line(outfile, "class #{attachable_class} ")
            if line
              say_status('modify', "Adding attachment support to #{attachable_class}")
              say_status('', "This will enable the Access package, which you will likely have to customize") 
              tab = _tab(line)
              _insert_after_line(outfile, line, _taboffset(tab, <<EOS
  # START added by fl:framework:attachments generator
  include Fl::Framework::Access::Access unless include?(Fl::Framework::Access::Access)
  include Fl::Framework::Attachment::Attachable
  include Fl::Framework::Attachment::ActiveRecord::Attachable
  has_attachments
  # END added by fl:framework:attachments generator
EOS
                                                           ) + "\n")
            else
              say_status('skipped', "Could not find a class definition for #{attachable_class}.")
              say_status('',
                         "To enable attachments, add the following to the class definition of #{attachable_class}:")
              say_status('', '  include Fl::Framework::Access::Access')
              say_status('', '  include Fl::Framework::Attachment::Attachable')
              say_status('', '  include Fl::Framework::Attachment::ActiveRecord::Attachable')
              say_status('', '  has_attachments')
            end
          end
        end
      else
        say_status('skipped', "Could not find a model file for #{attachable_class}")
        say_status('',
                   "To enable attachments, add the following to the class definition of #{attachable_class}:")
        say_status('', '  include Fl::Framework::Access::Access')
        say_status('', '  include Fl::Framework::Attachment::Attachable')
        say_status('', '  include Fl::Framework::Attachment::ActiveRecord::Attachable')
        say_status('', '  has_attachments')
      end
    end

    private

    def _tab(line)
      (line =~ /^\s+/) ? Regexp.last_match[0] : ''
    end

    def _taboffset(t, s)
      sl = s.split("\n").map { |l| "#{t}#{l}" }
      sl.join("\n") + "\n"
    end

    def _split_class_name(cname)
      parts = cname.split('::')
      {
        full_class_name: attachable_class,
        class_name: parts.pop,
        module_name: parts.join('::'),
        modules: parts
      }
    end

    def _find_line(filename, str)
      match = false

      File.open(File.join(destination_root, filename)) do |f|
        f.each_line do |line|
          if line =~ /(#{Regexp.escape(str)})/i
            match = line
          end
        end
      end
      match
    end

    def _insert_after_line(filename, line, str)
      gsub_file filename, /(#{Regexp.escape(line)})/i do |match|
        "#{match}#{str}"
      end
    end

    def _replace_line(filename, line, str)
      gsub_file filename, /(#{Regexp.escape(line)})/i do |match|
        "#{str}"
      end
    end

    def _full_route
      h = _split_class_name(attachable_class)
      resource_name = h[:class_name].underscore

      route = ''
      tab = 0

      h[:modules].each do |p|
        route << sprintf("%#{tab}snamespace :%s do\n", '', p.underscore)
        tab += 2
      end

      route << sprintf("%#{tab}sresources :%s do\n", '', resource_name.pluralize)
      tab += 2
      route << sprintf("%#{tab}sresources :attachments, only: [ :index, :create ], controller: '%s_attachments'\n",
                       '', resource_name)
      tab -= 2
      route << sprintf("%#{tab}send\n", '')

      h[:modules].each do |p|
        tab -= 2
        route << sprintf("%#{tab}send\n", '')
      end

      route
    end

    def _partial_route
      h = _split_class_name(attachable_class)
      resource_name = h[:class_name].underscore

      sprintf("resources :attachments, only: [ :index, :create ], controller: '%s_attachments'", resource_name)
    end
  end
end

