#/usr/bin/env ruby
# Usage merged-to-variant [html4|html5|xhtml|svg]
require 'linkeddata'

HOST_LANGUAGE = RDF::URI("http://www.w3.org/2006/03/test-description#hostLanguage")
variant = ARGV[0] || "xhtml"

manifests = {
  "html4" => RDF::URI("http://rdfa.digitalbazaar.com/test-suite/html4-manifest"),
  "html5" => RDF::URI("http://rdfa.digitalbazaar.com/test-suite/html5-manifest"),
  "svg" =>   RDF::URI("http://rdfa.digitalbazaar.com/test-suite/svgtiny-manifest"),
  "xhtml" => RDF::URI("http://rdfa.digitalbazaar.com/test-suite/xhtml-manifest"),
}

r = RDF::N3::Reader.new(File.open("manifest.ttl"))
g = RDF::Graph.new << r
subjects = g.query(:object => manifests[variant]).to_a.map(&:subject).uniq
#puts "subjects for #{variant}: #{subjects.inspect}"

puts RDF::RDFXML::Writer.buffer(
  :prefixes => r.prefixes,
  :base_uri => "http://rdfa.digitalbazaar.com/test-suite/") { |w|

  g.each_triple do |s, p, o|
    next if !subjects.include?(s) || p == HOST_LANGUAGE
    s = RDF::URI(s.to_s.sub("test-cases", "test-cases/#{variant}"))
    if o.uri?
      o = RDF::URI(o.to_s.sub("test-cases", "test-cases/#{variant}"))
      case variant
      when 'xhtml'
        o = RDF::URI(o.to_s.sub(/\.html$/, ".xhtml"))
      when 'svg'
        o = RDF::URI(o.to_s.sub(/\.html$/, ".svg"))
      end
    end
    w << [s, p, o]
  end
}
