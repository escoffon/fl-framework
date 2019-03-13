module Fl::Framework
  class AssetsGenerator < Rails::Generators::Base
    include Fl::Framework::GeneratorHelper
    
    desc <<-DESC
  This generator installs support for asset management.
  It copies the assets migration files to the application's db/migrations directory,
  including the file to create the table that manages access control for assets.

  For example, given this command:
    rails generate fl:framework:assets

  The generator will create:
    db/migrate TS_create_fl_framework_assets.fl_framework.rb
    db/migrate TS_create_fl_framework_asset_access.fl_framework.rb
  where TS is a timestamp.
DESC

    PWD = File.expand_path('.')
    DB_MIGRATE = File.expand_path('../../../../../../db/migrate', __FILE__)
    MIGRATION_FILE_NAMES = [ 'create_fl_framework_assets', 'create_fl_framework_asset_access' ]
    
    source_root File.expand_path('../templates', __FILE__)

    def create_migration_files
      MIGRATION_FILE_NAMES.each { |fn| create_migration_file(DB_MIGRATE, fn) }
    end
  end
end
