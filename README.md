# Introduction

This repository controls the [rdfa.info](http://rdfa.info/) website, including the
[RDFa Test Suite](http://rdfa.info/test-suite).

# License

Unless otherwise noted, all content in this source repository is released
under a public domain dedication. This includes all HTML, CSS, and JavaScript,
including all source code and testing files associated with the RDFa Test Suite.
At this point in time, the only exception to the public domain dedication are
the icons used on the site, which are copyright by Glyphicons and are
released under the CC-BY-SA-3.0 license.

# RDFa Test Suite

The RDFa Test Suite is a set of Web Services, markup and tests that can 
be used to verify RDFa Processor conformance to the set of specifications
that constitute RDFa 1.1. The goal of the suite is to provide an easy and 
comprehensive RDFa testing solution for developers creating RDFa Processors.

## Design

The RDFa Test suite allows developers to mix and match RDFa processor endpoints
with different RDFa versions and Host Languages.

The RDFa Test Suite is an HTML application driving the entire
process.

The RDFa Test Suite drives the entire process. The first step is to
retrieve the list of tests associated with different RDFa versions
and host languages. Then the RDFa Test Suite requests the
RDFa Service endpoint to run the associated SPARQL query, which
uses an _ASK_ form to return true or false, and a _FROM_ clause
to identify a result document. The built-in SPARQL processor will
poke the URL, referencing the chosen processor endpoint with a
query parameter indicating the test document, and other parameters
used to control the processor.

The test-suite is implemented using [Ruby](http://www.ruby-lang.org/), [Sinatra](http://www.sinatrarb.com/)
along with the [Linked Data](http://rubygems.org/gems/linkeddata) and [SPARQL](http://rubygems.org/gems/sparql) gems.
The user interface is implemented in JavaScript using
[Bootstrap.js](http://twitter.github.com/bootstrap/) and [Backbone.js](http://documentcloud.github.com/backbone/).

Ruby/Sinatra is responsible for running the service, which provides the test files, launches the HTML application, and executes SPARQL queries on request from the HTML app. The SPARQL queries, in turn, are access the processor endpoint to create a graph against which the query is run, with the results returned to the HTML app as a JSON `true` or `false`.

The HTML application is implemented principlly in JavaScript using Backbone.js as a model-viewer-controller, which downloads the test suite manifest and creates a simple user interface using Bootstrap.js to run tests, or get test details.

Processing happens in the following order:

    RDFa Test Suite | RDFa Service | RDFa Processor
    load webpage    ->
                    <- test scaffold
    load manifest   ->
                    <- JSON-LD manifest
    run test        -> Load SPARQL query
                       with FROM referencing
                       processor and reference
                       to test document.
                                    -> Process referenced
                                       test document and
                                       return RDF with
                                       Content-Type indicating
                                    <- format.
                       SPARQL runs with
                       returned document
                       returning _true_
    display results <- or _false_.

## Running the test suite

You can view and run this test suite at the following URL:

[http://rdfa.info/test-suite/](http://rdfa.info/test-suite/)

### Running locally

The website may be run locally and access either local or remote services. The site
is implemented as a Ruby/Sinatra application compatible with [Rack][] interfaces, similar to
Ruby on Rails. On a production installation, this is usually done with Apache and [Passenger](http://www.modrails.com/). Locally, it can be run using rackup or shotgun.

Running the website locally should be as simple as the following:

    git clone git@github.com:rdfa/rdfa-website.git
    cd rdfa-website
    [sudo] gem install bundler
    bundle install
    rackup

This will create an instance, usually running on port 9292. If you access as [http://localhost:9292/test-suite/](http://localhost:9292/test-suite/), it will re-write test URIs to http://rdfa.info/test-suite/ so that processors can see any tests that are already uploaded. If you want to run with a local endpoint, run with something else such as [http://127.0.0.1:9292/test-suite/](http://127.0.0.1:9292/test-suite/), which will inhibit the URI rewriting.
Note that you might have to create config.ru manually, you can just copy the existing config.ru.sample.

### Command line runner

By implementing a command-line runner, the tests can be run using bin/run-suite. This allows a processor that does not implement an HTTP-based distiller to run through test cases using a shell command.

To use this, implement a shell command accepting input RDFa on standard input generating Turtle or N-Triples on standard output. It should also accept the `--host-language`, `--version`, `--vocab_expansion`, `--rdfagrap`h, and `--uri` options.

For example, to run with the Ruby RDFa processor, invoke the following:

    bin/run-suite bin/rdf-rdfa

Remote endpoints can also be called using either the URL of the processor, or the name of the processor from the `processors.json` file.

See bin/run-suite --help for more on the test runner.

## How to add a unit test

In order to add a unit test, you must follow these steps:
   
1. Pick a new unit test number. For example - 250. To be consistent, please use
   the next available unit test number.
2. Create a markup file in the tests/ directory with a .txt extension. 
   For example: tests/250.txt
3. Create a SPARQL query file in the tests/ directory with a .sparql extension.
   For example: tests/250.sparql
4. Add your test to manifest.ttl and indicate the host language(s) and version(s) for which
   it applies. For example, if you would like your example to only apply to HTML4,
   you would specify ```rdfatest:hostLanguage "html4";``` in the test case entry.

There are three classifications for Unit Tests:

* required - These are tests that are required for proper operation per the
           appropriate RDFa specification.
* optional - These are tests for optional features supported by some RDFa 
           Processors.
* buggy    - These are tests that are buggy or are not considered valid test
           cases by all RDFa processor maintainers.

The test suite is designed to empower RDFa processor maintainers to create
and add tests as they see fit. This may mean that the test suite may become
unstable from time to time, but this approach has been taken so that the 
long-term goal of having a comprehensive test suite for RDFa can be achieved
by the RDFa community.

When running locally, after adding a unit test, run `rake cache:clear` to remove cached files and ensure that necessary HTTP resources are regenerated. For the deployed website, this happens automatically each time a Git commit is pushed to the server.

## How to create a processor endpoint.

The Test Suite operates by making a call to a _processor endpoint_ with a query parameter that indicates
the URL of the test document to be processed. Within the test suite, a text box (upper right-hand corner)
allows a processor endpoint to be selected or added manually. It is presumed that the endpoint URL ends
with a query parameter to which a test URL can be appended. For example, the _pyrdfa_ endpoint is
defined as follows: `http://www.w3.org/2012/pyRdfa/extract?uri=`. When invoked, the URL of an actual
test will be appended, such as the following:
`http://www.w3.org/2012/pyRdfa/extract?uri=http://rdfa.info/test-suite/test-cases/xml/rdfa1.1/0001.xml`.

Everything required by a processor can be presumed from the content of the document provided, however
the test suite will also set a `Content-Type` HTTP header appropriate for the document provided, these include
* application/xhtml+xml,
* application/xml,
* image/svg+xml, and
* text/html

The processor is called with HTTP Accept header indicating appropriate result formats (currently,
`text/turtle` (indicating [Turtle](http://www.w3.org/TR/turtle/)),
`application/rdf+xml` (indicating [RDF/XML](http://www.w3.org/TR/rdf-syntax-grammar/)), and
`text/plain` (indicating [N-Triples](http://www.w3.org/TR/rdf-testcases/#ntriples))), and the processor may
respond with an appropriate RDF format. Processors _SHOULD_ set the HTTP `Content-Type` of the resulting
document to the associated document Mime Type.

In some cases, the test suite may add additional query parameters to the endpoint URL to test different
required or optional behaviors, these include `rdfagraph`, taking a value of `original`, `processor`, or
`original,processor` to control the processor output
(see [RDFa Core 1.1 Section 7.6.1](http://www.w3.org/TR/rdfa-core/#accessing-the-processor-graph)).
Also, `vocab_expansion` taking any value is used
to control optional RDFa vocabulary expansion
(see [RDFa Core 1.1 Section 10.2](http://www.w3.org/TR/rdfa-core/#s_expansion_control)).

To add a processor to the test suite, add to the object definition in
`processors.json` in alphabetical order. This is currently defined as follows:

    {
      "any23 (Java)": {
        "endpoint": "http://any23.org/turtle/",
        "doap": "http://any23.org/",
        "doap_url": "/earl-reports/any23-doap.ttl"
      },
      "clj-rdfa (Clojure)": {
        "endpoint": "http://clj-rdfa.herokuapp.com/extract.ttl?url=",
        "doap": "https://github.com/niklasl/clj-rdfa",
        "doap_url": "/earl-reports/clj-rdfa-doap.ttl"
      },
      "EasyRdf (PHP)": {
        "endpoint": "http://www.easyrdf.org/converter?input_format=rdfa&raw=1&uri=",
        "doap": "http://www.aelius.com/njh/easyrdf/",
        "doap_url": "/earl-reports/easyrdf-doap.ttl"
      },
      "Green Turtle (JavaScript)": {
        "doap": "https://code.google.com/p/green-turtle/",
        "doap_url": "/earl-reports/green-turtle-doap.ttl"
      },
      "java-rdfa (Java)": {
        "endpoint": "http://rdf-in-html.appspot.com/translate/?parser=XHTML&uri=",
        "doap": "https://github.com/shellac/java-rdfa",
        "doap_url": "/earl-reports/java-rdfa-doap.ttl"
      },
      "librdfa (C)": {
        "endpoint": "http://librdfa.digitalbazaar.com/rdfa2rdf.py?uri=",
        "doap": "https://github.com/rdfa/librdfa",
        "doap_url": "/earl-reports/librdfa-doap.ttl"
      },
      "pyRdfa (Python)": {
        "endpoint": "http://www.w3.org/2012/pyRdfa/extract?uri=",
        "doap": "http://www.w3.org/2012/pyRdfa"
      },
      "RDF::RDFa (Ruby)": {
        "endpoint": "http://rdf.greggkellogg.net/distiller?raw=true&in_fmt=rdfa&uri=",
        "doap": "http://rubygems.org/gems/rdf-rdfa",
        "doap_url": "/earl-reports/rdf-rdfa-doap.ttl"
      },
      "RDF::RDFa::Parser (Perl)": {
        "endpoint": "http://buzzword.org.uk/2012/rdfa-distiller/?format=rdfxml&url=",
        "doap": "http://purl.org/NET/cpan-uri/dist/RDF-RDFa-Parser/v_1-097",
        "doap_url": "/earl-reports/rdf-rdfa-parser-doap.ttl"
      },
      "Semargl (Java)": {
        "endpoint": "http://demo.semarglproject.org/process?uri=",
        "doap": "http://semarglproject.org"
      },
      "other":  {
        "endpoint": "",
        "doap": ""
      }
    }
    
The `doap` is the IRI defining the processor. It should be an information resource resulting in a
[DOAP](https://github.com/edumbill/doap/wiki) project description, and will be used when formatting reports.

If the DOAP project description location differs from the identifying IRI, set that location in `doap_url`

## Document caching

Test cases are provided with HTTP ETag headers and expiration values.
Processors _MAY_ cache test case documents but _MUST_ validate the document using HTTP HEAD or conditional GET
operations.

## Crazy Ivan

The test suite is termed _Crazy Ivan_ because of an unusual maneuver popularized in [The Hunt for Red October](http://www.imdb.com/title/tt0099810/quotes?qt=qt0458296)
and [Firefly](http://www.youtube.com/watch?v=Oi6BLxusAM8). It is a term used to detect problems that are hiding, which is what the test suite.

> Seaman Jones: Conn, sonar! Crazy Ivan! 
> Capt. Bart Mancuso: All stop! Quick quiet! [the ships engines are shut down completely] 
> Beaumont: What's goin' on? 
> Seaman Jones: Russian captains sometime turn suddenly to see if anyone's behind them. We call it "Crazy Ivan." The only thing you can do is go dead. Shut everything down and make like a hole in the water. 
> Beaumont: So what's the catch? 
> Seaman Jones: The catch is, a boat this big doesn't exactly stop on a dime... and if we're too close, we'll drift right into the back of him. 

# Contributing

If you would like to contribute a to the website, include an additional
test suite processor endpoint, contribute a new test or to a fix to an existing test,
please follow these steps:

1. Notify the RDFa mailing list, public-rdf-wg@w3.org, 
   that you will be creating a new test or fix and the purpose of the
   change.
2. Clone the git repository: [git://github.com/rdfa/rdfa-website.git](https://github.com/rdfa/rdfa-website).
3. Make your changes and submit them via github, or via a 'git format-patch'
   to the RDFa mailing list.

Optionally, you can ask for direct access to the repository and may make
changes directly to the RDFa Website source code. All updates to the test 
suite go live within seconds of pushing changes to github via a WebHook call.

## Caution: Cached assets

The JavaScript and CSS files are minimized into cached assets. Any change to CSS or JavaScript files
requires that the assets be re-compiled. This can be done as follows:

    rake assets:precompile

Make sure to do this before committing changes that involve any CSS or JavaScript contained within `file:public/stylesheets` or `public/javascripts`.
