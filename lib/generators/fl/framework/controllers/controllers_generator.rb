module Fl::Framework
  class ControllersGenerator < Rails::Generators::Base
    CONTROLLERS = [ 'attachments', 'comment_attachments', 'comments' ]

    desc <<-DESC
  This generator installs a copy of standard framework controllers into an
  application's app/controllers folder. You can then modify the controllers
  as needed, for example to add authentication hooks, or to reroot them with
  the applications ApplicationController, rather than the framework's.

  Note that the generated controller will likely still need to be modified,
  for example to add authentication checks.

  For example:
    rails generate fl:framework:controllers -c=comments,attachments

  The generator will create:
    app/controllers/fl/framework/comments_controller.rb
    app/controllers/fl/framework/attachments_controller.rb
DESC

    source_root File.expand_path('../../../../../../app/controllers/fl/framework', __FILE__)

    class_option :controllers, aliases: "-c", type: :array,
    	desc: "Select specific controllers to generate (#{CONTROLLERS.join(', ')})"

    def create_controllers
      controllers = options[:controllers] || CONTROLLERS
      controllers.each do |name|
        target = "app/controllers/fl/framework/#{name}_controller.rb"
        outfile = File.join(destination_root, target)
        if File.exists?(outfile)
          say_status('skipped', "controller file exists: #{outfile}")
        else
          template("#{name}_controller.rb", outfile)
        end
      end
    end
  end
end
