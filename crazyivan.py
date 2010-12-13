##
# This is the web service form for the Crazy Ivan RDFa Test Harness script.
# License: Creative Commons Attribution Share-Alike
# @author Manu Sporny
import os, os.path
import re
import subprocess
from re import search
from urllib2 import urlopen
import urllib
from rdflib.Graph import Graph
import xml.sax.saxutils
from mod_python import apache

BASE_TEST_CASE_URL = "http://rdfa.digitalbazaar.com/test-suite/test-cases/"

##
# Retrieves all of the test cases from the given test suite manifest URL and
# filters the RDF using the given status filter.
#
# @param testSuiteManifestUrl A fully-qualified URL to the RDF file that
#                             contains the test manifest.
# @param classification The classification filter, usually something like 
#                     "required", "optional", or "buggy".
# @returns a tuple containing all of the filtered test cases including
#          unit test number, title, XHTML URL, SPARQL URL and status.
def retrieveTestCases(testSuiteManifestUrl, classificationFilter):
    # query the RDFa test manifest and generate test methods in the 
    # RDFaOnlineTest unittest
    
    q = """
    PREFIX test: <http://www.w3.org/2006/03/test-description#> 
    PREFIX dc:   <http://purl.org/dc/elements/1.1/>
    SELECT ?doc_uri ?sparql_uri ?title ?classification ?expected_results
    FROM <%s>
    WHERE 
    { 
    ?t dc:title ?title .
    ?t test:informationResourceInput ?doc_uri .
    ?t test:informationResourceResults ?sparql_uri .
    ?t test:classification ?classification .
    OPTIONAL
    { 
    ?t test:expectedResults ?expected_results .
    }
    }
    """ % (testSuiteManifestUrl)

    # Construct the graph from the given RDF and apply the SPARQL filter above
    g = Graph()
    unittests = []
    for doc_uri, sparql, title, classification_url, expected_results in g.query(q):
        classification = classification_url.split("#")[-1]

        print doc_uri

        if(classification == classificationFilter):
            matches = search(r'(\d+)\..?html', doc_uri)
            if(matches == None):
                matches = search(r'(\d+)\..?svg', doc_uri)
            num = matches.groups(1)

            if(expected_results == None):
                expected_results = 'true'

            unittests.append((int(num[0]),
                              str(title),
                              str(doc_uri),
                              str(sparql),
                              str(classification),
                              str(expected_results)))

    # Sorts the unit tests in unit test number order.
    def sorttests(a, b):
        if(a[0] < b[0]):
            return -1
        elif(a[0] == b[0]):
            return 0
        else:
            return 1

    unittests.sort(sorttests)
          
    return unittests

##
# Performs a given unit test given the RDF extractor URL, sparql engine URL,
# HTML file and SPARQL validation file.
#
# @param rdf_extractor_url The RDF extractor web service.
# @param sparql_engine_url The SPARQL engine URL.
# @param html_url the HTML file to use as input.
# @param sparql_url the SPARQL validation file to use on the RDF graph.
def performUnitTest(rdf_extractor_url, sparql_engine_url,
                    html_url, sparql_url, expected_result):
    # Build the RDF extractor URL
    rdf_extract_url = rdf_extractor_url + urllib.quote(html_url)

    # Build the SPARQL query
    sparql_query = urlopen(sparql_url).read()
    sparql_query = sparql_query.replace("ASK WHERE",
                                        "ASK FROM <%s> WHERE" % \
                                        (rdf_extract_url,))
    
    # Build the SPARQLer service URL
    sparql_engine_url += urllib.quote(sparql_query)
    sparql_engine_url += "&default-graph-uri=&stylesheet=%2Fxml-to-html.xsl"

    # Call the SPARQLer service
    sparql_engine_result = urlopen(sparql_engine_url).read()

    # TODO: Remove this hack, it's temporary until Michael Hausenblas puts
    #       an "expected SPARQL result" flag into the test manifest.
    query_result = "<boolean>%s</boolean>" % (expected_result,)
    sparql_value = (sparql_engine_result.find(query_result) != -1)

    return sparql_value

