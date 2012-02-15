require 'linkeddata'
require 'sparql'
require 'sinatra/base'
require 'sinatra/respond_to'
require 'sinatra/sparql'
require 'haml'
require 'digest/sha1'

class CrazyIvan < Sinatra::Base
  HTMLRE = Regexp.new('([0-9]{4,4})\.xhtml')
  TCPATHRE = Regexp.compile('\$TCPATH')
  MANIFEST_FILE = File.expand_path("../../manifest.ttl", __FILE__)

  register Sinatra::RespondTo
  register Sinatra::SPARQL

  set :views, File.expand_path('../views',  __FILE__)

  mime_type :sparql, "application/sparql-query"
  mime_type :ttl, "text/turtle"

  before do
    puts "[#{request.path_info}], #{params.inspect}, #{format}, #{request.accept.inspect}"
  end

  get '/' do
    redirect to('/test-suite/index.html')
  end

  ##
  # Return a representation of the manifest
  # Format is determined by content-negotiation
  #
  # We consider JavaScript and JSON to just return JSON-LD
  get '/test-suite/manifest' do
    settings.sparql_options.replace(
      :standard_prefixes => true,
      :prefixes => {:test => "http://www.w3.org/2006/03/test-description#"}
    )
    cache_control :public, :must_revalidate, :max_age => 60
    etag Digest::SHA1.hexdigest manifest_ttl
    respond_to do |wants|
      wants.ttl { manifest_ttl }
      wants.js { settings.sparql_options[:format] = :jsonld; graph }
      wants.json { settings.sparql_options[:format] = :jsonld; graph }
      wants.jsonld { settings.sparql_options[:format] = :jsonld; graph }
      wants.html { graph }
    end
  end

  ##
  # Writes a test case document for the given URL.
  get '/test-suite/test-cases/:suite/:version/:test' do
    cache_control :public, :must_revalidate, :max_age => 60
    etag Digest::SHA1.hexdigest(manifest_ttl + "#{params[:suite]}/#{params[:version]}/#{params[:test]}")

    filename = File.expand_path("../../tests/#{params[:test]}.#{format == :sparql ? 'sparql' : 'txt'}", __FILE__)
    tcpath = url("/test-cases/#{params[:suite]}/#{params[:version]}")
    begin
      found_head = format == :sparql
      namespaces = {}
      content = File.readlines(filename).map do |line|
        case line
        when %r(<head)
          found_head ||= true
        end
        
        if found_head
          line.chop
        else
          found_head = !!line.match(%r(http://www.w3.org/2000/svg))
          line.split(/\s+/).each do |defn|
            namespaces[$1] = $2 if defn.match(/(xmlns[^=]*)=['"](.*)['"]/)
          end
          nil
        end
      end.compact.join("\n")
      
      # Update test-case path
      content.gsub!(TCPATHRE, tcpath)

      case format
      when :sparql
        erb :test_case, :locals => {
          :namespaces => namespaces,
          :content => content,
          :suite => params[:suite],
          :version => params[:version]
        }
      else
        haml :test_case, :locals => {
          :namespaces => namespaces,
          :content => content,
          :suite => params[:suite],
          :version => params[:version]
        }
      end
    rescue Exception => e
      puts "error: #{e.message}\n#{e.backtrace.join("\n")}"
      [404, "#{e.message}\n#{e.backtrace.join("\n")}"]
    end
  end

  get '/test-suite/test-cases/:suite/:version' do
    haml :test_case_error, :format => :html5, :locals => {:unparsed_uri => request.url}
  end
  
  ##
  # Writes the test case alternatives for the given URL
  get '/test-suite/test-cases/:test' do
    cache_control :public, :must_revalidate, :max_age => 60
    etag Digest::SHA1.hexdigest(manifest_ttl + params[:test])

    @test_cases = retrieve_test_case_alternates(params[:test].to_i)
    haml :test_cases, :format => :html5, :locals => {:test_cases => @test_cases, :num => params[:test]}
  end
  
  get '/test-suite/test-cases' do
    haml :test_case_error, :format => :html5, :locals => {:unparsed_uri => request.url}
  end
  
  # Retrieve a test suite
  get '/test-suite/retrieve-tests' do
    format :html  # Only respond with HTML for now
    unless params["host-language"] && params["rdfa-version"]
      body %(
        <span style=\"text-decoration: underline; font-weight: bold; color: #f00\">
          ERROR: Could not retrieve test suite, Host Language ('language') and RDFa version ('version') were not specified!
        </span>
      )
    else
      begin
        cache_control :public, :must_revalidate, :max_age => 60
        etag Digest::SHA1.hexdigest(manifest_ttl + params["host-language"] + params["rdfa-version"])
        haml :retrieve_tests, :format => :html5, :locals => {
          :test_cases => retrieve_test_cases(params["host-language"], params["rdfa-version"])
        }
      rescue Exception => e
        puts "error: #{e.message}\n#{e.backtrace.join("\n")}"
        [404, "#{e.message}\n#{e.backtrace.join("\n")}"]
      end
    end
  end

  # Check a particular unit test
  get '/test-suite/check-test' do
    format :html  # Only respond with HTML for now
    req_params = %w(id source sparql rdfa-extractor sparql-engine expected-result)
    unless req_params.all? {|p| params.has_key?(p)}
      body req_params.detect {|p| !params.has_key?(p)}.map(", ") + "not specified to test harness!\nARGS: #{params.inspect}"
    else
      checkUnitTestHtml(("%04d" % params['id'].to_i), params['rdfa-extractor'],
                        params['sparql-engine'],
                        params['source'], params['sparql'],
                        params['expected-result'])
    end
  end

  get '/test-suite/test-details' do
    format :html  # Only respond with HTML for now
    req_params = %w(id source sparql rdfa-extractor)
    unless req_params.all? {|p| params.has_key?(p)}
      body req_params.detect {|p| !params.has_key?(p)}.map(", ") + "not specified to test harness!\nARGS: #{params.inspect}"
    else
      cache_control :public, :must_revalidate, :max_age => 60
      etag Digest::SHA1.hexdigest(manifest_ttl + params.inspect)
      begin
        prefixes = {}
        doc_url = ::URI.decode(params[:source])
        doc_text = RDF::Util::File.open_file(doc_url).read
        doc_graph = RDF::Graph.new << RDF::RDFa::Reader.new(doc_text, :format => :rdfa, :prefixes => prefixes)
        
        ttl_text = doc_graph.dump(:turtle, :prefixes => prefixes, :base_uri => doc_url)
        sparql_url = ::URI.decode(params[:sparql])
        sparql_text = RDF::Util::File.open_file(sparql_url).read
        
        rdf_extract_url = params["rdfa-extractor"] + params[:source]
        rdf_text = RDF::Util::File.open_file(rdf_extract_url).read

        haml :test_details, :format => :html5, :locals => {
          :num => params[:id],
          :doc_text => doc_text,
          :doc_url => doc_url,
          :ttl_text => ttl_text,
          :rdf_text => rdf_text,
          :rdf_url => rdf_extract_url,
          :sparql_text => sparql_text,
          :sparql_url => sparql_url
        }
      rescue Exception => e
        puts "error: #{e.message}\n#{e.backtrace.join("\n")}"
        [404, "#{e.message}\n#{e.backtrace.join("\n")}"]
      end
    end
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
  # Retrieves all of the test cases from the given test suite manifest URL and
  # filters the RDF using the given status filter.
  #
  # @param [String, RDF::URI] base_uri the base URL for the test cases
  # @param [String] hostLanguage
  #   the host language to use when selecting the list of tests.
  # @param [String] rdfaVersion
  #   the version of RDFa to use when selecting the list of  tests.
  # @return [Array<Symbol => String>]
  #   a list containing all of the filtered test cases including
  #          unit test number, title, Host Language URL, and SPARQL URL.
  def retrieve_test_cases(host_language, rdfa_version)
    puts "retrieve_test_cases(#{host_language.inspect}, #{rdfa_version.inspect})"
    q = %(
      PREFIX test: <http://www.w3.org/2006/03/test-description#> 
      PREFIX rdfatest: <http://rdfa.digitalbazaar.com/vocabs/rdfa-test#> 
      PREFIX dc:   <http://purl.org/dc/elements/1.1/>

      SELECT ?t ?title ?classification ?expected_results
      WHERE {
        ?t rdfatest:hostLanguage "#{host_language}";
           rdfatest:rdfaVersion "#{rdfa_version}";
           dc:title ?title;
           test:classification ?classification .
        OPTIONAL { 
          ?t test:expectedResults ?expected_results .
        }
      }
    )
    puts "query: #{q}"
    SPARQL.execute(q, graph).map do |solution|
      entry = solution.to_hash
      entry[:classification] = entry[:classification].to_s.split('#').last
      entry[:num] = entry[:t].to_s.split('/').last
      entry[:expected_results] ||= true
    
      # Generate the input document URLs
      entry[:suffix] = case host_language
      when /xhtml1/ then "xhtml"
      when /html/   then "html"
      when /svg/    then "svg"
      else               "xml"
      end
    
      test_uri = url("test-suite/test-cases/#{host_language}/#{rdfa_version}/#{entry[:num]}.")
      entry[:doc_uri] = test_uri + entry[:suffix]
      entry[:sparql_url] = test_uri + "sparql"
      entry
    end
  end
  
  ##
  # Retrieves all variations of a particular test case from the given test suite manifest URL
  #
  # @param [String, RDF::URI] base_uri the base URL for the test cases
  # @param [Integer] num
  #   Test case number.
  # @return [Array<{Symbol => String}>]
  #   a list containing all of the filtered test cases including
  #          unit test number, title, Host Language URL, and SPARQL URL.
  def retrieve_test_case_alternates(num)
    q = %(
      PREFIX test: <http://www.w3.org/2006/03/test-description#> 
      PREFIX rdfatest: <http://rdfa.digitalbazaar.com/vocabs/rdfa-test#> 
      PREFIX dc:   <http://purl.org/dc/elements/1.1/>

      SELECT ?t ?title ?classification ?expected_results ?host_language ?version
      WHERE {
        ?t rdfatest:hostLanguage ?host_language;
           rdfatest:rdfaVersion ?version;
           dc:title ?title;
           test:classification ?classification .
        OPTIONAL { 
          ?t test:expectedResults ?expected_results .
        }
        FILTER REGEX(STR(?t), "#{"%04d" % num}$")
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
    
      test_uri = url("test-suite/test-cases/#{entry[:host_language]}/#{entry[:version]}/#{"%04d" % num}.")
      entry[:doc_uri] = test_uri + entry[:suffix]
      entry[:sparql_url] = test_uri + "sparql"
      entry
    end
  rescue
    puts "error: #{$!.inspect}"
  end

  ##
  # Checks a unit test and outputs a simple unit test result as HTML.
  #
  # @param req the HTML request object.
  # @param num the unit test number.
  # @param rdf_extractor_url The RDF extractor web service.
  # @param sparql_engine_url The SPARQL engine URL.
  # @param doc_url the HTML file to use as input.
  # @param sparql_url the SPARQL file to use when validating the RDF graph.
  # @param expected_result
  def checkUnitTestHtml(num, rdfa_extractor_url, sparql_engine_url, doc_url, sparql_url, expected_result)
    if performUnitTest(num, rdfa_extractor_url, sparql_engine_url, doc_url, sparql_url, expected_result)
      status = "PASS"
      style = "text-decoration: underline; color: #090"
    else
      status = "FAIL"
      style = "text-decoration: underline; font-weight: bold; color: #f00"
    end
    haml :test_result, :locals => {
      :num => num.to_i,
      :doc_url => doc_url,
      :sparql_url => sparql_url,
      :expected_result => expected_result,
      :status => status,
      :style => style,
    }
  rescue Exception => e
    puts "error: #{e.message}\n#{e.backtrace.join("\n")}"
    [404, "#{e.message}\n#{e.backtrace.join("\n")}"]
  end

  ##
  # Performs a given unit test given the RDF extractor URL, sparql engine URL,
  # HTML file and SPARQL validation file.
  #
  # @param [String] num the unit test number.
  # @param [RDF::URI, String] rdf_extractor_url The RDF extractor web service.
  # @param [RDF::URI, String] sparql_engine_url The SPARQL engine URL.
  # @param [RDF::URI, String] doc_url the HTML file to use as input.
  # @param [RDF::URI, String] sparql_url the SPARQL validation file to use on the RDF graph.
  def performUnitTest(num, rdf_extractor_url, sparql_engine_url, doc_url, sparql_url, expected_result)
    puts "performUnitTest(#{num.inspect}, #{rdf_extractor_url.inspect}, #{sparql_engine_url.inspect}, #{doc_url.inspect}, #{sparql_url.inspect}, #{expected_result.inspect})"
    # Build the RDF extractor URL
    rdf_extractor_url += ::URI.decode(doc_url)

    # Get the SPARQL query
    doc_extension = doc_url.split('.').last
    tcpath = doc_url.sub(/\/[^\/]*$/, '')
    sparql_query = File.read(File.expand_path("../../tests/#{num}.sparql", __FILE__)).
      gsub(TCPATHRE, tcpath).
      gsub(HTMLRE, '\1.' + doc_extension).
      sub("ASK WHERE", "ASK FROM <#{rdf_extractor_url}> WHERE")

    puts "sparql_query: #{sparql_query}"

    # Perform the SPARQL query
    sparql_value = case sparql_engine_url
    when %r(/test-suite/sparql-query)
      SPARQL.execute(StringIO.new(sparql_query), nil)
    when %r(openlinksw)
      sparql_engine_url += ::URI.encode(sparql_query)
      sparql_engine_result = RDF::Util::File.open_file(sparql_engine_url).read
      sparql_engine_result.to_s.include?(expected_result.to_s)
    when %r(greggkellogg.net)
      sparql_engine_url += ::URI.encode(sparql_query)
      sparql_engine_result = RDF::Util::File.open_file(sparql_engine_url).read
      sparql_engine_result.to_s.include?(expected_result.to_s)
    when %r(sparql.org)
      sparql_engine_url += ::URI.encode(sparql_query)
      sparql_engine_url += "&default-graph-uri=&stylesheet=%2Fxml-to-html.xsl"
      sparql_engine_result = RDF::Util::File.open_file(sparql_engine_url).read
      sparql_engine_result.to_s.include?(expected_result.to_s)
    else
      # Custom SPARQL engine, presume that it only needs the query URL
      sparql_engine_url += ::URI.encode(sparql_query)
      sparql_engine_result = RDF::Util::File.open_file(sparql_engine_url).read
      sparql_engine_result.to_s.include?(expected_result.to_s)
    end
    
    sparql_value
  end

  ##
  # Outputs the details related to a given unit test given the unit test number,
  # RDF extractor URL, sparql engine URL, HTML file and SPARQL validation file.
  # The output is written to the req object as HTML.
  #
  # @param req the HTTP request.
  # @param num the unit test number.
  # @param rdf_extractor_url The RDF extractor web service.
  # @param sparql_engine_url The SPARQL engine URL.
  # @param doc_url the HTML file to use as input.
  # @param sparql_url the SPARQL validation file to use on the RDF graph.
  def retrieveUnitTestDetailsHtml(req, num, rdf_extractor_url, n3_extractor_url, doc_url, sparql_url)
  end
end