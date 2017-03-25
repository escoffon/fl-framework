# -*-ruby-*-

Gem::Specification.new do |s|
  s.name        = 'fl-framework'
  s.version     = '0.3.6'
  s.date        = '2017-03-25'
  s.summary     = "Floopstreet application framework"
  s.description = "A gem of framework code for implementing standardized Rails applications."
  s.authors     = [ "Emil Scoffone" ]
  s.email       = 'emil@scoffone.com'
  s.files       = [ 'lib/fl/framework.rb',
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

                    'lib/fl/framework/core/title_management.rb',

                    'lib/fl/framework/paperclip_helper.rb',

                    'lib/fl/framework/rel.rb',
                    'lib/fl/framework/rel/attachment.rb',
                    'lib/fl/framework/rel/attachment/attached_to.rb',
                    'lib/fl/framework/rel/attachment/image_attached_to.rb',
                    'lib/fl/framework/rel/attachment/main_image_attachment_for.rb',

                    'lib/fl/framework/test.rb', 'lib/fl/framework/test/attachment_test_helper.rb',

                    'lib/paperclip_processors/floopnail.rb',

                    'Rakefile',
                    'test/test_classes_helper.rb', 'test/test_access.rb', 'test/test_model_hash.rb',
                    'test/test_attribute_filters.rb',
                    '.yardopts'
                  ]
  s.homepage    = 'http://rubygems.org/gems/fl-framework'
  s.license     = 'MIT'
  s.add_runtime_dependency 'nokogiri', '~> 1.6'
#  s.add_runtime_dependency 'json', '~> 1.8'
end
