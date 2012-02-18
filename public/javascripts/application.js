$(function () {
  // Hide elements
  //$('.modal').modal('hide');

  // Enable features

  // Load Manifest JSON-LD
  var CrazyIvan = function(testObject) {
    this.value = testObject;
    this.num = testObject["@id"].split('/').pop();
    this.hostLanguages = testObject['rdfatest:hostLanguage'];
    this.versions = testObject['rdfatest:rdfaVersion'];
    this.description = testObject['dc:title'];
    this.classification = testObject['test:classification'].split(':').pop();
    this.expectedResults = testObject['test:expectedResults'] || true;
    
    if (!(this.hostLanguages instanceof Array)) { this.hostLanguages = [this.hostLanguages]; }
    if (!(this.versions instanceof Array)) { this.versions = [this.versions]; }
  };
  
  CrazyIvan.prototype = {
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
    processorURL: function() {
      return $("#processor-url").val();
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
            .append($('<div>').addClass('span3')
              .append($detailButton)
              .append($sourceButton))));

      // Add clases for each suite and host-language
      $.each(this.versions, function(index, version) {
        $testDiv.addClass(version == 'rdfa1.0' ? 'rdfa1_0' : 'rdfa1_1');
      });
      $.each(this.hostLanguages, function(index, hostLanguage) {
        $testDiv.addClass(hostLanguage);
      });
      
      return $testDiv;
    },
    
    testButton: function() {
      var that = this;
      return $('<button>')
        .button()
        .addClass('btn btn-primary')
        .attr('data-loading-text', "Running")
        .attr('autocomplete', 'off')
        .text("Test")
        .click(function() {
          var button = this;
          $(this).button('loading');
          
          // Retrieve results from processor and canonical representation
          var test_url = "/test-suite/check-test/" +
            that.suite() +
            '/' + that.version() +
            '/' + that.num +
            '?expected-results=' + that.expectedResults +
            '&rdfa-extractor=' + that.processorURL();

          $.getJSON(test_url, function (data) {
            // Indicate pass/fail and style
            var btn_class = data.status == "PASS" ? "btn-success" : "btn-danger";
            $(button)
              .button('reset')
              .text(data.status)
              .removeClass("btn-primary")
              .addClass(btn_class);
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
        .attr('data-complete-text', "loaded")
        .attr('autocomplete', 'off')
        .text("details")
        .click(function() {
          var button = this;
          $(this).button('loading');
          
          // Retrieve results from processor and canonical representation
          var details_url = "/test-suite/test-details/" +
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
              .append($('<a>').addClass('close').text('x'))
              .bind('closed', function () {
                $(button).button("complete");
                $(this).remove();
              });

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
        .attr('data-complete-text', "loaded")
        .attr('autocomplete', 'off')
        .text("source")
        .click(function() {
          var button = this;
          $(this).button('loading');

          // Get test URIs associated with this test
          $.getJSON("/test-suite/test-cases/" + that.num, function(data) {
            $(button).button("complete");
            var $sourceDiv = $('<div>')
              .alert()
              .attr('id', 'unit-test-source-' + that.num)
              .attr('data-dismiss', 'alert')
              .addClass('row alert fade in')
              .append($('<a>').addClass('close').text('x'))
              .bind('closed', function () {
                $(button).button("complete");
                $(this).remove();
              });

            $sourceDiv.append(data.join('<br/>'));
            // FIXME: would like to display source in modal
            //$.each(data, function(index, url) {
            //  console.debug('URL: ' + url);
            //  $sourceDiv.append(
            //    $('a')
            //      .attr('href', '#source-modal')
            //      .attr('data-toggle', 'modal')
            //      .text(url)
            //    .append('<br/>'));
            //});

            $("div#unit-test-" + that.num + " > div").append($sourceDiv);
          });
        });
    }
  };

  function selectVersion(version, suite) {
    var $versionAnchor = $("[data-version='" + version + "']");
    var versionSelector = "." + $versionAnchor.attr('data-selector');
    var testSelector = versionSelector + "." + suite;

    // Set this element to be active
    $("#menu-rdfa1_0, #menu-rdfa1_1").parent().removeClass('active');
    $versionAnchor.parent().addClass('active');

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
  $("#menu-rdfa1_0, #menu-rdfa1_1").click(function() {
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
  $.getJSON("/test-suite/manifest", function(data) {
    $("#tests").empty();
    $.each(data["@id"], function(index, value) {
      $("#tests").append(new CrazyIvan(value).newTest());
    });
  
    // Select active suite
    var activeVersion = $("ul.nav>li.active>a").attr('data-version');
    var activeSuite = $("button.suite.active").attr('data-suite');
    selectVersion(activeVersion, activeSuite);
  });
  
  // Load processors
  $.each({
    "arcrdfa":        "http://arc.web-semantics.org/demos/rdfa_tests/extract.php?url=",
    "cognition":      "http://srv.buzzword.org.uk/crazy-ivan.cgi?uri=",
    "librdfa-python": "http://rdfa.digitalbazaar.com/librdfa/rdfa2rdf.py?uri=",
    "marklogic":      "http://dmz-demo39.demo.marklogic.com/rdfa_extract.xqy?url=",
    "pyrdfa":         "http://www.w3.org/2012/pyRdfa/extract?uri=",
    "RDF.rb":         "http://rdf.greggkellogg.net/distiller?raw=true&fmt=turtle&in_fmt=rdfa&uri=",
    "shark":          "http://shark.informatik.uni-freiburg.de/Ocean/SharkWeb.asmx/Parse?url=",
    "spread":         "http://htmlwg.mn.aptest.com/rdfa/extract_rdfa.pl?format=xml&uri=",
    "other":          ""
  }, function(key, value) {
    var $li = $("<li>").append(
      $("<a href='#'>")
        .attr('data-processor', value)
        .text(key))
      .click(function() {
        $("#processor-url").val($(this).children("a").attr("data-processor"));
      });
    
    // Set default processor
    if(key === "pyrdfa") {
      $li.click();
    }

    $li.appendTo($("ul.processors"));
  });
});
