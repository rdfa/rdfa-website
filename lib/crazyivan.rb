require 'linkeddata'
require 'sparql'
require 'sinatra'
require 'sinatra/respond_to'
require 'sinatra/browserid'
require 'sinatra/sparql'
require 'digest/sha1'
require 'crazyivan/core'
require 'crazyivan/extensions'

module CrazyIvan
  HOSTNAME = (ENV['hostname'] || 'rdfa.info').freeze

  class Application < Sinatra::Base
    include Core

    configure do
      register Sinatra::RespondTo
      register Sinatra::BrowserID
      register Sinatra::SPARQL
      register Sinatra::SimpleAssets

      enable :sessions
      set :session_secret, "xyzzy"
      set :sessions, true
      set :app_name, "The RDFa Test Harness"
      set :public_folder, File.expand_path('../../public',  __FILE__)
      set :views, File.expand_path('../views',  __FILE__)
      set :browserid_login_button, :grey

      mime_type :sparql, "application/sparql-query"
      mime_type :ttl, "text/turtle"
      mime_type :rdf, "application/rdf+xml"

      assets do
        css :application, [
          '/stylesheets/bootstrap.css',
          '/stylesheets/application.css'
        ]
        js :application, [
          '/javascripts/underscore-1.3.1.js',
          '/javascripts/backbone-0.9.1.js',
          '/javascripts/bootstrap-2.0.1.js',
          '/javascripts/bootstrap-alert.js',
          '/javascripts/bootstrap-button.js',
          '/javascripts/bootstrap-dropdown.js',
          '/javascripts/bootstrap-modal.js',
          '/javascripts/models/test-model.js',
          '/javascripts/models/version-model.js',
          '/javascripts/views/details-view.js',
          '/javascripts/views/earl-view.js',
          '/javascripts/views/host-language-view.js',
          '/javascripts/views/processor-view.js',
          '/javascripts/views/progress-view.js',
          '/javascripts/views/run-all-view.js',
          '/javascripts/views/source-view.js',
          '/javascripts/views/test-view.js',
          '/javascripts/views/unauthorized-view.js',
          '/javascripts/views/version-view.js',
          '/javascripts/application.js'
        ]
      end
    end

    before do
      puts "[#{request.path_info}], " +
           "#{params.inspect}, " +
           "#{format}, " +
           "#{request.accept.inspect}, " +
           "#{authorized? ? Digest::SHA1.hexdigest(authorized_email) : 'unauthorized'}"
    end

    get '/test-suite' do
      redirect '/test-suite/'
    end

    get '/test-suite/' do
      cache_control :private
      locals = { :email => (authorized_email if authorized?)}
      haml :test_suite, :locals => locals
    end
    
    get '/test-suite/logout' do
      logout!
      redirect '/test-suite/'
    end

    ##
    # Return a representation of the manifest
    # Format is determined by content-negotiation
    #
    # We consider JavaScript and JSON to just return JSON-LD
    get '/test-suite/manifest' do
      format :json if format == :js
      settings.sparql_options.replace(
        :standard_prefixes => true,
        :prefixes => {
          :test => "http://www.w3.org/2006/03/test-description#",
          :rdfatest => "http://#{HOSTNAME}/vocabs/rdfa-test#"
        }
      )
      cache_control :public, :must_revalidate, :max_age => 3600
      respond_to do |wants|
        wants.ttl do
          etag Digest::SHA1.hexdigest manifest_ttl
          manifest_ttl
        end
        wants.json do
          etag Digest::SHA1.hexdigest manifest_json
          manifest_json
        end
        wants.html do
          etag Digest::SHA1.hexdigest graph.dump(:ntriples)
          graph
        end
      end
    end

    # Alternative access to specific version/host language manifests
    # Always return Turtle representation
    get "/test-suite/:version/:suite/manifest" do
      format :ttl
      
      cache_control :public, :must_revalidate, :max_age => 3600
      etag Digest::SHA1.hexdigest manifest_ttl
      manifest_ttl(params[:version], params[:suite])
    end

    ##
    # Return processor definitions
    get '/test-suite/processors' do
      cache_control :public, :must_revalidate, :max_age => 3600
      json = File.read(File.expand_path("../../processors.json", __FILE__))
      etag Digest::SHA1.hexdigest json
      respond_to do |wants|
        wants.json { json }
      end
    end

    ##
    # Return version definitions
    get '/test-suite/versionNames' do
      cache_control :public, :must_revalidate, :max_age => 3600
      json = File.read(File.expand_path("../../versionNames.json", __FILE__))
      etag Digest::SHA1.hexdigest json
      respond_to do |wants|
        wants.json { json }
      end
    end

    ##
    # Writes a test case document for the given URL.
    get '/test-suite/test-cases/:version/:suite/:num' do
      cache_control :public, :must_revalidate, :max_age => 3600

      begin
        content = get_test_content(params[:version], params[:suite], params[:num], format.to_s);
        etag Digest::SHA1.hexdigest(content)
        content
      rescue Exception => e
        puts "error: #{e.message}\n#{e.backtrace.join("\n")}"
        puts e.backtrace if settings.environment != :production
        [404, "#{e.message}\n#{e.backtrace.join("\n")}"]
      end
    end

    ##
    # Writes the test case alternatives for the given URL
    get '/test-suite/test-cases/:num' do
      format :json if format == :js
      cache_control :public, :must_revalidate, :max_age => 3600
      etag Digest::SHA1.hexdigest(manifest_ttl + params[:num])

      test_cases = get_test_alternates(params[:num])
      respond_to do |wants|
        wants.html do
          haml :test_cases, :format => :html5, :locals => {:test_cases => test_cases, :num => params["num"]}
        end
        wants.json do
          test_cases.to_json
        end
      end
    end
  
    # Check a particular unit test
    get '/test-suite/check-test/:version/:suite/:num' do
      params["rdfa-extractor"] ||= "http://www.w3.org/2012/pyRdfa/extract?format=xml&uri="
      params["expected-results"] ||= 'true'
      expected_results = params["expected-results"] == 'true'
      format :json if format == :js

      return [403, "Unauthorized access is not allowed"] unless authorized?

      begin
        if perform_test_case(params[:version], params[:suite], params[:num], params["rdfa-extractor"], expected_results)
          status = "PASS"
          style = "text-decoration: underline; color: #090"
        else
          status = "FAIL"
          style = "text-decoration: underline; font-weight: bold; color: #f00"
        end
      rescue Exception => e
        puts "test failed with exception: #{e.class}: #{e.message}"
        puts e.backtrace if settings.environment != :production
        status = "FAIL"
        style = "text-decoration: underline; font-weight: bold; color: #f00"
      end
    
      locals = {
        :num              => params[:num],
        :doc_url          => get_test_url(params[:version], params[:suite], params[:num]),
        :sparql_url       => get_test_url(params[:version], params[:suite], params[:num], 'sparql'),
        :expected_results => params["expected-results"],
        :status           => status,
      }

      respond_to do |wants|
        wants.html do
          haml :test_result, :locals => locals.merge(:style => style)
        end
        wants.json do
          locals.to_json
        end
      end
    end

    get '/test-suite/test-details/:version/:suite/:num' do
      params["rdfa-extractor"] ||= "http://www.w3.org/2012/pyRdfa/extract?uri="
      format :json if format == :js
      prefixes = {}

      return [403, "Unauthorized access is not allowed"] unless authorized?

      begin
        locals = get_test_details(params[:version], params[:suite], params[:num])

        respond_to do |wants|
          wants.html do
            haml :test_details, :format => :html5, :locals => locals
          end
          wants.json do
            locals.to_json(::JSON::State.new(
              :indent       => "  ",
              :space        => " ",
              :space_before => "",
              :object_nl    => "\n",
              :array_nl     => "\n"
            ))
          end
        end
      rescue Exception => e
        puts "error: #{e.message}\n#{e.backtrace.join("\n")}"
        puts e.backtrace if settings.environment != :production
        [404, "#{e.message}\n#{e.backtrace.join("\n")}"]
      end
    end

    # These endpoints are here mostly for testing, where Apache will not automatically load
    # the index.html files.
    get('/')      { redirect to '/index.html'}
    get('/play/') { redirect to '/play/index.html'}
    get('/dev/')  { redirect to '/dev/index.html'}
    get('/docs/') { redirect to '/docs/index.html'}
    get('/tools/'){ redirect to '/tools/index.html'}
    get('/wiki')  { redirect to '/wiki/index.html'}
    get('/wiki/') { redirect to '/wiki/index.html'}
    get('/:dir')  do
      if Dir.exist?(File.expand_path("../../public/#{params[:dir]}",  __FILE__))
        redirect to "/#{params[:dir]}/"
      else
        [404, "Not Found"]
      end
    end

    get '/vocabs/rdfa-test' do
      redirect to('/vocabs/rdfa-test.html')
    end
  end
end