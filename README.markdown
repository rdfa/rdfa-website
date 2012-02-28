= Introduction

This repository controls the [rdfa.info](http://rdfa.info/) webisite, including the
[RDFa Test Suite](http://rdfa.info/test-suite).

== RDFa Test Suite

The RDFa Test Suite is a set of Web Services, markup and tests that can 
be used to verify RDFa Processor conformance to the set of specifications
that constitute RDFa 1.1. The goal of the suite is to provide an easy and 
comprehensive RDFa testing solution for developers creating RDFa Processors.

== Design

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

The processor is indicated by a URL ending with a query
parameter used to specify the document to be tested. The processor may return
results as [RDF/XML][], [Turtle][], or [N-Triples][] and should
indicate the result format in Content-Type using the appropriate
Mime Type for the format used.

== Running the Test Suite

You can view and run this test suite at the following URL:

[http://rdfa.info/test-suite/](http://rdfa.info/test-suite/)

== Contributing

If you would like to contribute a new test or a fix to an existing test,
please follow these steps:

1. Notify the RDFa mailing list, public-rdf-wg@w3.org, 
   that you will be creating a new test or fix and the purpose of the
   change.
2. Clone the git repository: [git://github.com/rdfa/rdfa-website.git](https://github.com/rdfa/rdfa-website).
3. Make your changes and submit them via github, or via a 'git format-patch'
   to the RDFa mailing list.

Optionally, you can ask for direct access to the repository and may make
changes directly to the RDFa Test Suite source code. All updates to the test 
suite go live within seconds of committing changes to github via a WebHook call.

== How to Add a Unit Test

In order to add a unit test, you must follow these steps:
   
1. Pick a new unit test number. For example - 250. To be consistent, please use
   the next available unit test number.
2. Create a markup file in the tests/ directory with a .txt extension. 
   For example: tests/250.txt
3. Create a SPARQL query file in the tests/ directory with a .sparql extension.
   For example: tests/250.sparql
4. Add your test to manifest.ttl and indicate the host language(s) and version(s) for which
   it applies. For example, if you would like your example to only apply to HTML4,
   you would modify add :hostLanguage <html4-manifest>; to the test case entry.

There are three classifications for Unit Tests:

required - These are tests that are required for proper operation per the
           appropriate RDFa specification.
optional - These are tests for optional features supported by some RDFa 
           Processors.
buggy    - These are tests that are buggy or are not considered valid test
           cases by all RDFa processor maintainers.

The test suite is designed to empower RDFa processor maintainers to create
and add tests as they see fit. This may mean that the test suite may become
unstable from time to time, but this approach has been taken so that the 
long-term goal of having a comprehensive test suite for RDFa can be achieved
by the RDFa community.

== Crazy Ivan

The test suite is termed _Crazy Ivan_ because of an unusual manoever popularized in [The Hunt for Red October](http://www.imdb.com/title/tt0099810/quotes?qt=qt0458296)
and [Firefly](http://www.youtube.com/watch?v=Oi6BLxusAM8). It is a term used to detect problems that are hiding, which is what the test suite.

> Seaman Jones: Conn, sonar! Crazy Ivan! 
> Capt. Bart Mancuso: All stop! Quick quiet! [the ships engines are shut down completely] 
> Beaumont: What's goin' on? 
> Seaman Jones: Russian captains sometime turn suddenly to see if anyone's behind them. We call it "Crazy Ivan." The only thing you can do is go dead. Shut everything down and make like a hole in the water. 
> Beaumont: So what's the catch? 
> Seaman Jones: The catch is, a boat this big doesn't exactly stop on a dime... and if we're too close, we'll drift right into the back of him. 
