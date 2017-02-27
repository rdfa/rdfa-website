// Test suite uses a Test model and a collection
// for each combination of version and host language.
var AppRouter = Backbone.Router.extend({
  initialize: function(options) {
    var that = this;

    // Create the version singleton, and instantiate it's view
    this.version = new Version({
      version: $('button#versions:active').attr('data-version') || "rdfa1.1",
      hostLanguage: $('button#host-languages:active').attr('data-suite') || "xml"
    });
    
    // Load processor definitions
    $.getJSON("processors.json", function(data) {
      that.version.set("processors", data);
    });

    // Load version definitions
    $.getJSON("versionNames.json", function(data) {
      that.version.set("versionNames", data);
    });

    this.versionView = new VersionView({model: this.version});
    this.hostLanguageView = new HostLanguageView({model: this.version});
    this.processorView = new ProcessorView({model: this.version});

    // Initialize Bootstrap.js features
    $(".dropdown-toggle").dropdown();
    $('.btn').button();

    // If logged in, create primary test collection and view
    this.testList = new TestCollection([], {version: this.version});
    this.runAllView = new RunAllView({model: this.testList});
    this.progressView = new ProgressView({model: this.testList});
    this.testList.fetch();
    this.testListView = new TestListView({model: this.testList});
  },

  routes: {
    "":                               "main",
    ":version":                       "version",
    ":version/:hostLanguage":         "hostLanguage",
    ":version/:hostLanguage/:test":   "test"
  },
  
  main: function() {
    this.hostLanguage(this.version.get('version'), this.version.get('hostLanguage'));
  },

  version: function(version) {
    this.version.set('version', version);
    this.hostLanguage(version, this.version.get('hostLanguage'));
  },
  
  hostLanguage: function(version, hostLanguage) {
    this.version.set({
      version: version,
      hostLanguage: hostLanguage
    });
    this.testList.filter();
  },
  
  // Just a single test
  test: function(version, hostLanguage, test) {
    this.version.set({
      version: version,
      hostLanguage: hostLanguage,
      processorURL: this.version.get('processorURL')
    });
    // Filter to just test
    this.testList.filter();
  }
});

var app = new AppRouter();
Backbone.history.start();
