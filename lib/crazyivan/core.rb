require 'linkeddata'
require 'sparql'
require 'crazyivan/extensions'

module CrazyIvan
  ##
  # Core utilities used for generating and checking test cases
  module Core
    HTMLRE = Regexp.new('([0-9]{4,4})\.xhtml')
    TCPATHRE = Regexp.compile('\$TCPATH')
    TESTS_PATH = File.expand_path("../../../tests", __FILE__)
    MANIFEST_FILE = File.expand_path("../../../manifest.ttl", __FILE__)
    MANIFEST_JSON = File.expand_path("../../../manifest.jsonld", __FILE__)
    HOSTNAME = (ENV['hostname'] || 'rdfa.info').freeze

    TESTS_QUERY = %(
      PREFIX dc: <http://purl.org/dc/terms/>
      PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
      PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
      PREFIX test: <http://www.w3.org/2006/03/test-description#>
      PREFIX rdfatest: <http://rdfa.info/vocabs/rdfa-test#>
      PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>

      SELECT ?id
             ?classification
             ?contributor
             ?description
             ?expectedResults
             ?hostLanguage
             ?input
             ?purpose
             ?queryParam
             ?reference
             ?results
             ?version
      WHERE {
        ?id dc:contributor ?contributor;
           dc:title ?description;
           a test:TestCase;
           rdfatest:rdfaVersion ?version;
           rdfatest:hostLanguage ?hostLanguage;
           test:informationResourceInput ?input;
           test:informationResourceResults ?results;
           test:purpose ?purpose;
           test:specificationReference ?reference .
        OPTIONAL { ?id test:classification ?classification . }
        OPTIONAL { ?id test:expectedResults ?expectedResults . }
        OPTIONAL { ?id rdfatest:queryParam ?queryParam . }
      }
      ORDER BY ?id ?version ?hostLanguage
    ).freeze
    
    ##
    # Make strings turtle """ safe
    #
    # @param [String] unsafe string
    # @return suitably escaped content
    def tesc(unsafe_string)
      # trailing " is bad
      unsafe_string.sub /"$/, '\"'
    end

    ##
    # Return the Manifest source
    #
    # For version/suite specific manifests, the MF syntax is used,
    # instead of TestQuery; this makes EARL reporting simpler.
    #
    # @param [String] version
    # @param [String] suite
    def manifest_ttl(version = nil, suite = nil)
      if version && suite
        # Return specific subset of manifest based on host_language and version
        # with appropriate URI re-writing
        test_ttl = ""
        ttl = %{@base <#{url("/test-suite/test-cases/#{version}/#{suite}/manifest")}> .
          @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
          @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
          @prefix mf: <http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#> .
          @prefix qt: <http://www.w3.org/2001/sw/DataAccess/tests/test-query#> .
          @prefix test: <http://www.w3.org/2006/03/test-description#> .

          <>  rdf:type mf:Manifest ;
              rdfs:comment "RDFa #{version} tests for #{suite}" ;
              mf:entries (
        }.gsub(/^          /, '')
        ::JSON.load(manifest_json)['@graph'].each do |tc|
          next unless tc['hostLanguages'].include?(suite) && tc['versions'].include?(version)
          ttl << "      <##{tc['num']}>\n"
          test_ttl << %{
            <##{tc['num']}> a mf:QueryEvaluationTest;
              mf:name """Test #{tc['num']}: #{tesc(tc['description'])}""";
              rdfs:comment """#{tesc(tc['purpose'])}""";
              test:classification <#{tc['classification']}>;
              mf:action [ a qt:QueryTest;
                qt:queryForm qt:QueryAsk;
                qt:query <#{get_test_url(version, suite, tc['num'], 'sparql')}>;
                qt:data <#{get_test_url(version, suite, tc['num'])}>
              ];
              mf:result #{tc['expectedResults']} .
          }.gsub(/^            /, '')
          test_ttl << %{<##{tc['num']}> test:specificationReference """#{tesc(tc['reference'])}""" .\n} unless tc['reference'].empty?
        end
        
        # Output manifest definition, ordered tests and test definitions
        ttl << "  ) .\n"
        ttl + test_ttl
      else
        @manifest_ttl = File.read(MANIFEST_FILE)
      end
    end
    module_function :manifest_ttl

    ##
    # Return the Manifest source
    #
    # Generate a JSON-LD compatible with framing in /frames/rdfa-test.jsonld
    # and /contexts/rdfa-test.jsonld
    def manifest_json
      unless File.exist?(MANIFEST_JSON) && File.mtime(MANIFEST_JSON) >= File.mtime(MANIFEST_FILE)
        hash = Hash.ordered
        hash["@context"] = "http://rdfa.info/contexts/rdfa-test.jsonld"
        hash['@graph'] = []

        start = Time.now
        puts "Started SPARQL @ #{start.to_s}"
        SPARQL.execute(TESTS_QUERY, graph).each do |tc|
          tc_hash = hash['@graph'].last
          unless tc_hash && tc_hash['@id'] == tc[:id]
            tc_hash = Hash.ordered
            tc_hash['@id'] = tc[:id].to_s
            tc_hash['@type'] = 'test:TestCase'
            tc[:num] = tc_hash['@id'].split('/').last.split('.').first
            tc[:classification] ||= 'http://www.w3.org/2006/03/test-description#required'
            %w(num classification contribuor description input purpose queryParam reference results).each do |prop|
              tc_hash[prop] = tc[prop.to_sym].to_s unless tc[prop.to_sym].nil?
            end
            tc_hash['expectedResults'] = tc[:expectedResults].nil? ? true : tc[:expectedResults].object
            tc_hash['hostLanguages'] = []
            tc_hash['versions'] = []
            hash['@graph'] << tc_hash
          end
          tc_hash['hostLanguages'] << tc[:hostLanguage].to_s unless tc_hash['hostLanguages'].include?(tc[:hostLanguage].to_s)
          tc_hash['versions'] << tc[:version].to_s unless tc_hash['versions'].include?(tc[:version].to_s)
        end
        finish = Time.now
        puts "Finished SPARQL @ #{finish.to_s} #{finish - start} secs"

        json = hash.to_json(::JSON::State.new(
          :indent       => "  ",
          :space        => " ",
          :space_before => "",
          :object_nl    => "\n",
          :array_nl     => "\n"
        ))
        File.open(MANIFEST_JSON, "w") {|f| f.write(json)}
      end
      @manifest_json = File.read(MANIFEST_JSON)
    end
    module_function :manifest_json

    ##
    # Return Manifest graph
    def graph
      @graph ||= RDF::Graph.load(MANIFEST_FILE, :format => :turtle, :base_uri => url("/test-suite/manifest.ttl"))
    end
    module_function :graph

    ##
    # Return Suite/Version specific Manifest graph
    #
    # @param [String] version
    # @param [String] suite
    # @return [RDF::Graph]
    def version_graph(version, suite)
      # Get sub-graph matching just version and suite
      g = SPARQL.execute(%(
        PREFIX test: <http://www.w3.org/2006/03/test-description#>
        PREFIX rdfatest: <http://#{HOSTNAME}/vocabs/rdfa-test#>
        PREFIX dc: <http://purl.org/dc/terms/>

        CONSTRUCT {
          ?id a test:TestCase;
            dc:title ?title;
            dc:contributor ?contributor;
            test:classification ?classification;
            test:purpose ?purpose;
            test:expectedResults ?expected;
            test:informationResourceInput ?input;
            test:informationResourceResults ?results .
        }
        WHERE {
          ?id a test:TestCase;
            dc:title ?title;
            dc:contributor ?contributor;
            rdfatest:rdfaVersion "#{version}";
            rdfatest:hostLanguage "#{suite}";
            test:classification ?classification;
            test:purpose ?purpose;
            test:informationResourceInput ?input;
            test:informationResourceResults ?results .
            OPTIONAL { ?id test:classification ?classification . }
            OPTIONAL { ?id test:expectedResults ?expectedResults . }
            OPTIONAL { ?id rdfatest:queryParam ?queryParam . }
        }
      ), graph)

      # Construct a new graph, substituting graph ID, expanded and input
      # for their suite/version specific values
      output_graph = RDF::Graph.new
      test_base = RDF::URI("http://www.w3.org/2006/03/test-description#")
      g.each_statement do |statement|
        num = statement.subject.to_s.split("/").last
        subj = get_test_url(params[:version], params[:suite], num)
        sparql = get_test_url(params[:version], params[:suite], num, "sparql")
        statement.subject = RDF::URI(subj)
        case statement.predicate.to_s
        when /informationResourceInput/
          statement.object = statement.subject
        when /informationResourceResults/
          statement.object = RDF::URI(sparql)
        end
        output_graph << statement
      end
      output_graph
    end

    ##
    # Return the document URL for a test or SPARQL
    #
    # @param [String] version "rdfa1.1" or other
    # @param [String] suite "xhtml1", "html5" ...
    # @param [String] num "0001" or greater
    # @param [String] format
    #   "sparql", "xhtml", "xml", "html", "svg", or
    #   auto-detects from suite
    # @return [String]
    def get_test_url(version, suite, num, suffix = nil)
      suffix ||= case suite
      when /xhtml/  then "xhtml"
      when /html/   then "html"
      when /svg/    then "svg"
      else               "xml"
      end

      url("/test-suite/test-cases/#{version}/#{suite}/#{num}.#{suffix}").
        sub(/localhost:\d+/, HOSTNAME) # For local testing
     rescue
       "http://rdfa.info/test-suite/test-cases/#{version}/#{suite}/#{num}.#{suffix}"
    end
    module_function :get_test_url

    ##
    # Get the content for a test
    #
    # @param [String] version "xhtml1", "html5" ...
    # @param [String] suite "rdfa1.1" or other
    # @param [String] num "0001" or greater
    # @param [String] format "sparql", nil
    # @return [{:root_attributes => {}, :content => String, :suite => String, :version => String}]
    #   Serialized document and root attributes (including prefix mappings)
    def get_test_content(version, suite, num, format = nil)
      suffix = case suite
      when /xhtml/  then "xhtml"
      when /html/   then "html"
      when /svg/    then "svg"
      else               "xml"
      end

      filename = TESTS_PATH + "/#{num}.#{format == 'sparql' ? 'sparql' : 'txt'}"
      
      tcpath = url("/test-suite/test-cases/#{version}/#{suite}") rescue "http://rdfa.info/test-suite/test-cases/#{version}/#{suite}"
      tcpath.sub!(/localhost:\d+/, HOSTNAME) # For local testing

      # Read in the file, extracting prefix mappings and other root attributes
      found_head = format == 'sparql'
      in_json = false
      prefix_mappings = []
      root_attributes = []
      prefix_mappings_json= ""
      content = File.readlines(filename).map do |line|
        line.force_encoding(Encoding::UTF_8) if line.respond_to?(:force_encoding)
        case line
        when %r(<head)
          found_head ||= true
        when %r({)
          in_json ||= true
        end
      
        if found_head
          line
        else
          found_head = !!line.match(%r(http://www.w3.org/2000/svg))
          if in_json then
            prefix_mappings_json << line.strip
            in_json = false if line.include?("}")
          else
            root_attributes << line.strip
          end
          nil
        end
      end.compact.join("")
      content.force_encoding(Encoding::UTF_8) if content.respond_to?(:force_encoding)
    
      unless prefix_mappings_json.empty?
        ::JSON.parse(prefix_mappings_json).each do |prefix,iri|
          if version == 'rdfa1.0' then
            prefix_mappings << 'xmlns:' + prefix + '="' + iri + '"'
          else
            prefix_mappings << prefix + ": " + iri
          end
        end
        if version == 'rdfa1.0' then
          prefix_mappings = prefix_mappings.join(" ")
        else
          prefix_mappings = 'prefix="' + prefix_mappings.join(" ") + '"'
        end
      else
        prefix_mappings = ""
      end
      root_attributes = root_attributes.join("\n")
      root_attributes = ' ' + root_attributes unless root_attributes.empty?
      root_attributes = prefix_mappings + root_attributes
      root_attributes = ' ' + root_attributes unless prefix_mappings.empty?

      content.gsub!(HTMLRE, "\\1.#{suffix}")
      content.gsub!(TCPATHRE, tcpath)

      case format || suffix
      when 'sparql'
        content
      when 'html'
        if suite == 'html4'
          %(<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/MarkUp/DTD/html401-rdfa11-1.dtd">\n) +
          %(<html version="HTML+RDFa 1.1"#{root_attributes}>\n)
        else
          "<!DOCTYPE html>\n" +
          %(<html#{root_attributes}>\n)
        end +
        content +
        "</html>"
      when 'xml'
        %(<?xml version="1.0" encoding="UTF-8"?>\n<root#{root_attributes}>\n) +
        content +
        "</root>"
      when 'svg'
        %(<?xml version="1.0" encoding="UTF-8"?>\n<svg#{root_attributes}>\n) +
        content +
        "</svg>"
      when 'xhtml'
        %(<?xml version="1.0" encoding="UTF-8"?>\n) +
        if suite == 'xhtml1' && version == 'rdfa1.0'
          %(<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.0//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-1.dtd">\n) +
          %(<html xmlns="http://www.w3.org/1999/xhtml" version="XHTML+RDFa 1.0"#{root_attributes}>\n)
        elsif suite == 'xhtml1'
          %(<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.1//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-2.dtd">\n) +
          %(<html xmlns="http://www.w3.org/1999/xhtml" version="XHTML+RDFa 1.1"#{root_attributes}>\n)
        else
          %(<!DOCTYPE html>\n<html xmlns="http://www.w3.org/1999/xhtml"#{root_attributes}>\n)
        end +
        content +
        "</html>"
      else
        raise "unknown format #{(format || suffix).inspect}"
      end
    end
    module_function :get_test_content

    ##
    # Return test details, including doc text, sparql, and extracted results
    #
    # @param [String] version "rdfa1.1" or other
    # @param [String] suite "xhtml1", "html5" ...
    # @param [String] num "0001" or greater
    # @return [{Symbol => Object}]
    #   Serialized documents and URIs
    def get_test_details(version, suite, num)
      doc_url = get_test_url(version, suite, num)
      puts "doc_url: #{doc_url}"

      tests = ::JSON.load(manifest_json)['@graph']
      test = tests.detect {|t| t['@id'] == "http://rdfa.info/test-suite/test-cases/#{num}"}

      # Short cut document text
      prefixes = {}
      doc_text = get_test_content(version, suite, num)
      doc_graph = RDF::Graph.new << RDF::RDFa::Reader.new(doc_text, :base_uri => doc_url, :format => :rdfa, :prefixes => prefixes)

      # Turtle version of default graph
      ttl_text = doc_graph.dump(:turtle, :prefixes => prefixes, :base_uri => doc_url)
      ttl_text.force_encoding(Encoding::UTF_8) if ttl_text.respond_to?(:force_encoding)
      sparql_url = get_test_url(version, suite, num, 'sparql')
      sparql_text = get_test_content(version, suite, num, 'sparql')

      # Extracted version of default graph
      extract_url = ::URI.decode(params["rdfa-extractor"]) + ::URI.encode(doc_url)
      begin
        extracted_text = RDF::Util::File.open_file(extract_url).read
        extracted_text.force_encoding(Encoding::UTF_8) if extracted_text.respond_to?(:force_encoding)
      rescue Exception => e
        puts "error extracting text: #{e.class}: #{e.message}"
        puts e.backtrace if settings.environment != :production
        extracted_text = e.message
      end

      {
        :num            => params[:num],
        :purpose        => test["purpose"],
        :doc_text       => doc_text,
        :doc_url        => doc_url,
        :ttl_text       => ttl_text,
        :extracted_text => extracted_text,
        :extract_url    => extract_url,
        :sparql_text    => sparql_text,
        :sparql_url     => sparql_url
      }
    end
    module_function :get_test_details

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
      tests = ::JSON.load(manifest_json)['@graph']
      test = tests.detect {|t| t['@id'] == "http://rdfa.info/test-suite/test-cases/#{num}"}
    
      entries = []
      [test["hostLanguages"]].flatten.each do |host_language|
        suffix = case host_language.to_s
        when /xhtml/  then "xhtml"
        when /html/   then "html"
        when /svg/    then "svg"
        else               "xml"
        end
        [test["versions"]].flatten.each do |version|
          entries << {
            :num => num,
            :doc_uri => get_test_url(version, host_language, num, suffix),
            :suite_version => "#{host_language}+#{version}"
          }
        end
      end
      puts "entries: #{entries.inspect}"
      entries
    rescue
      puts "error: #{$!.inspect}"
      puts $!.backtrace if settings.environment != :production
    end
    module_function :get_test_alternates

    ##
    # Performs a given unit test given the RDF extractor URL, sparql engine URL,
    # HTML file and SPARQL validation file.
    #
    # @param [String] version "rdfa1.1" or other
    # @param [String] suite "xhtml1", "html5" ...
    # @param [String] num "0001" or greater
    # @param [RDF::URI, String] extract_url The RDF extractor web service.
    # @param [Boolean] expected_results `true` or `false`
    # @return [Boolean] pass or fail
    def perform_test_case(version, suite, num, extract_url, expected_results, options = {})
      # Build the RDF extractor URL
      extract_url = ::URI.decode(extract_url) + get_test_url(version, suite, num)

      # Retrieve the remote graph
      extracted = RDF::Util::File.open_file(extract_url)
      puts "tc: #{version}/#{suite}/#{num}" unless options[:quiet]
      puts "extract from: #{extract_url}, content-type: #{extracted.content_type.inspect}" unless options[:quiet]
      extracted_doc = extracted.read
      extracted.rewind
      puts "extracted:\n#{extracted_doc}" unless options[:quiet]
      puts "content-type: #{extracted.content_type.inspect}" unless options[:quiet]

      format_opts = {:sample => extracted_doc}
      format_opts[:content_type] = extracted.content_type if extracted.content_type

      graph = RDF::Graph.new << RDF::Reader.for(format_opts).
        new(extracted, :base_uri => get_test_url(version, suite, num))
      puts "graph:#{graph.dump(:ntriples)}" unless options[:quiet]

      # Get the SPARQL query
      sparql_query = get_test_content(version, suite, num, 'sparql')

      puts "sparql_query: #{sparql_query}" unless options[:quiet]

      # Perform the SPARQL query
      result = SPARQL.execute(StringIO.new(sparql_query), graph)
      puts "result: #{result.inspect}, expected: #{expected_results.inspect} == #{(result == expected_results).inspect}" unless options[:quiet]
      result == expected_results
    end
    module_function :perform_test_case
  end
  
  ##
  # Standalone environment for core functions
  class StandAlone
    include Core
    
    def url(offset)
      "http://#{HOSTNAME}#{offset}"
    end
  end
end
