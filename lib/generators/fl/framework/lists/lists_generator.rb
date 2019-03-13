module Fl::Framework
  class ListsGenerator < Rails::Generators::Base
    include Fl::Framework::GeneratorHelper
    
    desc <<-DESC
  This generator installs support for list objects.
  It copies the lists migration file to the application's db/migrations directory.

  For example, given this command:
    rails generate fl:framework:lists

  The generator will create:
    db/migrate TS_create_fl_framework_lists.fl_framework.rb
  where TS is a timestamp.
DESC

    PWD = File.expand_path('.')
    DB_MIGRATE = File.expand_path('../../../../../../db/migrate', __FILE__)
    MIGRATION_FILE_NAMES = [ 'create_fl_framework_lists' ]
    
    source_root File.expand_path('../templates', __FILE__)

    def create_migration_files
      MIGRATION_FILE_NAMES.each { |fn| create_migration_file(DB_MIGRATE, fn) }
    end
  end
end
