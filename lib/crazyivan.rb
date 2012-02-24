require 'linkeddata'
require 'sparql'
require 'sinatra'
require 'sinatra/respond_to'
require 'sinatra/sparql'
require 'digest/sha1'

class CrazyIvan < Sinatra::Base
  HTMLRE = Regexp.new('([0-9]{4,4})\.xhtml')
  TCPATHRE = Regexp.compile('\$TCPATH')
  MANIFEST_FILE = File.expand_path("../../manifest.ttl", __FILE__)

  configure do
    set :app_name, "The RDFa Test Harness (Crazy Ivan)"
    set :public_folder, File.expand_path('../../public',  __FILE__)
    set :views, File.expand_path('../views',  __FILE__)

    mime_type :sparql, "application/sparql-query"
    mime_type :ttl, "text/turtle"

    register Sinatra::RespondTo
    register Sinatra::SPARQL
    register Sinatra::SimpleAssets
    assets do
      css :application, [
        '/stylesheets/bootstrap.css',
        '/stylesheets/application.css'
      ]
      js :application, [
        '/javascripts/bootstrap.js',
        '/javascripts/bootstrap-alert.js',
        '/javascripts/bootstrap-button.js',
        '/javascripts/bootstrap-modal.js',
        '/javascripts/application.js'
      ]
    end
  end

  before do
    puts "[#{request.path_info}], #{params.inspect}, #{format}, #{request.accept.inspect}"
  end

  get '/test-suite/' do
    cache_control :public, :must_revalidate, :max_age => 60
    haml :test_suite
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
        :rdfatest => "http://rdfa.info/vocabs/rdfa-test#", # FIXME: new name?
      }
    )
    cache_control :public, :must_revalidate, :max_age => 60
    etag Digest::SHA1.hexdigest manifest_ttl
    respond_to do |wants|
      wants.ttl { manifest_ttl }
      wants.json { settings.sparql_options[:format] = :jsonld; graph }
      wants.html { graph }
    end
  end

  ##
  # Writes a test case document for the given URL.
  get '/test-suite/test-cases/:suite/:version/:num' do
    cache_control :public, :must_revalidate, :max_age => 60
    etag Digest::SHA1.hexdigest(manifest_ttl + "#{params[:suite]}/#{params[:version]}/#{params[:num]}")

    begin
      get_test_content(params[:suite], params[:version], params[:num], format.to_s);
    rescue Exception => e
      puts "error: #{e.message}\n#{e.backtrace.join("\n")}"
      [404, "#{e.message}\n#{e.backtrace.join("\n")}"]
    end
  end

  ##
  # Writes the test case alternatives for the given URL
  get '/test-suite/test-cases/:num' do
    format :json if format == :js
    cache_control :public, :must_revalidate, :max_age => 60
    etag Digest::SHA1.hexdigest(manifest_ttl + params[:num])

    test_cases = get_test_alternates(params[:num])
    puts "loaded test cases for #{params[:num]}"
    respond_to do |wants|
      wants.html do
        haml :test_cases, :format => :html5, :locals => {:test_cases => test_cases}
      end
      wants.json do
        test_cases.map do |tc|
          {
            :suite_version => "#{tc[:host_language]}+#{tc[:version]}",
            :doc_uri => tc[:doc_uri]
          }
        end.to_json
      end
    end
  end
  
  # Check a particular unit test
  get '/test-suite/check-test/:suite/:version/:num' do
    params["rdfa-extractor"] ||= "http://www.w3.org/2012/pyRdfa/extract?format=xml&uri="
    params["expected-results"] ||= 'true'
    expected_results = params["expected-results"] == 'true'
    format :json if format == :js

    begin
      if perform_test_case(params[:suite], params[:version], params[:num], params["rdfa-extractor"], expected_results)
        status = "PASS"
        style = "text-decoration: underline; color: #090"
      else
        status = "FAIL"
        style = "text-decoration: underline; font-weight: bold; color: #f00"
      end
      
      locals = {
        :num              => params[:num],
        :doc_url          => get_test_url(params[:suite], params[:version], params[:num]),
        :sparql_url       => get_test_url(params[:suite], params[:version], params[:num], 'sparql'),
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
    rescue Exception => e
      puts "error: #{e.message}\n#{e.backtrace.join("\n")}"
      [404, "#{e.message}\n#{e.backtrace.join("\n")}"]
    end
  end

  get '/test-suite/test-details/:suite/:version/:num' do
    params["rdfa-extractor"] ||= "http://www.w3.org/2012/pyRdfa/extract?uri="
    format :json if format == :js
    prefixes = {}

    begin
      locals = get_test_details(params[:suite], params[:version], params[:num])

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

  get '/vocabs/rdfa-test' do
    redirect to('/vocabs/rdfa-test.html')
  end

  # Deployment, triggered as a post-receive hook from Github
  # Called with a parameter :payload, which we just ignore
  post '/admin/deploy' do
    system(File.expand_path("../../deploy/after_push", __FILE__))
  end

  protected
  ##
  # Return the Manifest source
  def manifest_ttl
    @manifest_ttl = File.read(MANIFEST_FILE)
  end

  ##
  # Return Manifest graph
  def graph
    @graph ||= RDF::Graph.load(MANIFEST_FILE, :format => :turtle, :base_uri => url("test-suite/manifest.ttl"))
  end

  ##
  # Return the document URL for a test or SPARQL
  #
  # @param [String] suite "xhtml1", "html5" ...
  # @param [String] version "rdfa1.1" or other
  # @param [String] num "0001" or greater
  # @param [String] format
  #   "sparql", "xhtml", "xml", "html", "svg", or
  #   auto-detects from suite
  # @return [String]
  def get_test_url(suite, version, num, suffix = nil)
    # Load graph from built-in processor
    suffix ||= case suite
    when /xhtml1/ then "xhtml"
    when /html/   then "html"
    when /svg/    then "svg"
    else               "xml"
    end

    url("/test-suite/test-cases/#{suite}/#{version}/#{num}.#{suffix}").
      sub(/localhost:\d+/, 'rdfa.digitalbazaar.com') # For local testing
  end

  ##
  # Get the content for a test
  #
  # @param [String] suite "rdfa1.1" or other
  # @param [String] version "xhtml1", "html5" ...
  # @param [String] num "0001" or greater
  # @param [String] format "sparql", nil
  # @return [{:namespaces => {}, :content => String, :suite => String, :version => String}]
  #   Serialized document and namespaces
  def get_test_content(suite, version, num, format = nil)
    # Load graph from built-in processor
    suffix = case suite
    when /xhtml1/ then "xhtml"
    when /html/   then "html"
    when /svg/    then "svg"
    else               "xml"
    end

    filename = File.expand_path("../../tests/#{num}.#{format == 'sparql' ? 'sparql' : 'txt'}", __FILE__)
    tcpath = url("/test-suite/test-cases/#{suite}/#{version}").
      sub(/localhost:\d+/, 'rdfa.digitalbazaar.com') # For local testing

    # Read in the file, extracting namespaces
    found_head = format == 'sparql'
    namespaces = []
    content = File.readlines(filename).map do |line|
      case line
      when %r(<head)
        found_head ||= true
      end
      
      if found_head
        line
      else
        found_head = !!line.match(%r(http://www.w3.org/2000/svg))
        namespaces << line.strip
        nil
      end
    end.compact.join("")
    
    namespaces = namespaces.join("\n")
    namespaces = ' ' + namespaces unless namespaces.empty?
    content.gsub!(HTMLRE, "\\1.#{suffix}")
    content.gsub!(TCPATHRE, tcpath)

    case format || suffix
    when 'sparql'
      content
    when 'html'
      if suite == 'html4'
        %(<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/MarkUp/DTD/html401-rdfa11-1.dtd">\n) +
        %(<html version="XHTML+RDFa 1.1"#{namespaces}>\n)
      else
        "<!DOCTYPE html>\n" +
        %(<html#{namespaces}>\n)
      end +
      content +
      "</html>"
    when 'xml'
      %(<?xml version="1.0" encoding="UTF-8"?>\n<root#{namespaces}>\n) +
      content +
      "</root>"
    when 'svg'
      %(<?xml version="1.0" encoding="UTF-8"?>\n<svg#{namespaces}>\n) +
      content +
      "</svg>"
    when 'xhtml'
      %(<?xml version="1.0" encoding="UTF-8"?>\n) +
      if suite == 'xhtml1' && version == 'rdfa1.0'
        %(<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.0//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-1.dtd">\n) +
        %(<html xmlns="http://www.w3.org/1999/xhtml" version="XHTML+RDFa 1.0"#{namespaces}>\n)
      elsif suite == 'xhtml1'
        %(<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.1//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-2.dtd">\n) +
        %(<html xmlns="http://www.w3.org/1999/xhtml" version="XHTML+RDFa 1.1"#{namespaces}>\n)
      else
        %(<!DOCTYPE html>\n<html#{namespaces}>\n)
      end +
      content +
      "</html>"
    else
      raise "unknown format #{(format || suffix).inspect}"
    end
  end

  ##
  # Return test details, including doc text, sparql, and extracted results
  #
  # @param [String] suite "xhtml1", "html5" ...
  # @param [String] version "rdfa1.1" or other
  # @param [String] num "0001" or greater
  # @return [{Symbol => Object}]
  #   Serialized documents and URIs
  def get_test_details(suite, version, num)
    # Load graph from built-in processor
    doc_url = get_test_url(suite, version, num)
    puts "doc_url: #{doc_url}"

    # Short cut document text
    prefixes = {}
    doc_text = get_test_content(suite, version, num)
    doc_graph = RDF::Graph.new << RDF::RDFa::Reader.new(doc_text, :format => :rdfa, :prefixes => prefixes)

    # Turtle version of default graph
    ttl_text = doc_graph.dump(:turtle, :prefixes => prefixes, :base_uri => doc_url)
    sparql_url = get_test_url(suite, version, num, 'sparql')
    sparql_text = get_test_content(suite, version, num, 'sparql')

    # Extracted version of default graph
    extract_url = ::URI.decode(params["rdfa-extractor"]) + ::URI.encode(doc_url)
    extracted_text = RDF::Util::File.open_file(extract_url).read

    {
      :num            => params[:num],
      :doc_text       => doc_text,
      :doc_url        => doc_url,
      :ttl_text       => ttl_text,
      :extracted_text => extracted_text,
      :extract_url    => extract_url,
      :sparql_text    => sparql_text,
      :sparql_url     => sparql_url
    }
  end

  ##
  # Retrieves all variations of a particular test case from the given test suite manifest URL
  #
  # @param [String, RDF::URI] base_uri the base URL for the test cases
  # @param [String] num
  #   Test case number.
  # @return [Array<{Symbol => String}>]
  #   a list containing all of the filtered test cases including
  #          unit test number, title, Host Language URL, and SPARQL URL.
  def get_test_alternates(num)
    q = %(
      PREFIX test: <http://www.w3.org/2006/03/test-description#> 
      PREFIX rdfatest: <http://rdfa.digitalbazaar.com/vocabs/rdfa-test#> 
      PREFIX dc:   <http://purl.org/dc/terms/>

      SELECT ?t ?title ?classification ?expected_results ?host_language ?version
      WHERE {
        ?t rdfatest:hostLanguage ?host_language;
           rdfatest:rdfaVersion ?version;
           dc:title ?title;
           test:classification ?classification .
        OPTIONAL { 
          ?t test:expectedResults ?expected_results .
        }
        FILTER REGEX(STR(?t), "#{num}$")
      }
    )
    puts "query: #{q}"
    SPARQL.execute(q, graph).map do |solution|
      puts "solution: #{solution.inspect}"
      entry = solution.to_hash
      entry[:classification] = entry[:classification].to_s.split('#').last
      entry[:num] = num
      entry[:expected_results] ||= true
    
      # Generate the input document URLs
      entry[:suffix] = case entry[:host_language].to_s
      when /xhtml1/ then "xhtml"
      when /html/   then "html"
      when /svg/    then "svg"
      else               "xml"
      end

      entry[:doc_uri] = get_test_url(entry[:host_language], entry[:version], num, entry[:suffix])
      entry[:sparql_url] = get_test_url(entry[:host_language], entry[:version], num, 'sparql')
      entry
    end
  rescue
    puts "error: #{$!.inspect}"
  end

  ##
  # Performs a given unit test given the RDF extractor URL, sparql engine URL,
  # HTML file and SPARQL validation file.
  #
  # @param [String] suite "xhtml1", "html5" ...
  # @param [String] version "rdfa1.1" or other
  # @param [String] num "0001" or greater
  # @param [RDF::URI, String] extract_url The RDF extractor web service.
  # @param [Boolean] expected_results `true` or `false`
  # @return [Boolean] pass or fail
  def perform_test_case(suite, version, num, extract_url, expected_results)
    # Build the RDF extractor URL
    extract_url = ::URI.decode(extract_url) + get_test_url(suite, version, num)

    # Get the SPARQL query
    sparql_query = get_test_content(suite, version, num, 'sparql').
      sub("ASK WHERE", "ASK FROM <#{extract_url}> WHERE")

    puts "sparql_query: #{sparql_query}"

    # Perform the SPARQL query
    result = SPARQL.execute(StringIO.new(sparql_query), nil)
    puts "result: #{result.inspect}, expected: #{expected_results.inspect} == #{(result == expected_results).inspect}"
    result == expected_results
  end
end