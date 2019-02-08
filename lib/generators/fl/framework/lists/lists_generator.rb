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
    MIGRATION_FILE_NAME = 'create_fl_framework_lists'
    
    source_root File.expand_path('../templates', __FILE__)

    def create_migration_file
      now = Time.new
      ts = now.strftime('%Y%m%d%H%M%S')
      
      in_name, in_file = find_migration_file(DB_MIGRATE, MIGRATION_FILE_NAME)
      if in_name.nil?
        say_status('error', 'could not find the template migration file')
      else
        out_dir = File.join(destination_root, 'db', 'migrate')
        out_name, out_file = find_migration_file(out_dir, "#{MIGRATION_FILE_NAME}.fl_framework")
        if out_name
          say_status('warn', "migration file exists: #{File.basename(out_file)}")
        else
          out_file = File.join(out_dir, "#{ts}_#{in_name}.fl_framework.rb")
          say_status('create', "Creating migration file #{File.basename(out_file)}")
          self.class.source_root File.expand_path(DB_MIGRATE)
          copy_file(in_file, out_file)
        end
      end
    end

    private

    def find_migration_file(d, n)
      migration_file_re = Regexp.new("[0-9]+_(#{n}).rb$")
      name = nil
      infile = nil
      curdir = Dir.getwd
      Dir.chdir(d)
      Dir.glob('*.rb') do |fn|
        if fn =~ migration_file_re
          name = Regexp.last_match[1]
          infile = fn
          break
        end
      end
      Dir.chdir(curdir)

      [ name, infile ]
    end
  end
end
