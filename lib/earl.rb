# EARL reporting
require 'rdf/rdfa'
require 'rdf/turtle'
require 'json/ld'
require 'sparql'
require 'haml'
require 'crazyivan/core'

##
# EARL reporting class.
# Instantiate a new class using one or more input graphs
require 'rdf/rdfa'
require 'rdf/turtle'

class EARL
  attr_reader :graph
  PROCESSOR_QUERY = %(
    PREFIX doap: <http://usefulinc.com/ns/doap#>
    PREFIX foaf: <http://xmlns.com/foaf/0.1/>
    PREFIX rdfatest: <http://rdfa.info/vocabs/rdfa-test#>
    
    SELECT DISTINCT ?uri ?name ?developer ?dev_name ?dev_type ?doap_desc ?homepage ?language
    WHERE {
      ?uri doap:name ?name .
      OPTIONAL { ?uri doap:developer ?developer . ?developer foaf:name ?dev_name .}
      OPTIONAL { ?uri doap:developer ?developer . ?developer a ?dev_type . }
      OPTIONAL { ?uri doap:homepage ?homepage . }
      OPTIONAL { ?uri doap:description ?doap_desc . }
      OPTIONAL { ?uri doap:programming-language ?language . }
    }
  ).freeze

  ASSERTION_QUERY = %(
    PREFIX earl: <http://www.w3.org/ns/earl#>
    PREFIX mf: <http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#>
    PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
    
    SELECT ?subject ?test ?by ?mode ?outcome ?name ?description
    WHERE {
      [ a earl:Assertion;
        earl:assertedBy ?by;
        earl:mode ?mode;
        earl:result [earl:outcome ?outcome];
        earl:subject ?subject;
        earl:test ?test ] .
      ?test a earl:TestCase;
        mf:name ?name;
        rdfs:comment ?description
        .
    }
    ORDER BY ?test ?subject
  ).freeze

  SUITE_URI = "http://rdfa.info/test-suite/"
  PROCESSORS_PATH = File.expand_path("../../processors.json", __FILE__)

  # Convenience vocabularies
  class EARL < RDF::Vocabulary("http://www.w3.org/ns/earl#"); end
  class RDFATEST < RDF::Vocabulary("http://rdfa.info/vocabs/rdfa-test#"); end

  ##
  # @param [Array<String>] files
  def initialize(files)
    @graph = RDF::Repository.new
    @prefixes = {}
    [files].flatten.each do |file|
      puts "read #{file}"
      reader = case file
      when /\.ttl/ then RDF::Turtle::Reader
      when /\.html/ then RDF::RDFa::Reader
      when /\.jsonld/
        @json_hash = ::JSON.parse(File.read(file))
        return
      end
      reader.open(file) {|r| @graph << r}
    end
    
    # Flatten named graphs introduced through loading
    # so that we can query the default graph
    @graph = RDF::Graph.new << @graph

    processors = ::JSON.parse(File.read(PROCESSORS_PATH))
    processors.each do |proc, info|
      next if (proc || 'other') == 'other'
      # Load DOAP definitions
      doap_url = info["doap_url"] || info["doap"]
      puts "check for <#{info["doap"]}> in graph"
      next unless doap_url && @graph.has_subject?(RDF::URI(info["doap"]))
      doap_url = File.expand_path("../../public", __FILE__) + doap_url if doap_url[0,1] == '/'
      puts "read doap description for #{proc} from #{doap_url}"
      begin
        doap_graph = RDF::Graph.load(doap_url)
        #puts "doap: #{doap_graph.dump(:ttl)}"
        @graph << doap_graph.to_a

        # Load FOAF definitions of doap:developers
        foaf_url = doap_graph.first_object(:predicate => RDF::DOAP.developer)
        if foaf_url.url?
          foaf_graph = RDF::Graph.load(foaf_url)
          puts "read foaf description for #{proc} from #{foaf_url} with #{foaf_graph.count} triples"
          #puts "foaf: #{foaf_graph.dump(:ttl)}"
          @graph << foaf_graph.to_a
        end
      rescue
        # Ignore failure
      end
    end
    
  end

  ##
  # Dump the collesced output graph
  #
  # If there is a DOAP file associated with a processor, load it's information into the
  # graph.
  #
  # If no `io` parameter is provided, the output is returned as a string
  #
  # @param [Symbol] format
  # @param [IO] io (nil)
  # @return [String] serialized graph, if `io` is nil
  def dump(format, io = nil)
    options = {
      :base => SUITE_URI,
      :standard_prefixes => true,
      :prefixes => { :earl => "http://www.w3.org/ns/earl#", }
    }

    ##
    # Retrieve Hashed information in JSON-LD format
    case format
    when :jsonld
      json = json_hash.to_json(::JSON::State.new(
        :indent       => "  ",
        :space        => " ",
        :space_before => "",
        :object_nl    => "\n",
        :array_nl     => "\n"
      ))
      io.write(json) if io
      json
    when :turtle, :ttl
      if io
        earl_turtle(io)
      else
        io = StringIO.new
        earl_turtle(io)
        io.rewind
        io.read
      end
    else
      if io
        RDF::Writer.for(format).new(io) {|w| w << graph}
      else
        graph.dump(format, options)
      end
    end
  end

  ##
  # Generate output report, using Haml template
  # If no `io` parameter is provided, the output is returned as a string
  #
  # @param [IO, String, Hash] json
  # @param [Array<String>] source_files
  # @param [IO] io (nil)
  # @return [String] Generated report, if `io` is nil
  def self.generate(json, source_files, io = nil)
    json = json.read if json.respond_to?(:read)
    tests = json.is_a?(String) ? ::JSON.parse(json) : json

    template = File.read(File.expand_path('../views/earl_report.html.haml', __FILE__))

    html = Haml::Engine.new(template, :format => :xhtml).render(self, {:tests => tests, :source_files => source_files})
    io.write(html) if io
    html
  end
  
  private
  
  ##
  # Return hashed EARL reports in JSON-LD form
  # @return [Hash]
  def json_hash
    @json_hash ||= begin
      # Customized JSON-LD output
      hash = Hash.ordered
      hash["@context"] = "http://rdfa.info/contexts/rdfa-earl.jsonld"
      hash["@id"] = SUITE_URI
      hash["@type"] = %w(earl:Software doap:Project)
      hash['homepage'] = "http://rdfa.info/"
      hash['name'] = "RDFa Test Suite"
      hash['processor'] = json_test_subject_info
      hash['manifests'] = json_result_info
      hash
    end
  end

  ##
  # Return array of processor information
  # @return [Array]
  def json_test_subject_info
    # Get the set of processors
    @subject_info ||= begin
      proc_info = {}
      SPARQL.execute(PROCESSOR_QUERY, @graph).each do |solution|
        #puts "solution #{solution.to_hash.inspect}"
        next if solution[:uri].to_s == SUITE_URI
        info = proc_info[solution[:uri].to_s] ||= {}
        %w(name doap_desc homepage language).each do |prop|
          info[prop] = solution[prop.to_sym].to_s if solution[prop.to_sym]
        end
        if solution[:dev_name]
          dev_type = solution[:dev_type].to_s =~ /Organization/ ? "foaf:Organization" : "foaf:Person"
          info['developer'] = Hash.ordered
          info['developer']['@id'] = solution[:developer].to_s if solution[:developer].uri?
          info['developer']['@type'] = dev_type
          info['developer']['foaf:name'] = solution[:dev_name].to_s if solution[:dev_name]
        end
      end

      # Map ids and values to array entries
      proc_info.keys.sort.map do |id|
        info = proc_info[id]
        processor = Hash.ordered
        processor["@id"] = id
        processor["@type"] = %w(earl:TestSubject doap:Project)
        %w(name developer doap_desc homepage language).each do |prop|
          processor[prop] = info[prop] if info[prop]
        end
        processor
      end
    end
  end

  ##
  # @return [Array<Hash>]
  def json_result_info
    puts "check results"
    manifests = []
    subjects = json_test_subject_info.map {|s| s['@id']}

    # Iterate through assertions and add to appropriate test case
    SPARQL.execute(ASSERTION_QUERY, @graph).each do |solution|
      uri = solution[:test].to_s
      puts solution.inspect
      manifest = uri.split('#').first
      hl_vers = manifests.detect {|m| m['@id'] == manifest}
      # Create entry for this manifest, if it doesn't already exist
      unless hl_vers
        puts "version: #{manifest}"
        manifest_title = solution[:test].to_s.match(%r{/([a-z0-9-\.]*)/([a-z0-9]*)/manifest}) && "#{$2}+#{$1}"
        raise "version, host language not found in #{solution[:test]}" unless manifest_title
        hl_vers = {
          "@id" => manifest,
          'title' => manifest_title,
          'tests' => []
        }
        manifests << hl_vers
      end

      # Create entry for this test case, if it doesn't already exist
      tc = hl_vers['tests'].detect {|t| t['@id'] == uri}
      unless tc
        puts "Test case: #{solution[:name]}"
        tc = {
          "@id" => uri,
          "@type" => "earl:TestCase",
          'title' => solution[:name].to_s,
          'description' => solution[:description].to_s,
          'mode' => "",
          'assertions' => []
        }

        # Pre-initialize results for each subject to untested
        subjects.each do |siri|
          tc['assertions'] << {
            '@type' => 'earl:Assertion',
            'assertedBy' => SUITE_URI,
            'test'    => uri,
            'subject' => siri,
            'mode' => "earl:automatic",
            'result' => {
              '@type' => 'earl:TestResult',
              'outcome' => 'earl:untested'
            }
          }
        end

        hl_vers['tests'] << tc
      end

      # Assertion info
      assertion = tc['assertions'].detect {|a| a['subject'] == solution[:subject].to_s}
      raise "Assertion not found for #{solution.inspect}" unless assertion
      assertion['mode'] = "earl:#{solution[:mode].to_s.split('#').last || 'automatic'}"
      assertion['result']['outcome'] = "earl:#{solution[:outcome].to_s.split('#').last}"
    end

    manifests
  end
  
  ##
  # Output consoloated EARL report as Turtle
  # @param [IO, StringIO] io
  # @return [String]
  def earl_turtle(io)
    # Write preamble
    #{
    #  :dc       => RDF::DC,
    #  :doap     => RDF::DOAP,
    #  :earl     => ::EARL::EARL,
    #  :foaf     => RDF::FOAF,
    #  :owl      => RDF::OWL,
    #  :rdf      => RDF,
    #  :rdfa     => RDF::RDFA,
    #  :rdfatest => RDFATEST,
    #  :rdfs     => RDF::RDFS,
    #  :xhv      => RDF::XHV,
    #  :xsd      => RDF::XSD
    #}.each do |prefix, vocab|
    #  io.puts("@prefix #{prefix}: <#{vocab.to_uri}> .")
    #end
    #io.puts
    #
    ## Write earl:Software
    #io.puts %(<#{json_hash['@id']}> a earl:Softare, doap:Project;)
    #io.puts %(  doap:homepage <#{json_hash['homepage']}>;)
    #io.puts %(  doap:name "#{json_hash['homepage']}" .)
  end
  
  ##
  # Write out Processor definition for each earl:TestSubject
  # @param [Hash] desc
  # @return [String]
  def proc_turtle(desc)
    developer = desc['developer']
    res = %(<#{desc['@id']}> a #{desc['@type'].join(', ')}\n)
    res += %(  doap:name "#{desc['name']}";\n)
    res += %(  doap:description """#{desc['doap_desc']}""";\n)     if desc['doap_desc']
    res += %(  doap:programming-language "#{desc['language']}";\n) if desc['language']
    if developer && developer['@id']
      res += %(  doap:developer <#{developer['@id']}> .\n)
      res += %(<#{developer['@id']}> a #{[developer['@type']].flatten.join(', ')} )
      res += %(foaf:name "#{developer['foaf:name']}" .\n)
    elsif developer
      res += %(  doap:developer [ a #{developer['@type'] || "foaf:Person"}; foaf:name "#{developer['foaf:name']}"] .\n)
    else
      res += %(  .\n)
    end
    res + "\n"
  end
  
  ##
  # Write out each Test Case definition
  # @prarm[Hash] desc
  # @return [String]
  def tc_turtle(desc)
    res = %(<#{desc['@id']}> a #{[desc['@type']].flatten.join(', ')};\n)
    res += %(  dc:title "#{desc['title']}";\n)
    res += %(  dc:description """#{desc['description']}""";\n)
    res += %(  rdfatest:num "#{desc['num']}";\n)
    res += %(  rdfatest:rdfaVersion #{desc['version'].sort.uniq.map(&:dump).join(', ')};\n)
    res += %(  rdfatest:hostLanguage #{desc['hostLanguage'].sort.uniq.map(&:dump).join(', ')}.\n)
    res + "\n"
  end

  ##
  # Write out each Assertion definition
  # @prarm[Hash] desc
  # @return [String]
  def as_turtle(desc)
    res =  %([ a earl:Assertion\n)
    res += %(  earl:assertedBy <#{desc['assertedBy']}>;\n)
    res += %(  earl:test <#{desc['test']}>;\n)
    res += %(  earl:subject <#{desc['subject']}>;\n)
    res += %(  earl:mode #{desc['mode']};\n)
    res += %(  earl:result [ a earl:Result; #{desc['result']['outcome']}] ] .\n)
    res += %(\n)
    res
  end
end
