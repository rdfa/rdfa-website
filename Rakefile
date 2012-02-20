require 'bundler'
require 'fileutils'

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

namespace :cache do
  desc 'Clear document cache'
  task :clear do
    FileUtils.rm_rf File.expand_path("../cache", __FILE__)
  end
end