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
    
    SELECT ?subject ?test ?by ?mode ?outcome
    WHERE {
      [ a earl:Assertion;
        earl:assertedBy ?by;
        earl:mode ?mode;
        earl:result [earl:outcome ?outcome];
        earl:subject ?subject;
        earl:test ?test ] .
    }
    ORDER BY ?test ?subject
  ).freeze

  VOCAB_QUERY = %(
    PREFIX dc: <http://purl.org/dc/terms/>
    PREFIX owl: <http://www.w3.org/2002/07/owl#>
    PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
    
    SELECT DISTINCT ?prop ?label ?description
    WHERE {
      ?prop a owl:DatatypeProperty;
        rdfs:label ?label;
        dc:description ?description .
    }
  )

  SUITE_URI = "http://rdfa.info/test-suite/"
  PROCESSORS_PATH = File.expand_path("../../processors.json", __FILE__)
  MANIFEST_PATH = File.expand_path("../../manifest.jsonld", __FILE__)

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
      next unless doap_url && @graph.has_object?(RDF::URI(info["doap"]))
      doap_url = File.expand_path("../../public", __FILE__) + doap_url if doap_url[0,1] == '/'
      puts "read doap description for #{proc} from #{doap_url}"
      begin
        doap_graph = RDF::Graph.load(doap_url)
        puts "doap: #{doap_graph.dump(:ttl)}"
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
      hash['entries'] = json_result_info
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
      proc_info.keys.sort_by {|id| proc_info[id]['name'].downcase}.map do |id|
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
  # Return information about JSON vocabularies
  # @return [Hash]
  def json_vocabulary_info
    @vocab_info ||= begin
      # Get vocabulary information for documentation
      vocab_graph = RDF::Graph.load(File.expand_path("../../public/vocabs/rdfa-test.html", __FILE__))
      vocab_info = {}
      SPARQL.execute(VOCAB_QUERY, vocab_graph).each do |solution|
        prop_name = solution[:prop].to_s.split('/').last
        vocab_info[prop_name] = {
          "@id"         => prop_name,
          "label"       => solution[:label].to_s,
          "description" => solution[:description].to_s
        }
      end
      vocab_info
    end
  end


  ##
  # Expected results for each test number
  # @return [Hash{String => TrueClass, FalseClass}]
  def manifest_info
    @manifest_info ||= begin
      man = ::JSON.parse(File.read(MANIFEST_PATH))
      man['@graph'].inject({}) do |memo, t|
        memo[t['num']] = {
          :name => "Test #{t['num']}: #{t['description']}",
          :description => t['purpose'].strip.gsub(/\s+/m, ' '),
          :expectedResults => t.fetch('expectedResults', true)
        }
        memo
      end
    end
  end

  ##
  # @return [Array<Hash>]
  def json_result_info
    manifests = []
    subjects = json_test_subject_info.map {|s| s['@id']}

    # Iterate through assertions and add to appropriate test case
    SPARQL.execute(ASSERTION_QUERY, @graph).each do |solution|
      uri = solution[:test].to_s
      manifest = uri.split('#').first
      solution[:test].to_s.match(%r{/([a-z0-9\-\.]*)/([a-z0-9]*)/manifest})
      version, hostLanguage = $1, $2
      raise "version, host language not found in #{solution[:test]}" unless version && hostLanguage
      hl_vers = manifests.detect {|m| m['@id'] == manifest}
      # Create entry for this manifest, if it doesn't already exist
      unless hl_vers
        puts "version: #{version}, hostLanguage: #{hostLanguage}"
        hl_info = json_vocabulary_info[hostLanguage]
        vers_info = json_vocabulary_info[version]
        hl_vers = {
          "@id" => manifest,
          "@type" => %w{earl:Report mf:Manifest},
          'title' => "#{hl_info['label']}+#{vers_info['label']}",
          'hostLanguage' => hostLanguage,
          'version' => version,
          'description' => [
            vers_info['description'].strip.gsub(/\s+/m, ' '),
            hl_info['description'].strip.gsub(/\s+/m, ' ')
          ],
          'entries' => []
        }
        manifests << hl_vers
      end

      # Create entry for this test case, if it doesn't already exist
      tc = hl_vers['entries'].detect {|t| t['@id'] == uri}
      unless tc
        num = uri.split('#').last
        #puts "Test case: #{solution[:name]}"
        tc = {
          "@id" => uri,
          "@type" => %w(earl:TestCase mf:QueryEvaluationTest),
          'title' => manifest_info[num][:name],
          'description' => manifest_info[num][:description],
          'testAction' => {
            '@type' => 'qt:QueryTest',
            'queryForm' => 'qt:QueryAsk',
            'query' => CrazyIvan::Core::get_test_url(version, hostLanguage, num, 'sparql'),
            'data' => CrazyIvan::Core::get_test_url(version, hostLanguage, num)
          },
          'testResult' => manifest_info[num][:expectedResults],
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

        hl_vers['entries'] << tc
      end

      # Assertion info
      assertion = tc['assertions'].detect {|a| a['subject'] == solution[:subject].to_s}
      raise "Assertion not found for #{solution[:subject]} in #{tc['assertions'].map{|a| a['subject']}.inspect}\nsubjects: #{subjects.inspect}" unless assertion
      assertion['mode'] = "earl:#{solution[:mode].to_s.split('#').last || 'automatic'}"
      assertion['result']['outcome'] = "earl:#{solution[:outcome].to_s.split('#').last}"
    end

    manifests.sort_by {|m| "#{m['hostLanguage']} #{m['version']}"}
  end
  
  ##
  # Output consoloated EARL report as Turtle
  # @param [IO, StringIO] io
  # @return [String]
  def earl_turtle(io)
    # Write preamble
    {
      :dc       => RDF::DC,
      :doap     => RDF::DOAP,
      :earl     => ::EARL::EARL,
      :foaf     => RDF::FOAF,
      :mf       => "http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#",
      :owl      => RDF::OWL,
      :rdf      => RDF,
      :rdfa     => RDF::RDFA,
      :rdfatest => RDFATEST,
      :rdfs     => RDF::RDFS,
      :xhv      => RDF::XHV,
      :xsd      => RDF::XSD
    }.each do |prefix, vocab|
      io.puts("@prefix #{prefix}: <#{vocab.respond_to?(:to_uri) ? vocab.to_uri : vocab}> .")
    end
    io.puts
    
    # Write earl:Software
    io.puts %(<#{json_hash['@id']}> a earl:Software, doap:Project;)
    io.puts %(  doap:homepage <#{json_hash['homepage']}>;)
    io.puts %(  doap:name "#{json_hash['name']}";)
    
    # Processors
    proc_defs = json_hash['processor'].map {|defn| "<#{defn['@id']}>"}.join(",\n    ")
    io.puts %(  rdfa:processor #{proc_defs};)

    # Manifests
    man_defs = json_hash['entries'].map {|defn| "<#{defn['@id']}>"}.join("\n    ")
    io.puts %(  mf:entries (\n    #{man_defs}) .\n)

    # Output Manifest definitions
    # along with test cases and assertions
    test_cases = []
    io.puts %(\n# Manifests)
    json_hash['entries'].each do |man|
      io.puts %(<#{man['@id']}> a earl:Report, mf:Manifest;)
      io.puts %(  dc:title "#{man['title']}";)
      io.puts %(  mf:name "#{man['title']}";)
      descriptions = man['description'].map {|d| %("""#{d}"""^^rdf:HTML)}
      io.puts %(  dc:description\n    ) + descriptions.join(",\n    ") + ';'
      
      # Test Cases
      test_defs = man['entries'].map {|defn| "<#{defn['@id']}>"}.join("\n    ")
      io.puts %(  mf:entries (\n    #{test_defs}) .\n\n)

      test_cases += man['entries']
    end
    
    # Write out each earl:TestSubject
    io.puts %(#\n# Processor Definitions\n#)
    json_hash['processor'].each do |proc_desc|
      io.write(proc_turtle(proc_desc))
    end
    
    # Write out each earl:TestCase
    io.puts %(#\n# Test Case Definitions\n#)
    test_cases.sort_by {|tc| tc['title']}.each do |tc|
      io.write(tc_turtle(tc))
    end
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
    %(<#{desc['@id']}> a #{[desc['@type']].flatten.join(', ')};
      mf:name "#{desc['title']}";
      mf:action [ a qt:QueryTest; qt:queryForm qt:QueryAsk;
        qt:query <#{desc['testAction']['query']}>;
        qt:data <#{desc['testAction']['data']}> ];
      mf:result #{desc['testResult']};
      dc:title "#{desc['title']}";
      dc:description """#{desc['description']}""";
      earl:assertions (#{desc['assertions'].map {|a| as_turtle(a)}.join("")}
      ) .

).gsub(/^      /, '  ')
  end

  ##
  # Write out each Assertion definition
  # @prarm[Hash] desc
  # @return [String]
  def as_turtle(desc)
    %(
        [ a earl:Assertion;
          earl:assertedBy <#{desc['assertedBy']}>;
          earl:test <#{desc['test']}>;
          earl:subject <#{desc['subject']}>;
          earl:mode #{desc['mode']};
          earl:result [ a earl:Result; #{desc['result']['outcome']}] ])
  end
end
