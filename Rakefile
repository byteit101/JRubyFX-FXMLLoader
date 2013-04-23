#
# To change this template, choose Tools | Templates
# and open the template in the editor.


require 'rubygems'
require 'rake'
require 'rake/clean'
require 'rubygems/package_task'

spec = Gem::Specification.new do |s|
  s.name = 'jrubyfx-fxmlloader'
  s.version = '0.0.1'
  s.has_rdoc = true
  s.extra_rdoc_files = ['README', 'LICENSE']
  s.summary = 'GPL\'d JavaFX FXMLLoder class in Ruby for JRubyFX'
  s.description = s.summary
  s.author = 'Patrick Plenefisch & JRubyFX team & Oracle'
  s.email = 'simonpatp@gmail.com'
  # s.executables = ['your_executable_here']
  s.files = %w(LICENSE README Rakefile) + Dir.glob("{bin,lib,spec}/**/*")
  s.require_path = "lib"
  s.bindir = "bin"
end

Gem::PackageTask.new(spec) do |p|
  p.gem_spec = spec
  p.need_tar = true
  p.need_zip = true
end
