$:.unshift(File.dirname(__FILE__) + '/lib')
require 'omnibus/version'

Gem::Specification.new do |s|
  s.name = 'omnibus'
  s.version = Omnibus::VERSION
  s.platform = Gem::Platform::RUBY
  s.has_rdoc = true
  s.extra_rdoc_files = ["README.md" ]
  s.summary = "Installer builder DSL"
  s.description = s.summary
  s.author = "Opscode"
  s.email = "info@opscode.com"
  s.homepage = "http://wiki.opscode.com/"

  s.add_dependency "mixlib-shellout", "~>1.0"
  s.add_dependency "ohai", ">= 0.6.12"
  s.add_dependency "rake", ">= 0.9"
  s.add_dependency "fpm", "= 0.3.11"
  s.add_dependency "uber-s3"

  %w(rspec).each { |gem| s.add_development_dependency gem }

  s.bindir       = "bin"
  s.executables  = []
  s.require_path = 'lib'
  s.files = %w(README.md) + Dir.glob("lib/**/*")
end
