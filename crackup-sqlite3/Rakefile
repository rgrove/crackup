require 'rubygems'

Gem::manage_gems

require 'rake/gempackagetask'
require 'rake/rdoctask'

spec = Gem::Specification.new do |s|
  s.name             = 'Crackup'
  s.version          = '1.0.0'
  s.author           = 'Ryan Grove'
  s.email            = 'ryan@wonko.com'
  s.homepage         = 'http://wonko.com/software/crackup'
  s.platform         = Gem::Platform::RUBY
  s.summary          = "Crackup is a pretty simple, pretty secure remote " +
                       "backup solution for folks who want to keep their " +
                       "data securely backed up but aren't particularly " +
                       "concerned about bandwidth usage."
  s.files            = FileList['{bin,db,docs,lib,tests}/**/*'].exclude('rdoc').to_a
  s.require_path     = 'lib'
  s.autorequire      = 'crackup'
#  s.test_file        = ''
  s.has_rdoc         = true
  s.extra_rdoc_files = ['README']
  s.add_dependency('sqlite3-ruby', '>= 1.1.0')
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_tar = true
end

Rake::RDocTask.new do |rd|
  rd.main     = 'README'
  rd.title    = 'Crackup Documentation'
  rd.rdoc_dir = 'doc/html'
  rd.rdoc_files.include('README', 'bin/**/*.rb', 'lib/**/*.rb')
end
