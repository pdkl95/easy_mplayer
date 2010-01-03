require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "easy_mplayer"
    gem.summary = "Wrapper to launch and control MPlayer"
    gem.description = "A wrapper to manage mplayer, that supports callbacks to easyily support event-driven GUIs"
    gem.email = "gem-mplayer@thoughtnoise.net"
    gem.homepage = "http://github.com/pdkl95/easy_mplayer"
    gem.authors = ["Brent Sanders"]
    gem.add_runtime_dependency "color_debug_messages", ">= 1.1.2"
    gem.add_runtime_dependency "facets", ">= 2.8.0"
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "easy_mplayer #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
