# -*-ruby-*-

$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "fl/framework/version"

Gem::Specification.new do |s|
  s.name        = 'fl-framework'
  s.platform    = Gem::Platform::RUBY
  s.version     = Fl::Framework::VERSION
  s.date        = Fl::Framework::DATE
  s.authors     = [ "Emil Scoffone" ]
  s.email       = [ 'emil@scoffone.com' ]
  s.homepage    = 'https://github.com/escoffon/fl-framework'
  s.summary     = "Floopstreet application framework"
  s.description = "A gem of framework code for implementing standardized Rails applications."
  s.license     = 'MIT'

  #-- s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  #-- s.files         = `git ls-files`.split("\n")
  #-- s.test_files    = `git ls-files -- test/*`.split("\n")
  s.files       = [ 'lib/fl/framework.rb',
                    'lib/fl/framework/icalendar.rb', 'lib/fl/framework/time_zone.rb',

                    'lib/fl/framework/access.rb', 'lib/fl/framework/access/access.rb',
                    'lib/fl/framework/access/grants.rb',
                    'lib/fl/framework/controller.rb', 'lib/fl/framework/controller/access.rb',
                    'lib/fl/framework/controller/csrf.rb', 'lib/fl/framework/controller/helper.rb',
                    'lib/fl/framework/controller/status_error.rb',
                    'lib/fl/framework/model_hash.rb',
                    'lib/fl/framework/service.rb', 'lib/fl/framework/service/base.rb',
                    'lib/fl/framework/visibility.rb',

                    'lib/fl/framework/attachment.rb', 'lib/fl/framework/attachment/configuration.rb',
                    'lib/fl/framework/attachment/active_record.rb',
                    'lib/fl/framework/attachment/active_record/base.rb',
                    'lib/fl/framework/attachment/active_record/registration.rb',
                    'lib/fl/framework/attachment/neo4j.rb',
                    'lib/fl/framework/attachment/neo4j/base.rb', 'lib/fl/framework/attachment/neo4j/image.rb',
                    'lib/fl/framework/attachment/neo4j/master.rb',
                    'lib/fl/framework/attachment/neo4j/registration.rb',

                    'lib/fl/framework/attribute_filters.rb', 'lib/fl/framework/html_helper.rb',

                    'lib/fl/framework/core.rb', 'lib/fl/framework/core/title_management.rb',

                    'lib/fl/framework/paperclip_helper.rb',

                    'lib/fl/framework/neo4j.rb',
                    'lib/fl/framework/neo4j/rel.rb',
                    'lib/fl/framework/neo4j/rel/attachment.rb',
                    'lib/fl/framework/neo4j/rel/attachment/attached_to.rb',
                    'lib/fl/framework/neo4j/rel/attachment/image_attached_to.rb',
                    'lib/fl/framework/neo4j/rel/attachment/main_image_attachment_for.rb',

                    'lib/fl/framework/test.rb', 'lib/fl/framework/test/attachment_test_helper.rb',

                    'lib/paperclip_processors/floopnail.rb',

                    'test/test_helper.rb', 'test/test_classes_helper.rb',
                    'test/fl/icalendar_test.rb',
                    'test/fl/access_test.rb', 'test/fl/model_hash_test.rb', 'test/fl/attribute_filters_test.rb',

                    '.yardopts',

                    'Rakefile', 'MIT-LICENSE', 'README.md'
                  ]

  s.add_runtime_dependency "rails", "~> 5.0"
  s.add_runtime_dependency "railties"
  s.add_runtime_dependency "paperclip", "~> 5.0"
  s.add_runtime_dependency 'loofah', '~> 2.2'
  s.add_runtime_dependency 'mimemagic', '~> 0.3'
  s.add_runtime_dependency 'fl-google'
  s.add_runtime_dependency 'pg'
  
  s.add_development_dependency "sqlite3"
  s.add_development_dependency 'rspec-rails'
  s.add_development_dependency "factory_bot_rails"
end
