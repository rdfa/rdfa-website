$(function () {
   var CrazyIvan = function(testObject) {
    this.value = testObject;
    this.num = testObject["@id"].split('/').pop();
    this.hostLanguages = testObject['rdfatest:hostLanguage'];
    this.versions = testObject['rdfatest:rdfaVersion'];
    this.description = testObject['dc:title'];
    this.classification = (testObject['test:classification'] || 'test:required').split(':').pop();
    this.expectedResults = testObject['test:expectedResults'];
    if (this.expectedResults === undefined) { this.expectedResults = true; }
    this.queryParam = testObject['rdfatest:queryParam'];
    this.result = "unknown";
    
    if (!(this.hostLanguages instanceof Array)) { this.hostLanguages = [this.hostLanguages]; }
    if (!(this.versions instanceof Array)) { this.versions = [this.versions]; }
  };
  
  CrazyIvan.prototype = {
    // Indicates if this test is active
    active: function() {
      $this.div.visible();
    },

    // Return the selected version string
    // This is set when the version is selected on all selected test divs
    version: function() {
      return $("#tests").attr('data-version');
    },

    // Return the selected hostLanguage
    // This is set when the hostLanguage is selected on all selected test divs
    suite: function() {
      return $("#tests").attr('data-suite');
    },

    // Return the selected processor URI
    // This is set when the hostLanguage is selected on all selected test divs
    // The processorURL is updated with query parameters from the test-case object.
    processorURL: function() {
      var url = $("#processor-url").val();
      if (this.queryParam) {
        // Add any parameter to the processorURL
        url = url.replace(/([\?&])([^\?&]*)$/, "$1" + this.queryParam + "&$2");
      }
      return escape(url);
    },

    newTest: function() {
      var $testButton = this.testButton();
      var $detailButton = this.detailButton();
      var $sourceButton = this.sourceButton();

      // Add each test
      var $testDiv = $("<div>").addClass("row version").attr('id', "unit-test-" + this.num)
        .append($('<div>').addClass('span12')
          .append($('<div>').addClass('row')
            .append($('<div>').addClass('span1').append($testButton))
            .append($('<div>').addClass('span8')
              .append($('<span>').addClass('test-num').text("Test " + this.num))
              .append(" (")
              .append($('<span>').addClass('classification').text(this.classification))
              .append("): ")
              .append($('<span>').addClass('description').text(this.description)))
            .append($('<div>').addClass('span3 pull-right')
              .append($detailButton)
              .append($sourceButton))));

      // Add clases for each suite and host-language
      $.each(this.versions, function(index, version) {
        $testDiv.addClass(version == 'rdfa1.0' ? 'rdfa1_0' : 'rdfa1_1');
      });
      $.each(this.hostLanguages, function(index, hostLanguage) {
        $testDiv.addClass(hostLanguage);
      });
      
      return this.div = $testDiv;
    },
    
    testButton: function() {
      var that = this;
      return $('<button>')
        .button()
        .addClass('btn btn-primary test')
        .attr('data-loading-text', "Running")
        .attr('autocomplete', 'off')
        .text("Test")
        .click(function() {
          var button = this;
          $(this).button('loading');
          
          // Retrieve results from processor and canonical representation
          var test_url = "check-test/" +
            that.suite() +
            '/' + that.version() +
            '/' + that.num +
            '?expected-results=' + that.expectedResults +
            '&rdfa-extractor=' + that.processorURL();

          $.getJSON(test_url, function (data) {
            // Indicate pass/fail and style
            that.result = data.status;
            var btn_class = data.status == "PASS" ? "btn-success" : "btn-danger";
            $(button)
              .button('reset')
              .text(data.status)
              .removeClass("btn-primary")
              .addClass(btn_class)
              .trigger('complete');
          });
        });
    },
    
    // Test detail button
    detailButton: function() {
      var that = this;
      return $('<button>')
        .button()
        .addClass('btn btn-info')
        .attr('data-loading-text', "Loading details ...")
        .attr('data-complete-text', "details")
        .attr('autocomplete', 'off')
        .text("details")
        .click(function() {
          var button = this;
          $(this).button('loading');
          
          // Retrieve results from processor and canonical representation
          var details_url = "test-details/" +
            that.suite() +
            '/' + that.version() +
            '/' + that.num +
            '?rdfa-extractor=' + that.processorURL();

          $.getJSON(details_url, function (data) {
            $(button).button("complete");
            var $detailsDiv = $('<div>')
              .alert()
              .attr('id', 'unit-test-details-' + that.num)
              .attr('data-dismiss', 'alert')
              .addClass('row alert fade in')
              .append($('<a>').addClass('close').text('x'));

            // Content of details pane
            $detailsDiv
              .append($("<h3>Source Document</h3>"))
              .append($("<pre>").append($('<div/>').text(data.doc_text).html()))
              .append($("<em/>")
                .append("Source ")
                .append($("<a/>").attr("href", data.doc_url).text(data.doc_url)))
              .append($("<h3>Turtle (Reference Implementation Triples)</h3>"))
              .append($("<pre>").append($('<div/>').text(data.ttl_text).html()))
              .append($("<h3>Extracted</h3>"))
              .append($("<pre>").append($('<div/>').text(data.extracted_text).html()))
              .append($("<em/>")
                .append("Source ")
                .append($("<a/>").attr("href", data.extract_url).text(data.extract_url)))
              .append($("<h3>SPARQL Test</h3>"))
              .append($("<pre>").append($('<div/>').text(data.sparql_text).html()))
              .append($("<em/>")
                .append("Source ")
                .append($("<a/>").attr("href", data.sparql_url).text(data.sparql_url)));

            $("div#unit-test-" + that.num + " > div").append($detailsDiv);
          });
        });
    },
    
    // Source button
    sourceButton: function() {
      var that = this;
      return $('<button>')
        .button()
        .addClass('btn btn-info')
        .attr('data-loading-text', "Loading tests ...")
        .attr('data-complete-text', "source")
        .attr('autocomplete', 'off')
        .text("source")
        .click(function() {
          var button = this;
          $(this).button('loading');

          // Get test URIs associated with this test
          $.getJSON("test-cases/" + that.num, function(data) {
            $(button).button("complete");
            var $sourceDiv = $('<div>')
              .alert()
              .attr('id', 'unit-test-source-' + that.num)
              .attr('data-dismiss', 'alert')
              .addClass('row alert fade in')
              .append($('<a>').addClass('close').text('x'));

            $.each(data, function(index, tc) {
                $('<a>')
                  .attr('href', tc.doc_uri)
                  .text(tc.suite_version)
                  .appendTo($sourceDiv);
                 $('<br/>').appendTo($sourceDiv);
            });
            
            $("div#unit-test-" + that.num + " > div").append($sourceDiv);
          });
        });
    },
    
    // Generate an EARL report for this test case
    earl: function() {
      var details_url = "test-details/" +
        this.suite() +
        '/' + this.version() +
        '/' + this.num +
        '?rdfa-extractor=' + this.processorURL();
      var test_url = "check-test/" +
        that.suite() +
        '/' + that.version() +
        '/' + that.num +
        '?expected-results=' + that.expectedResults +
        '&rdfa-extractor=' + that.processorURL();

      $('<div typeof="earl:Assertion"/>')
        .attr('about', details_url)
        .append($('<dl><dt>Assertor</dt></dl>')
          .append($('<dd property="assertedBy"/>')
            .attr('resource', url())
            .text('RDFa Test Suite'))
          .append($('<dt>Test Subject</dt>'))
          .append($('<dd property="earl:subject"/>')
            .attr('resource', this.processorURL())
            .append('<a/>').attr('href', this.processorURL()))
          .append($('<dt>Test Criterion</dt>'))
          .append($('<dd rel="earl:test" typeof="earl:TestCase"/>')
            .attr('resource', test_url)
            .append($('<h3 property="dc:title">').text(this.title))
            .append($('<p property="dc:description">')).text(this.description))
          .append($('<dt>Test Result</dt>'))
          .append($('<dd rel="earl:result" typeof="earlTestResult"')
            .append($('<span property="earl:outcome"')
              .attr('resource', 'earl:' + this.result.downcase())
              .text(this.result))));
    },
    
    reset: function() {
      this.div
        .removeClass('btn-success btn-danger')
        .addClass('btn-primary')
        .button('reset');
      this.result = "unknown";
    }
  };

  function resetTests() {
    $("div.row.version button.test")
      .removeClass('btn-success btn-danger')
      .addClass('btn-primary')
      .button('reset');
    $("div.test-progress").hide();
  }

  function selectVersion(version, suite) {
    var $versionAnchor = $("[data-version='" + version + "']");
    var versionSelector = "." + $versionAnchor.attr('data-selector');
    var testSelector = versionSelector + "." + suite;

    resetTests();

    // Set this element to be active
    $("button.versions").removeClass('active');
    $versionAnchor.addClass('active');

    // Record selected version and suite on div#tests
    $("#tests").attr('data-version', version);
    $("#tests").attr('data-suite', suite);

    // Disable all version elements
    $(".version").hide();
    
    // Enable appropriate suites
    $("button" + versionSelector).show();

    // Enable all tests with this selector
    $("div" + testSelector).show();
  }

  // Click triggers for versions
  $("button.versions").click(function() {
    var version = $(this).attr('data-version');
    var suite = $("#tests").attr('data-suite') || 'xhtml1';
    selectVersion(version, suite);
  });

  // Click triggers for suites
  $("button.suite").click(function() {
    var suite = $(this).attr('data-suite');
    var version = $("#tests").attr('data-version') || 'rdfa1_1';
    selectVersion(version, suite);
  });

  // Load test cases
  $("<div class='row'><h3>" + "Test Cases are Loading..." + "</h3></div>").appendTo('#tests');
  $.getJSON("manifest", function(data) {
    $("#tests").empty();
    $.each(data["@id"], function(index, value) {
      $("#tests").append(new CrazyIvan(value).newTest());
    });
  
    // Select active suite
    var activeVersion = $("button.versions.active").attr('data-version');
    var activeSuite = $("button.suite.active").attr('data-suite');
    selectVersion(activeVersion, activeSuite);
  });
  
  // Load processors
  $.each({
    "pyrdfa":         "http://www.w3.org/2012/pyRdfa/extract?uri=",
    "RDF.rb":         "http://rdf.greggkellogg.net/distiller?raw=true&in_fmt=rdfa&uri=",
    "other":          ""
  }, function(key, value) {
    var $li = $("<li>").append(
      $("<a href='#'>")
        .attr('data-processor', value)
        .text(key))
      .click(function() {
        resetTests();
        $("#processor-url").val($(this).children("a").attr("data-processor"));
      });
    
    // Set default processor
    if(key === "pyrdfa") {
      $li.click();
    }

    $li.appendTo($("ul.processors"));
  });

  // Hide test progress bar
  $("div.test-progress").hide();

  // Set message queuing for Run All tests
  // FIXME: use test models and create
  // queue of models based on those that
  // are active
  $("button.run-all").click(function() {
    var total = 0;

    $(this).button('loading');
    // Create a message queue and load it up with
    // all tests which are visible
    resetTests();
    var q = $.makeArray(
      $("div.row.version:visible")
        .find("button.test"));

    total = q.length;

    $('div.test-progress').show();
    $('div.test-progress .test-total').text(total.toString());

    console.debug("click: " + this.toString());

    // Bind to the complete event of each test button
    // to trigger the next element in the queue
    $("button.test").bind('complete', function() {
      console.debug("complete: " + this.toString());
      
      // Update progress
      var passed = $("button.btn-success").length;
      var failed = $("button.btn-danger").length;
      $(".test-progress .bar").width((((passed + failed)/total)*100).toString() + "%");
      $(".test-progress .test-passed").text(passed.toString());
      $(".test-progress .test-failed").text(failed.toString());

      var next = q.shift();
      if (next === undefined) {
        $("button.run-all").button('reset');
      } else {
        $(next).click();
      }
    });
    
    $(q.shift()).click();
  });
});
