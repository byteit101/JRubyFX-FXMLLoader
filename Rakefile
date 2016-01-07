#
# To change this template, choose Tools | Templates
# and open the template in the editor.


require 'rubygems'
require 'rake'
require 'rake/clean'
require 'rubygems/package_task'
require 'ant'

build_dir = "build"
file build_dir

task :java_init => build_dir do
  ant.property :name => "src.dir", :value => "src"
  ant.path(:id => "project.class.path") do
    pathelement :location => "classes"
  end
  ant.tstamp
  ant.mkdir(:dir => build_dir)
end

task :compile => :java_init do
  ant.javac(:destdir => build_dir) do
    classpath :refid => "project.class.path"
    src { pathelement :location => "${src.dir}" }
  end
end

desc "Build the Java component"
task :jar => :compile do
  ant.jar :destfile => "lib/FXMLLoader-j8.jar", :basedir => build_dir
end

task :java_clean do
  ant.delete(:dir => build_dir)
  ant.delete(:dir => "pkg")
  ant.delete(:file => "lib/FXMLLoader-j8.jar")
end

task :clean => :java_clean

task :gem => :jar

spec = Gem::Specification.new do |s|
  s.name = 'jrubyfx-fxmlloader'
  s.version = '0.4.1'
  s.platform    = 'java'
  s.has_rdoc = true
  s.extra_rdoc_files = ['README', 'LICENSE']
  s.summary = 'GPL\'d JavaFX FXMLLoder class in Ruby for JRubyFX'
  s.description = "JRubyFX FxmlLoader gem bits"
  s.author = 'Patrick Plenefisch & JRubyFX team & Oracle'
  s.email = 'simonpatp@gmail.com'
  s.homepage = "https://github.com/byteit101/JRubyFX-FXMLLoader"
  # s.executables = ['your_executable_here']
  # manually specify it to avoid globbing issues
  s.files = %w(LICENSE README Rakefile lib/FXMLLoader-j8.jar) + Dir.glob("{bin,lib,spec}/**/*")
  s.require_path = "lib"
  s.bindir = "bin"
  s.license = "GPL-2.0-with-classpath-exception"
end

Gem::PackageTask.new(spec) do |p|
  p.gem_spec = spec
  p.need_tar = true
  p.need_zip = true
end


task :default => :gem
