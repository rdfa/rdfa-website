#!/usr/bin/env ruby
# Re-creates host-language specific manifests from a merged manifest
#
# Usage merged-to-variant [html4|html5|xhtml|svgtiny]
#
# Without an argument, it re-creates all manifests.
require 'linkeddata'
require 'getoptlong'

save_manifests = false

opts = GetoptLong.new(
  ["--save", GetoptLong::NO_ARGUMENT]
)
opts.each do |opt, arg|
  case opt
  when '--save' then save_manifests = true
  end
end

TD = RDF::Vocabulary.new("http://www.w3.org/2006/03/test-description#")
  
r = RDF::N3::Reader.new(File.open("manifest.ttl"))
g = RDF::Graph.new << r

# Extract specific host language manifest URIs from test:hostLanguage
manifests = {}
g.query(:predicate => TD.hostLanguage) do |stmt|
  hl = stmt.object.to_s.split("/").last.sub("-manifest", "")
  manifests[hl] ||= stmt.object
end

# For each variant in the argument list, or for all detected variants
variants = ARGV
variants = manifests.keys if variants.empty?

variants.each do |variant|
  subjects = g.query(:object => manifests[variant]).to_a.map(&:subject).uniq

  out = if save_manifests
    fn = manifests[variant].to_s.split("/").last + ".rdf"
    puts "Write manifest for #{variant} to #{fn}"
    File.open(fn, "wb")
  else
    puts "\nManifest for #{variant}:\n"
    STDOUT
  end
      
  # As a special case, the path is "xhtml1" for the "xhtml" variant
  variant = "xhtml1" if variant == "xhtml"

  RDF::RDFXML::Writer.new(out,
    :prefixes => r.prefixes,
    :base_uri => "http://rdfa.digitalbazaar.com/test-suite/") { |w|

    g.each_triple do |s, p, o|
      next if !subjects.include?(s) || p == TD.hostLanguage
      s = RDF::URI(s.to_s.sub("test-cases", "test-cases/#{variant}"))
      if o.uri?
        o = RDF::URI(o.to_s.sub("test-cases", "test-cases/#{variant}"))
        case variant
        when 'xhtml1'
          o = RDF::URI(o.to_s.sub(/\.html$/, ".xhtml"))
        when 'svgtiny'
          o = RDF::URI(o.to_s.sub(/\.html$/, ".svg"))
        end
      end
      w << [s, p, o]
    end
  }
end