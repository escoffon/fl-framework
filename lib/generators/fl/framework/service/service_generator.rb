module Fl::Framework
  class ServiceGenerator < Rails::Generators::Base
    include Fl::Framework::GeneratorHelper
    
    desc <<-DESC
  This generator installs a starting service implementation file in the
  application's app/services folder. You can then modify the service
  as needed, for example to manage the whitelist of allowed parameters.
  The genertor also installs in app/controllers a sample controller that
  uses the service object.

  It takes two mandatory arguments:
    SERVICE_CLASS	The name of the service class to generate.
    MODEL_CLASS         The name of the associated model class.

  For example, given this command:
    rails generate fl:framework:service My:Service::Component My::Component

  The generator will create:
    app/services/my/service/component.rb
    app/controllers/my/components_controller-sample.rb
DESC

    source_root File.expand_path('../templates', __FILE__)

    argument :service_class, type: :string, default: 'Service'
    argument :data_class, type: :string, default: 'Data'

    def create_service_file
      @service_c = split_class_name(service_class)
      @data_c = split_class_name(data_class)

      outfile = File.join(destination_root, 'app', 'services', service_class.underscore + '.rb')
      say_status('create', "Creating service class #{service_class} for #{data_class}")
      template('service.rb', outfile)

      dc = [ @data_c[:module_name], @data_c[:plural_name] ].join('::')
      outfile = File.join(destination_root, 'app', 'controllers', dc.underscore + '_controller-sample.rb')
      template('sample_controller.rb', outfile)
    end

    private
  end
end
