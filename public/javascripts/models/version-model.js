// Version, Host Language, and Processor URL
window.Version = Backbone.Model.extend({
  defaults: {
    processorURL: "http://www.w3.org/2012/pyRdfa/extract?uri="
  },

  // List of processors
  processors: {
    "pyrdfa": "http://www.w3.org/2012/pyRdfa/extract?uri=",
    "RDF.rb": "http://rdf.greggkellogg.net/distiller?raw=true&in_fmt=rdfa&uri=",
    "other":  ""
  },
  
  // Appropriate suites for the current version
  hostLanguages: function() {
    return {
      "rdfa1.0": ["SVG", "XHTML1"],
      "rdfa1.1": ["HTML4", "HTML5", "SVG", "XHTML1", "XHTML5", "XML1"],
      "rdfa1.1-vocab": ["HTML4", "HTML5", "SVG", "XHTML1", "XHTML5", "XML1"]
    }[this.get("version")];
  }
});
