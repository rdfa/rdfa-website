require 'bundler'
require 'fileutils'
$:.unshift(File.expand_path('../lib',  __FILE__))

task :environment do
  Bundler.require(:default)
  require File.expand_path("../lib/crazyivan", __FILE__)
end

namespace :assets do
  desc 'Precompile assets'
  task :precompile => [:environment, :clear] do
    CrazyIvan.assets.precompile
  end
  
  desc 'Clear precompiled assets'
  task :clear do
    Dir.glob('./public/*/application-*.{js,css}').each do |f|
      FileUtils.rm f
    end
  end
end

namespace :earl do
  desc 'Collate reports'
  task :collate => :environment do
    require 'earl'
    earl = EARL.new(Dir.glob(File.expand_path("../earl-reports/*.html", __FILE__)))
    File.open(File.expand_path("../earl-reports/earl.ttl", __FILE__), "w") do |file|
      puts "dump #{earl.graph.count} triples"
      earl.dump(:ttl, file)
    end
  end
end

namespace :cache do
  desc 'Clear document cache'
  task :clear do
    FileUtils.rm_rf File.expand_path("../cache", __FILE__)
  end
end