##
# Writes all the available test cases.
#
# Writes the test case alternatives for the given URL
def writeTestCaseRetrievalError(req, tc):
    req.write("""<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.0//EN"
 "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-1.dtd"> 
<html version="XHTML+RDFa 1.0" xmlns="http://www.w3.org/1999/xhtml"
   xmlns:xhv="http://www.w3.org/1999/xhtml/vocab#"
   xmlns:dcterms="http://purl.org/dc/terms/"
   xmlns:test="http://www.w3.org/2006/03/test-description#"> 
   
   <head> 
      <meta http-equiv="Content-Type" content="text/html;charset=utf-8" /> 
      <title>RDFa Test Suite: Test Cases</title> 
   </head>
   <body>
   <p>
      This feature is not implemented yet, but when it is, you will be able
      to view all tests cases available via this test suite.
   </p>
   </body>
</html>
""")

##
# Writes the test case alternatives for the given URL
#
# Writes the test case alternatives for the given URL
def writeTestCaseAlternatives(req, arguments):
    filename = arguments.split("/")[-1]
    req.write("""<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.0//EN"
 "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-1.dtd"> 
<html version="XHTML+RDFa 1.0" xmlns="http://www.w3.org/1999/xhtml"
   xmlns:xhv="http://www.w3.org/1999/xhtml/vocab#"
   xmlns:dcterms="http://purl.org/dc/terms/"
   xmlns:test="http://www.w3.org/2006/03/test-description#"> 
   
   <head> 
      <meta http-equiv="Content-Type" content="text/html;charset=utf-8" /> 
      <title>RDFa Test Suite: Select a Test Case Document</title> 
   </head>
   <body>
   <p>
      The following documents are associated with this test case:
      <ul>
         <li><a href="%sxhtml1/%s.xhtml">XHTML+RDFa 1.1</li>
         <li><a href="%shtml4/%s.html">HTML4</li>
         <li><a href="%shtml5/%s.html">HTML5</li>
         <li><a href="%sxhtml1/%s.sparql">SPARQL for XHTML+RDFa 1.1</li>
         <li><a href="%shtml4/%s.sparql">SPARQL for HTML4</li>
         <li><a href="%shtml5/%s.sparql">SPARQL for HTML5</li>
      </ul>
   </p>
   </body>
</html>""" % (BASE_TEST_CASE_URL, filename, BASE_TEST_CASE_URL, filename, 
              BASE_TEST_CASE_URL, filename, BASE_TEST_CASE_URL, filename, 
              BASE_TEST_CASE_URL, filename, BASE_TEST_CASE_URL, filename))

