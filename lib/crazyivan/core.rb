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

    ##
    # Return the Manifest source
    def manifest_ttl
      @manifest_ttl = File.read(MANIFEST_FILE)
    end
    module_function :manifest_ttl

    ##
    # Return the Manifest source
    def manifest_json
      unless File.exist?(MANIFEST_JSON) && File.mtime(MANIFEST_JSON) >= File.mtime(MANIFEST_FILE)
        ::JSON::LD::Writer.open(MANIFEST_JSON,
          :standard_prefixes => true,
          :prefixes => {
            :test => "http://www.w3.org/2006/03/test-description#",
            :rdfatest => "http://rdfa.info/vocabs/rdfa-test#", # FIXME: new name?
          }) {|w| w << graph}
      end
      @manifest_json = File.read(MANIFEST_JSON)
    end
    module_function :manifest_json

    ##
    # Return Manifest graph
    def graph
      @graph ||= RDF::Graph.load(MANIFEST_FILE, :format => :turtle, :base_uri => url("test-suite/manifest.ttl"))
    end
    module_function :graph

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
        sub(/localhost:\d+/, 'rdfainfo.digitalbazaar.com') # For local testing
    end
    module_function :get_test_url

    ##
    # Get the content for a test
    #
    # @param [String] version "xhtml1", "html5" ...
    # @param [String] suite "rdfa1.1" or other
    # @param [String] num "0001" or greater
    # @param [String] format "sparql", nil
    # @return [{:namespaces => {}, :content => String, :suite => String, :version => String}]
    #   Serialized document and namespaces
    def get_test_content(version, suite, num, format = nil)
      suffix = case suite
      when /xhtml/  then "xhtml"
      when /html/   then "html"
      when /svg/    then "svg"
      else               "xml"
      end

      filename = TESTS_PATH + "/#{num}.#{format == 'sparql' ? 'sparql' : 'txt'}"
      tcpath = url("/test-suite/test-cases/#{version}/#{suite}").
        sub(/localhost:\d+/, 'rdfainfo.digitalbazaar.com') # For local testing

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

      # Short cut document text
      prefixes = {}
      doc_text = get_test_content(version, suite, num)
      doc_graph = RDF::Graph.new << RDF::RDFa::Reader.new(doc_text, :format => :rdfa, :prefixes => prefixes)

      # Turtle version of default graph
      ttl_text = doc_graph.dump(:turtle, :prefixes => prefixes, :base_uri => doc_url)
      sparql_url = get_test_url(version, suite, num, 'sparql')
      sparql_text = get_test_content(version, suite, num, 'sparql')

      # Extracted version of default graph
      extract_url = ::URI.decode(params["rdfa-extractor"]) + ::URI.encode(doc_url)
      begin
        extracted_text = RDF::Util::File.open_file(extract_url).read
      rescue Exception => e
        puts "error extracting text: #{e.class}: #{e.message}"
        extracted_text = e.message
      end

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
      tests = ::JSON.load(manifest_json)['@id']
      test = tests.detect {|t| t['@id'] == "http://rdfa.info/test-suite/test-cases/#{num}"}
    
      entries = []
      [test["rdfatest:hostLanguage"]].flatten.each do |host_language|
        suffix = case host_language.to_s
        when /xhtml/  then "xhtml"
        when /html/   then "html"
        when /svg/    then "svg"
        else               "xml"
        end
        [test["rdfatest:rdfaVersion"]].flatten.each do |version|
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
    def perform_test_case(version, suite, num, extract_url, expected_results)
      # Build the RDF extractor URL
      extract_url = ::URI.decode(extract_url) + get_test_url(version, suite, num)

      # Get the SPARQL query
      sparql_query = get_test_content(version, suite, num, 'sparql').
        sub("ASK WHERE", "ASK FROM <#{extract_url}> WHERE")

      puts "sparql_query: #{sparql_query}"

      # Perform the SPARQL query
      result = SPARQL.execute(StringIO.new(sparql_query), nil)
      puts "result: #{result.inspect}, expected: #{expected_results.inspect} == #{(result == expected_results).inspect}"
      result == expected_results
    end
    module_function :perform_test_case
  end
end