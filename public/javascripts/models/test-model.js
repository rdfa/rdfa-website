// Test model, ID is combination of version, hostLanguage and num
window.Test = Backbone.Model.extend({
  // Calls back with retrieved source
  source: function (cb) {
    var that = this;

    // Retrieve results from processor and canonical representation
    var source_url = "test-cases/" + that.get('num');
    
    $.getJSON(source_url, cb);
  },
  
  // Get the details for a given test
  details: function (cb) {
    var that = this;

    // Retrieve results from processor and canonical representation
    var details_url = "test-details/" +
      that.get('version') +
      '/' + that.get('hostLanguage') +
      '/' + that.get('num') +
      '?rdfa-extractor=' + that.processorURL();
    
      $.getJSON(details_url, cb);
  },
  
  // Run the test, causes this.result to be set
  run: function () {
    var that = this;

    // Retrieve results from processor
    var test_url = "check-test/" +
      that.get('version') +
      '/' + that.get('hostLanguage') +
      '/' + that.get('num') +
      '?expected-results=' + that.get('expectedResults') +
      '&rdfa-extractor=' + that.processorURL();

    $.getJSON(test_url, function (data) {
      // Indicate pass/fail and style
      that.set("result", data.status);
    });
  },
  
  // Return the selected processor URI
  // This is set when the hostLanguage is selected on all selected test divs
  // The processorURL is updated with query parameters from the test-case object.
  // Reset test to original condition
  processorURL: function() {
    var url = this.get('processorURL');
    var queryParam = this.get('queryParam');

    if (queryParam) {
      // Add any parameter to the processorURL
      url = url.replace(/([\?&])([^\?&]*)$/, "$1" + this.queryParam + "&$2");
    }
    return escape(url);
  },

  reset: function () {
    this.result = this.source = this.details = null;
  }
});

// Collection of defined tests, ordered by test number.
// There is a different collection of tests for each combination of version and host language
window.TestCollection = Backbone.Collection.extend({
  model:  Test,
  
  url:    'manifest.json',
  
  initialize:   function(models, options) {
    if (options) {
      this.version = options.version;
      this.hostLanguage = options.hostLanguage;
      this.processorURL = options.processorURL;
    }
  },
  
  // Override parse() to deal with JSON-LD array semantics
  // Return tests filtered by version and hostLanguage
  parse: function(response) {
    var that = this;
    var filteredTests = _.filter(response['@id'], function(data) {
      return _.include(_.flatten([data['rdfatest:rdfaVersion']]), that.version) &&
             _.include(_.flatten([data['rdfatest:hostLanguage']]), that.hostLanguage);
    });
    
    return _.map(filteredTests, function(data) {
      // Map to native fields we're interested in
      return {
        classification: (data['test:classification'] || 'required').split(':').pop(),
        description: data['dc:title'],
        expectedResults: data['test:expectedResults'] || true,
        hostLanguage: that.hostLanguage,
        num: _.last(data['@id'].split('/')),
        processorURL: that.processorURL,
        pubpose: data['test:purpose'],
        queryParam: data['rdfatest:queryParam'],
        version: that.version
      };
    });
  },

  // Order tests by test number
  comparator: function(test) {
    return test.get('num');
  }
});
