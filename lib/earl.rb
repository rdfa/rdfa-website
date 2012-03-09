# EARL reporting
require 'rdf/rdfa'
require 'rdf/turtle'

##
# EARL reporting class.
# Instantiate a new class using one or more input graphs
require 'rdf/rdfa'
require 'rdf/turtle'

class EARL
  attr_reader :graph
  
  ##
  # @param [Array<String>] files
  def initialize(files)
    @graph = RDF::Graph.new
    @prefixes = {}
    files.each do |file|
      reader = case file
      when /\.ttl/ then RDF::Turtle::Reader
      when /\.html/ then RDF::RDFa::Reader
      end
      @graph << reader.open(file)
    end
  end

  ##
  # Dump the collesced output graph
  #
  # If no `io` parameter is provided, the output is returned as a string
  #
  # @param [Symbol] format
  # @param [IO] io (nil)
  # @return [String] serialized graph, is `io` is nil
  def dump(format, io = nil)
    options = {
      :base => "http://rdfa.info/test-suite/",
      :prefixes => {
        :earl => "http://www.w3.org/ns/earl#",
        :doap => "http://usefulinc.com/ns/doap#"
      }
    }
    if io
      RDF::Writer.for(format).dump(@graph, io, options)
    else
      @graph.dump(format, options)
    end
  end

  ##
  # Generate output report, using Haml templates
  def generate
  end
end
