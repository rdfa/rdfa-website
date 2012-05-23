// Version, Host Language, and Processor URL
window.Version = Backbone.Model.extend({
  defaults: {
    processorURL: "http://www.w3.org/2012/pyRdfa/extract?uri=",
    processorName: "pyRdfa (Python)",
    processorDOAP: "http://www.w3.org/2012/pyRdfa",

    // List of processors
    processors: {"other": {endpoint: "", doap: ""}},

    // Names to give each vesion, initialized forom Ajax
    versionNames: {},

    // Mapping of version to hostLanguage/suite which uses it
    versionHostLanguageMap: {"rdfa1.0": ["XHTML1", "XML"]}
  },
  
  // Appropriate hostLanguages/suites for the current version
  hostLanguages: function() {
    return this.get("versionHostLanguageMap")[this.get("version")];
  }
});
