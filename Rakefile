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
    FileUtils.rm_rf File.expand_path("../manifest.jsonld", __FILE__)
    Dir.glob('./public/*/application-*.{js,css}').each do |f|
      FileUtils.rm f
    end
  end
end

desc 'Generate manifest.json'
task :manifest => :environment do
  require 'crazyivan/core'
  CrazyIvan::StandAlone.new.send(:manifest_json)
end

namespace :earl do
  desc 'Collate reports'
  task :collate => :environment do
    require 'earl'
    puts "parse individual results"
    files = Dir.glob(File.expand_path("../public/earl-reports/*-earl*", __FILE__))
    earl = EARL.new(files)
    File.open(File.expand_path("../public/earl-reports/earl.jsonld", __FILE__), "w") do |file|
      puts "dump #{earl.graph.count} triples to JSON-LD"
      earl.dump(:jsonld, file)
    end
    File.open(File.expand_path("../public/earl-reports/earl.ttl", __FILE__), "w") do |file|
      puts "dump #{earl.graph.count} triples to Turtle"
      earl.dump(:ttl, file)
    end
  end
  
  desc 'Generate comprehensive report'
  task :report do
    require 'earl'
    source_files = Dir.glob(File.expand_path("../public/earl-reports/*-earl*", __FILE__)).map do |f|
      f.split('/').last
    end
    earl_json = File.read(File.expand_path("../public/earl-reports/earl.jsonld", __FILE__))
    File.open(File.expand_path("../public/earl-reports/earl.html", __FILE__), "w") do |file|
      EARL.generate(earl_json, source_files, file)
    end
  end
end

namespace :cache do
  desc 'Clear document cache'
  task :clear do
    FileUtils.rm_rf File.expand_path("../cache", __FILE__)
  end
end