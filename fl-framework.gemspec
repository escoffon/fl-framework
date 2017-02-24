# -*-ruby-*-

Gem::Specification.new do |s|
  s.name        = 'fl-framework'
  s.version     = '0.1.1'
  s.date        = '2017-02-22'
  s.summary     = "Floopstreet application framework"
  s.description = "A gem of framework code for implementing standardized Rails applications."
  s.authors     = [ "Emil Scoffone" ]
  s.email       = 'emil@scoffone.com'
  s.files       = [ 'lib/fl/framework.rb',
                    'Rakefile',
                    'test/test_usda_nfs.rb',
                    '.yardopts'
                  ]
  s.homepage    = 'http://rubygems.org/gems/fl-framework'
  s.license     = 'MIT'
#  s.add_runtime_dependency 'nokogiri', '~> 1.6'
#  s.add_runtime_dependency 'json', '~> 1.8'
end
