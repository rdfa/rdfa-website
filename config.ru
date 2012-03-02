#!/usr/bin/env rackup
$:.unshift(File.expand_path('../lib',  __FILE__))

require 'rubygems' || Gem.clear_paths
require 'bundler'
Bundler.require(:default)

require 'rack/cache'
require 'crazyivan'

set :environment, (ENV['RACK_ENV'] || 'production').to_sym

if settings.environment == :production
  puts "Mode set to #{settings.environment.inspect}, logging to sinatra.log"
  log = File.new('sinatra.log', 'a')
  STDOUT.reopen(log)
  STDERR.reopen(log)
else
  puts "Mode set to #{settings.environment.inspect}, logging to console"
end

#use Rack::Cache,
#  :verbose     => true,
#  :metastore   => "file:" + File.expand_path("../cache/meta", __FILE__),
#  :entitystore => "file:" + File.expand_path("../cache/body", __FILE__)

disable :run, :reload

run CrazyIvan
