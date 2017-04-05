# -*-ruby-*-
#
# Rakefile for the fl-framework gem.

begin
  require 'bundler/setup'
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end

require 'rdoc/task'

RDoc::Task.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'Fl::Framework'
  rdoc.options << '--line-numbers'
  rdoc.rdoc_files.include('README.md')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

#--APP_RAKEFILE = File.expand_path("../test/dummy/Rakefile", __FILE__)
#--load 'rails/tasks/engine.rake'

load 'rails/tasks/statistics.rake'

require 'bundler/gem_tasks'

require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = false
end

desc "Run tests"
task default: :test

require 'fileutils'

namespace :doc do
  task :yard do
    dir = File.join(File.dirname(__FILE__), 'doc/out/yard')
    FileUtils.rm_r(dir) if File.directory?(dir)
    sh('yardoc')
  end
end