##
# Writes a test case document for the given URL.
def writeTestCaseDocument(req, path):
    validDocument = True

    version = path[-2]
    document = path[-1]
    namespaces = ""
    body = ""

    # Generate the filename that resides on disk
    filename = os.path.join(req.document_root(), "test-suite")
    if(document.endswith(".sparql")):
        filename += "/" + os.path.join("tests", document)
    else:
        filename += "/tests/%s.txt" % (document.split(".")[0])

    # Check to see if the file exists and extract the body of the document
    if(os.path.exists(filename)):
        bfile = open(filename, "r")
        lines = bfile.readlines()
        foundHead = False

        # Don't search for the head of the document if a SPARQL document
        # was requested
        if(document.endswith(".sparql")):
            foundHead = True

        # Extract the namespaces from the top of the document and build
        # the body of the document
        for line in lines:
            if("<head" in line or "http://www.w3.org/2000/svg" in line):
                foundHead = True

            if(not foundHead):
                namespaces += line
            else:
                body += line
    else:
        req.status = apache.HTTP_NOT_FOUND

    # Trim up the namespaces string
    namespaces = namespaces[:-1]

    # Create the regular expression to rewrite the contents of the XHTML and
    # SPARQL files
    tcpath = BASE_TEST_CASE_URL + version
    htmlre = re.compile("([0-9]{4,4})\.xhtml")
    svgre = re.compile("([0-9]{4,4})\.svg")
    tcpathre = re.compile("\$TCPATH")

    if(document.endswith(".xhtml") and version == "xhtml1"):
        req.content_type = "application/xhtml+xml"
        req.write("""<?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.1//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-2.dtd"> 
    <html xmlns="http://www.w3.org/1999/xhtml"
    %s>\n""" % (namespaces,))
        req.write(tcpathre.sub(tcpath, body))
        req.write("</html>")
    elif(document.endswith(".html") and version == "html4"):
        req.content_type = "text/html"
        req.write("""<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01+RDFa 1.1//EN" "http://www.w3.org/MarkUp/DTD/html401-rdfa11-1.dtd">
        """)
        req.write("""<html %s>\n""" % (namespaces,))

        # Rename all of the test case .xhtml files to .html
        req.write(tcpathre.sub(tcpath, htmlre.sub("\\1.html", body)))

        req.write("</html>")
    elif(document.endswith(".html") and version == "html5"):
        req.content_type = "text/html"
        if(len(namespaces) > 0):
            req.write("""<!DOCTYPE html>\n<html %s>\n""" % (namespaces,))
        else:
            req.write("""<!DOCTYPE html>\n<html>\n""")

        # Rename all of the test case .xhtml files to .html
        req.write(tcpathre.sub(tcpath, htmlre.sub("\\1.html", body)))
        req.write("</html>")
    elif(document.endswith(".svg") and version == "svgtiny"):
        req.content_type = "image/svg+xml"
        req.write("""<?xml version="1.0" encoding="UTF-8"?>\n<svg %s>\n""" % \
            (namespaces,))
        req.write(tcpathre.sub(tcpath, body))
        req.write("</svg>")
    elif(document.endswith(".sparql")):
        req.content_type = "application/sparql-query"

        if(version != "xhtml1"):
            # Rename all of the test case .xhtml files to .html
            req.write(tcpathre.sub(tcpath, htmlre.sub("\\1.html", body)))
        else:
            req.write(tcpathre.sub(tcpath, body))
    else:
        req.status = apache.HTTP_NOT_FOUND

##
# Writes the unit test HTML to the given request object.
#
# @param req the HTTP request object.
# @param test a tuple containing the unit test number, HTML file, SPARQL file,
#             and the status of the test.
def writeUnitTestHtml(req, test):
    num = test[0]
    title = test[1]
    html_url = test[2]
    sparql_url = test[3]
    status = test[4]
    expected_result = test[5]
    formatted_num = "%04i" % (num,)

    req.write("""
<p class=\"unittest\">
[<span id=\"unit-test-status-%i\">
    <a id=\"unit-test-anchor-%i\"
       href=\"javascript:checkUnitTest(%i,'%s','%s','%s')\">
       <span id=\"unit-test-result-%i\">TEST</span></a>
 </span>]
   Test #%i (%s): <span id=\"unit-test-description-%i\">%s</span>
   [<span id=\"unit-test-details-status-%i\">
    <a href=\"javascript:showUnitTestDetails(%i, '%s', '%s')\">show details</a>
     | 
    <a href=\"javascript:hideUnitTestDetails(%i)\">hide details</a>
     |
    <a href=\"http://rdfa.digitalbazaar.com/test-suite/test-cases/%s\">source</a>
    </span>
    ]<div style=\"margin-left: 50px\" id=\"unit-test-details-%i\">
    </div>
</p>

""" % (num, num, num, html_url, sparql_url, expected_result, num, num,
       status, num, title, num, num, html_url, sparql_url, num, formatted_num, 
       num))

