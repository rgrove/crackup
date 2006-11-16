require 'rubygems'

Gem::manage_gems

require 'rake/gempackagetask'
require 'rake/rdoctask'

spec = Gem::Specification.new do |s|
  s.name     = 'crackup'
  s.version  = '1.0.1'
  s.author   = 'Ryan Grove'
  s.email    = 'ryan@wonko.com'
  s.homepage = 'http://wonko.com/software/crackup'
  s.platform = Gem::Platform::RUBY
  s.summary  = "Crackup is a pretty simple, pretty secure remote backup " +
               "solution for folks who want to keep their data securely " +
               "backed up but aren't particularly concerned about bandwidth " +
               "usage."

  s.files        = FileList['{bin,lib}/**/*', 'LICENSE', 'HISTORY'].exclude('rdoc').to_a
  s.executables  = ['crackup', 'crackup-restore']
  s.require_path = 'lib'
  s.autorequire  = 'crackup'

  s.has_rdoc         = true
  s.extra_rdoc_files = ['README', 'LICENSE']
  
  s.required_ruby_version = '>= 1.8.4'
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_tar = true
end

Rake::RDocTask.new do |rd|
  rd.main     = 'README'
  rd.title    = 'Crackup Documentation'
  rd.rdoc_dir = 'doc/html'
  rd.rdoc_files.include('README', 'bin/**/*', 'lib/**/*.rb')
end
