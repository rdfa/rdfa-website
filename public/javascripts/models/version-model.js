// Version, Host Language, and Processor URL
window.Version = Backbone.Model.extend({
  defaults: {
    processorURL: "http://www.w3.org/2012/pyRdfa/extract?uri=",
    processorName: "pyRdfa",
    processorDOAP: "http://www.w3.org/2012/pyRdfa",

    // List of processors
    processors: {
      "other":  {
        endpoint: "",
        doap: ""
      }
    }
  },

  // Appropriate suites for the current version
  hostLanguages: function() {
    return {
      "rdfa1.0": ["SVG", "XHTML1"],
      "rdfa1.1": ["HTML4", "HTML5", "SVG", "XHTML1", "XHTML5", "XML"],
      "rdfa1.1-vocab": ["HTML4", "HTML5", "SVG", "XHTML1", "XHTML5", "XML"]
    }[this.get("version")];
  }
});