##
# Checks a unit test and outputs a simple unit test result as HTML.
#
# @param req the HTML request object.
# @param num the unit test number.
# @param rdf_extractor_url The RDF extractor web service.
# @param sparql_engine_url The SPARQL engine URL.
# @param html_url the HTML file to use as input.
# @param sparql_url the SPARQL file to use when validating the RDF graph.
def checkUnitTestHtml(req, num, rdfa_extractor_url, sparql_engine_url,
                      html_url, sparql_url, expected_result):
    if(performUnitTest(rdfa_extractor_url, sparql_engine_url,
                       html_url, sparql_url, expected_result) == True):
        req.write("<span id=\"unit-test-anchor-%s\" style=\"text-decoration: underline; color: #090\" onclick=\"javascript:checkUnitTest(%s, '%s', '%s', '%s')\"><span id='unit-test-result-%s'>PASS</span></span>" % (num, num, html_url, sparql_url, expected_result, num))
    else:
        req.write("<span id=\"unit-test-anchor-%s\" style=\"text-decoration: underline; font-weight: bold; color: #f00\" onclick=\"javascript:checkUnitTest(%s, '%s', '%s', '%s')\"><span id='unit-test-result-%s>FAIL</span></span>" % (num, num, html_url, sparql_url, expected_result, num))

##
# Outputs the details related to a given unit test given the unit test number,
# RDF extractor URL, sparql engine URL, HTML file and SPARQL validation file.
# The output is written to the req object as HTML.
#
# @param req the HTTP request.
# @param num the unit test number.
# @param rdf_extractor_url The RDF extractor web service.
# @param sparql_engine_url The SPARQL engine URL.
# @param html_url the HTML file to use as input.
# @param sparql_url the SPARQL validation file to use on the RDF graph.
def retrieveUnitTestDetailsHtml(req, num, rdf_extractor_url, n3_extractor_url,
                                html_url, sparql_url):
    # Build the RDF extractor URL
    rdf_extract_url = rdf_extractor_url + urllib.quote(html_url)

    # Build the N3 extractor URL
    n3_extract_url = n3_extractor_url + urllib.quote(html_url)

    # Get the SPARQL query
    sparql_query = urlopen(sparql_url).read()

    # Get the XHTML data
    xhtml_text = urlopen(html_url).read()

    # get the triples in N3 format
    n3_text = urlopen(n3_extract_url).read()

    # Get the RDF text
    rdf_text = urlopen(rdf_extract_url).read()

    # Get the SPARQL text
    sparql_text = sparql_query

    req.write("""
    <h3>Test #%s Source Document</h3>
    <pre class="code">\n%s\n</pre>
    <em>Source: <a href="%s">%s</a></em>
    <h3>Test #%s N3 (Reference Implementation Triples)</h3>
    <pre class="code">\n%s\n</pre>
    <em>Extracted using: <a href="%s">%s</a></em>
    <h3>Test #%s RDF</h3>
    <pre class="code">\n%s\n</pre>
    <em>Extracted using: <a href="%s">%s</a></em>
    <h3>Test #%s SPARQL Test</h3>
    <pre class="code">\n%s\n</pre>
    <em>Source: <a href="%s">%s</a></em>
    """ % (num, 
           xml.sax.saxutils.escape(xhtml_text),
           urllib.unquote(html_url), urllib.unquote(html_url), 
           num,
           xml.sax.saxutils.escape(n3_text),
           urllib.unquote(n3_extract_url), urllib.unquote(n3_extract_url), 
           num,
           xml.sax.saxutils.escape(rdf_text), 
           urllib.unquote(rdf_extract_url), urllib.unquote(rdf_extract_url), 
           num, 
           xml.sax.saxutils.escape(sparql_text),
           urllib.unquote(sparql_url), urllib.unquote(sparql_url)))

