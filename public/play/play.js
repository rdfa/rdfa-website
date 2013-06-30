/**
 * The RDFa play is used to test out RDFa markup in HTML.
 *
 * @author Manu Sporny <msporny@digitalbazaar.com>
 */
(function($) {
  RDF_TYPE = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type';
  RDF_PLAIN_LITERAL = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#PlainLiteral';
  RDF_TYPED_LITERAL = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#TypedLiteral';
  RDF_XML_LITERAL = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral';
  RDF_OBJECT = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#object';

  // create the play instance if it doesn't already exist
  window.play = window.play || {};
  var play = window.play;

  // The CodeMirror editor
  play.editor = null;

  // The CodeMirror triple display
  play.outputDisplay = null;

  // the counter is used to throttle previews and triple generation
  play.processDelay = 500;

  // the process timeout is used to keep track of the preview and triple 
  // processing timeout 
  play.processTimeout = null;

  // known prefixes used to shorten IRIs during the TURTLE transformation
  play.knownPrefixes = {
   // w3c
    'grddl': 'http://www.w3.org/2003/g/data-view#',
    'ma': 'http://www.w3.org/ns/ma-ont#',
    'owl': 'http://www.w3.org/2002/07/owl#',
    'rdf': 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
    'rdfa': 'http://www.w3.org/ns/rdfa#',
    'rdfs': 'http://www.w3.org/2000/01/rdf-schema#',
    'rif': 'http://www.w3.org/2007/rif#',
    'skos': 'http://www.w3.org/2004/02/skos/core#',
    'skosxl': 'http://www.w3.org/2008/05/skos-xl#',
    'wdr': 'http://www.w3.org/2007/05/powder#',
    'void': 'http://rdfs.org/ns/void#',
    'wdrs': 'http://www.w3.org/2007/05/powder-s#',
    'xhv': 'http://www.w3.org/1999/xhtml/vocab#',
    'xml': 'http://www.w3.org/XML/1998/namespace',
    'xsd': 'http://www.w3.org/2001/XMLSchema#',
    // non-rec w3c
    'sd': 'http://www.w3.org/ns/sparql-service-description#',
    'org': 'http://www.w3.org/ns/org#',
    'gldp': 'http://www.w3.org/ns/people#',
    'cnt': 'http://www.w3.org/2008/content#',
    'dcat': 'http://www.w3.org/ns/dcat#',
    'earl': 'http://www.w3.org/ns/earl#',
    'ht': 'http://www.w3.org/2006/http#',
    'ptr': 'http://www.w3.org/2009/pointers#',
    // widely used
    'cc': 'http://creativecommons.org/ns#',
    'ctag': 'http://commontag.org/ns#',
    'dc': 'http://purl.org/dc/terms/',
    'dcterms': 'http://purl.org/dc/terms/',
    'foaf': 'http://xmlns.com/foaf/0.1/',
    'gr': 'http://purl.org/goodrelations/v1#',
    'ical': 'http://www.w3.org/2002/12/cal/icaltzd#',
    'og': 'http://ogp.me/ns#',
    'rev': 'http://purl.org/stuff/rev#',
    'sioc': 'http://rdfs.org/sioc/ns#',
    'v': 'http://rdf.data-vocabulary.org/#',
    'vcard': 'http://www.w3.org/2006/vcard/ns#',
    'schema': 'http://schema.org/'
  }
  
  /**
   * Used to initialize the UI, call once on document load.
   */
  play.init = function() {
    // Initialize CodeMirror editor and the update callbacks
    var editor = document.getElementById('editor');
    var editorOptions = {
      mode: 'text/html',
      tabMode: 'indent',
      onChange: function() {
        clearTimeout(play.processDelay);
        play.processDelay = setTimeout(play.process, 300);
      }
    };
    
    play.editor = CodeMirror.fromTextArea(editor, editorOptions);
    setTimeout(play.process, 300);
    
    // Initialize CodeMirror output displays
    var turtleOutputDisplay = document.getElementById('turtleOutputDisplay');
    var turtleOutputOptions = {
      mode: 'text/turtle',
      readOnly: true
    };
    play.turtleOutputDisplay = 
      CodeMirror.fromTextArea(turtleOutputDisplay, turtleOutputOptions);

    /*
    var ntriplesOutputDisplay = 
      document.getElementById('ntriplesOutputDisplay');
    var ntriplesOutputOptions = {
      mode: 'text/n-triples',
      readOnly: true
    };
    play.ntriplesOutputDisplay = 
      CodeMirror.fromTextArea(ntriplesOutputDisplay, ntriplesOutputOptions);
    */
    
    // bind to tab change events
    $('a[data-toggle=tab]').bind('click', play.tabSelected);
    
    // bind the example buttons to the example callback
    $('button[class=btn]').bind('click', play.loadExample);
  };

  /**
   * Detects the example button that was clicked and loads the associated 
   * example into the code editor.
   *
   * @param e the event object that was fired.
   */
  play.loadExample = function(e) {
     var example = e.currentTarget.id.replace('btn-', '');
     
     if(example in play.examples) {
       play.editor.setValue(play.examples[example]);
     }
  };

  play.tabSelected = function(e) {
    // e.target is the new active tab according to docs
    // so save the reference in case it's needed later on
    play.activeTab = e.target;
    
    // FIXME: This is a hack - force an update of the TURTLE display because 
    // CodeMirror doesn't do it automatically on .show()
    play.editor.setValue(play.editor.getValue());
  };

  /**
   * Process the RDFa markup that has been input and display the output
   * in the active tab.
   */
  play.process = function() {
    var previewFrame = document.getElementById('preview');
    var preview =  previewFrame.contentDocument || previewFrame.contentWindow.document;
    
    preview.open();
    preview.write(play.editor.getValue());
    preview.close();
    
    if(!preview.data)
    {
       GreenTurtle.attach(preview);
    }
    else
    {
       GreenTurtle.attach(preview, true);
    }
    
    // iterate through all triples and insert them into the output display
    var turtle = play.toTurtle(preview.data);
    //var tLite = play.toTurtleLite(preview.data);
    var d3Nodes = play.toD3TreeGraph(preview.data);
    play.turtleOutputDisplay.setValue(turtle);
    //play.ntriplesOutputDisplay.setValue(tLite);
    play.viz.redraw(d3Nodes);
  };

  /**
   * Attempts to retrieve the short name of an IRI based on the fragment
   * identifier or last item in the path.
   *
   * @param iri the IRI to process
   * @param hashify if true, pre-pend a hash character if the shortening results
   *                in a fragment identifier.
   * @returns a short name or the original IRI if a short name couldn't be
   *          generated.
   */
  play.getIriShortName = function(iri, hashify) {
    var rval = iri;
    
    // find the last occurence of # or / - short name is everything after it
    if(iri.indexOf('#') >= 0) {
      if(hashify) {
        rval = '#' + iri.split('#').pop();
      }
      else {
        rval = iri.split('#').pop();
      }
    }
    else if(iri.indexOf('/') >= 0) {
      rval = iri.split('/').pop();
    }
    
    // don't allow the entire IRI to be optimized away
    if(rval.length < 1) {
      rval = iri;
    }
    
    return rval;
  };

  /**
   * Converts the RDFa data in the page to a D3 tree graph for visualization.
   *
   * @param data the reference to the RDFa DataDocument API.
   */
  play.toD3TreeGraph = function(data) {
    var bnodeNames = {};
    var bnodeCount = 1;
    var rval = {
      'name': 'Web Page',
      'children': []
    };

    var subjects = data.getSubjects();
    var embedded = {};

    var createNode = function(s, p, data, rval) {
      var triples = data.getSubject(s);
      var predicates = triples === null ? [] : triples.predicates;
      var name = '';
      var node = {
        'name': '',
        'children': []
      };
      
      // calculate the short name of the node
      // prepend the predicate name if there is one
      if(p !== undefined) {
        name = play.getIriShortName(p) + ': ';
      }

      if(s.charAt(0) == '_') {
        name += 'Item ' + bnodeNames[s];
      }
      else if(p == RDF_TYPE) {
        name += play.getIriShortName(s);
      }
      else {
        name += play.getIriShortName(s, true);
      }
      node.name = name;
      
      // create nodes for all predicates and objects
      for(p in predicates)
      {
        // do not include which vocabulary was used in the visualization
        if(p == "http://www.w3.org/ns/rdfa#usesVocabulary") {
          continue;
        }
      
        var objects = triples.predicates[p].objects;
        for(oi in objects) {
          var value = '';
          var o = objects[oi];

          if(o.type == RDF_OBJECT) {
            // recurse to create a node for the object if it's an object
            createNode(o.value, p, data, node);
            embedded[o.value] = true;
          }
          else {
            // generate the leaf node
            var name = '';
            if(o.type == RDF_XML_LITERAL) {
              // if the property is an XMLLiteral, serialise it
              name = play.nodelistToXMLLiteral(o.value);
            }
            else {
              name = o.value;
            }

            var child = {
               'name': play.getIriShortName(p) + ': ' + name
            };
            node.children.push(child);
          }
        }        
      }

      // remove the children property if there are no children
      if(node.children.length === 0) {
        node.children = undefined;
      }
      // collapse children of nodes that have already been embedded
      if(embedded[s] !== undefined && node.children !== undefined) {
        node._children = node.children;
        node.children = undefined;
      }
      
      rval.children.push(node);
    };
    
    // Pre-generate names for all bnodes in the graph
    for(si in subjects) {
      var s = subjects[si];
      
      // calculate the short name of the node
      if(s.charAt(0) == '_' && !(s in bnodeNames)) {
        bnodeNames[s] = bnodeCount;
        bnodeCount += 1;
      }
    }
    
    // Generate the D3 tree graph
    for(si in subjects) {
      var s = subjects[si];
      createNode(s, undefined, data, rval);
    }
    
    // clean up any top-level children with no data
    var cleaned = [];
    for(c in rval.children)
    {
      var child = rval.children[c];
      if(child.children !== undefined)
      {
        cleaned.push(child);
      }
    }
    rval.children = cleaned;

    return rval;
  };
  
  /**
   * Attempts to compress an IRI and updates a map of used prefixes if the
   * compression was successful.
   *
   * @param iri the IRI to compress into a Compact URI Expression.
   * @param prefixes the map of prefixes that have already been compressed.
   */
  play.iriToCurie = function(iri, prefixes)
  {
     var rval = iri;
     var detectedPrefix = false;
     
     for(prefix in play.knownPrefixes) {
        var expanded = play.knownPrefixes[prefix];
        
        // if the IRI starts with a known CURIE prefix, compact it
        if(iri.indexOf(expanded) == 0) {
           rval = prefix + ':' + iri.replace(expanded, '');
           prefixes[prefix] = expanded;
           break;
        }
     }
     
     if(rval.length == iri.length) {
        rval = '<' + iri + '>';
     }
     
     return rval;
  };

  /**
   * Converts a NodeList into an rdf:XMLLiteral string.
   *
   * @param nodelist the nodelist.
   */
  play.nodelistToXMLLiteral = function(nodelist) {
    var str = '';
    for(var i = 0; i < nodelist.length; i++) {
      var n = nodelist[i];
      str += n.outerHTML || n.nodeValue;
    }
    return str;
  };

  /**
   * Converts the RDFa data in the page to a N-Triples representation.
   *
   * @param data the reference to the RDFa DataDocument API.
   */
  play.toTurtleLite = function(data) {
    var rval = '';
    var subjects = data.getSubjects();
    for(si in subjects) {
      var s = subjects[si];
      var triples = data.getSubject(s);
      var predicates = triples.predicates;
      
      for(p in predicates)
      {
        var objects = triples.predicates[p].objects;
                
        for(oi in objects) {
          var o = objects[oi];

          // print the subject
          if(s.charAt(0) == '_') {
            rval += s + ' ';
          }
          else {
            rval += '<' + s + '> ';
          }

          // print the predicate
          rval += '<' + p + '> ';

          //console.log(o);
          // print the object
          if(o.type == RDF_PLAIN_LITERAL) {
             rval += '"' + o.value.replace('"', '\\"') + '"';
             if(o.language != null) {
                rval += '@' + o.language;
             }
          }
          else if(o.type == RDF_OBJECT) {
            if(o.value.charAt(0) == '_') {
              rval += o.value;
            }
            else {
              rval += '<' + o.value + '>';
            }
          }
          else
          {
             rval += o.value;
          }
          
          rval += ' .\n';
        }
      }      
    }
    
    return rval;
  };  

  /**
   * Converts the RDFa data in the page to a TURTLE representation of the data.
   *
   * @param data the reference to the RDFa DataDocument API.
   */
  play.toTurtle = function(data) {
    var rval = '';
    var prefixesUsed = {};

    var subjects = data.getSubjects();
    for(si in subjects) {
      var s = subjects[si];
      var triples = data.getSubject(s);
      var predicates = triples.predicates;

      // print the subject
      if(s.charAt(0) == '_') {
        rval += s + ' ';
      }
      else {
        rval += '<' + s + '>';
      }
      rval += '\n';

      pList = [];
      for(p in predicates) { pList.push(p) }
      var lastP = pList.length - 1;

      for(pi in pList)
      {
        var p = pList[pi];
        var objects = triples.predicates[p].objects;
        var lastO = objects.length - 1;

        for(oi in objects) {
          var o = objects[oi];

          // print the predicate, as a CURIE if possible
          rval += '   ' + play.iriToCurie(p, prefixesUsed) + ' ';

          //console.log(o);
          // print the object
          if(o.type == RDF_PLAIN_LITERAL) {
             var lit = o.value.replace('"', '\\"');
             var sep = '"';
             if (lit.indexOf('\n') > -1) {
               sep = '"""';
             }
             rval += sep + lit + sep;
             if(o.language != null) {
                rval += '@' + o.language;
             }
          }
          else if(o.type == RDF_OBJECT) {
            if(o.value.charAt(0) == '_') {
              rval += o.value;
            }
            else {
              rval += play.iriToCurie(o.value, prefixesUsed);
            }
          }
          else if(o.type == RDF_XML_LITERAL) {
            rval += '"';
            rval += play.nodelistToXMLLiteral(o.value).replace('"', '\\"');
            rval += '"^^rdf:XMLLiteral';
          }
          else if(o.type != null) {
            rval += '"' + o.value.replace('"', '\\"') + '"' + '^^' +
              play.iriToCurie(o.type, prefixesUsed);
          }
          else
          {
             console.log("UNCAUGHT TYPE", o);
             rval += o.value;
          }
          
          // place the proper TURTLE statement terminator on the data
          if (pi == lastP && oi == lastO) {
            rval += ' .\n';
          } else {
            rval += ';\n';
          }
        }
      }      
    }

    // prepend the prefixes used to the TURTLE representation.
    var prefixHeader = '';
    for(prefix in prefixesUsed)
    {
       prefixHeader += 
          '@prefix ' + prefix +': <' + prefixesUsed[prefix] + '> .\n';
    }
    rval = prefixHeader + '\n' + rval;
    
    return rval;
  };  

  /**
   * Populate the UI with a named example.
   *
   * @param name the name of the example to pre-populate the input boxes.
   */
  play.populateWithExample = function(name) {

    if(name in play.examples) {
      // TODO: implement examples
    }
  };

  // initialize RDFa Play
  play.init();
})(jQuery);
