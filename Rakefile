task :environment do
  Bundler.require(:default)
  require File.expand_path("../lib/crazyivan", __FILE__)
end

namespace :assets do
  desc 'Precompile assets'
  task :precompile => :environment do
    CrazyIvan.assets.precompile
  end
end