##
# The handler function is what is called whenever an apache call is made.
#
# @param req the HTTP request.
#
# @return apache.OK if there wasn't an error, the appropriate error code if
#         there was a failure.
def handler(req):
    # File that runs an apache test.
    status = apache.OK
  
    puri = req.parsed_uri
    service = puri[-3]
    argstr = puri[-2]
    args = {}

    # Convert all of the arguments from their URL-encoded value to normal text
    if(argstr and len(argstr) > 0):
        if("&" in argstr):
            for kv in argstr.split("&"):
                key, value = kv.split("=", 1)
                args[urllib.unquote(key)] = urllib.unquote(value)
        elif("=" in argstr):
            key, value = argstr.split("=")
            args[urllib.unquote(key)] = urllib.unquote(value)

    # Retrieve all of the unit tests from the W3C website
    if(service.find("/test-suite/test-cases") != -1):
        req.content_type = 'text/html'
        document = service.replace("/test-suite/test-cases", "").split("/")
        if(len(document) <= 2):
            writeTestCaseRetrievalError(req, document[-1])
        elif(len(document) == 3):
            if(service.endswith(".xhtml") or service.endswith(".html") or
                service.endswith(".svg") or service.endswith(".sparql")):
                writeTestCaseDocument(req, document)
            else:
                writeTestCaseAlternatives(req, document[-1])
        else:
            req.write("ERROR DOCUMENT:" + str(document))
    elif(service.find("/test-suite/retrieve-tests") != -1):
        req.content_type = 'text/html'

        if(args.has_key('manifest') and args.has_key('status')):
            unittests = retrieveTestCases(args['manifest'], args['status'])
            for ut in unittests:
                writeUnitTestHtml(req, ut)
        else:
            req.write("<span style=\"text-decoration: underline; font-weight: bold; color: #f00\">ERROR: Could not retrieve test suite manifest, RDF url or status was not specified!</span>")

    # Check a particular unit test
    elif(service.find("/test-suite/check-test") != -1):
        req.content_type = 'text/html'
        if(args.has_key('id') and args.has_key('source') and
           args.has_key('sparql') and args.has_key('rdfa-extractor') and
           args.has_key('sparql-engine') and args.has_key('expected-result')):
            checkUnitTestHtml(req, args['id'], args['rdfa-extractor'],
                              args['sparql-engine'],
                              args['source'], args['sparql'],
                              args['expected-result'])
        else:
            req.write("ID, RDFA-EXTRACTOR, SPARQL-ENGINE, XHTML and " + \
                      "SPARQL not specified in request to test harness!")
            req.write("ARGS:" + str(args))

    # Retrieve the details about a particular unit test
    elif(service.find("/test-suite/test-details") != -1):
        req.content_type = 'text/html'
        if(args.has_key('id') and args.has_key('xhtml') and
           args.has_key('sparql') and args.has_key('rdfa-extractor') and
           args.has_key('n3-extractor')):
            retrieveUnitTestDetailsHtml(req, args['id'],
                                        args['rdfa-extractor'],
                                        args['n3-extractor'],
                                        args['xhtml'], args['sparql'])
        else:
            req.write("ID, XHTML, SPARQL, RDFA-EXTRACTOR or N3-EXTRACTOR " + \
                      "was not specified in the request URL to the" + \
                      "test harness!")

    # Perform a git update in the current directory
    elif(service.find("/test-suite/git-update") != -1):
        testSuitePath = os.path.dirname(req.canonical_filename)
        gitUpdatePath = os.path.join(testSuitePath, ".git")
        p = subprocess.Popen(["git", "--git-dir", gitUpdatePath, "pull"], 
            bufsize=4096, stdout=subprocess.PIPE, stderr=subprocess.PIPE, 
            close_fds=True, cwd=testSuitePath)
        (so, se) = p.communicate()
        req.write("GIT status: %s%s" % (so, se))
    else:
        req.content_type = 'text/html'
        req.write("<b>ERROR: Unknown CrazyIvan service: %s</b>" % (service,))

    return status

