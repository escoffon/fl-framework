# -*-ruby-*-

Gem::Specification.new do |s|
  s.name        = 'fl-framework'
  s.version     = '0.2.3'
  s.date        = '2017-03-15'
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
                    'Rakefile',
                    'test/test_classes_helper.rb', 'test/test_access.rb', 'test/test_model_hash.rb',
                    '.yardopts'
                  ]
  s.homepage    = 'http://rubygems.org/gems/fl-framework'
  s.license     = 'MIT'
#  s.add_runtime_dependency 'nokogiri', '~> 1.6'
#  s.add_runtime_dependency 'json', '~> 1.8'
end
