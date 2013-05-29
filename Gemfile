source "https://rubygems.org/"

gem 'sparql'
gem 'linkeddata'
gem 'equivalent-xml'
gem 'rake'
gem 'haml'
gem 'json'
gem 'sinatra'
gem 'rdf-rdfa', :git => "git://github.com/ruby-rdf/rdf-rdfa.git", :require => 'rdf/rdfa'
gem 'json-ld', :git => "git://github.com/ruby-rdf/json-ld.git", :require => 'json/ld'
gem 'sinatra-simple-assets', :require => 'sinatra/simple_assets'
gem 'sinatra-respond_to', :require => 'sinatra/respond_to'
gem 'sinatra-browserid', :git => "git://github.com/gkellogg/sinatra-browserid.git", :require => 'sinatra/browserid'
gem 'rack-cache', :require => 'rack/cache'
gem 'curb'

# Bundle gems for the local environment. Make sure to
# put test-only gems in this group so their generators
# and rake tasks are available in development mode:
group :development, :test do
  gem 'shotgun'
  gem "wirble"
  gem "syntax"
  gem "debugger", :platforms => :mri_19
end
