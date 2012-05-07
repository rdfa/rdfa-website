/**
 * The RDFa play is used to test out RDFa markup in HTML.
 *
 * @author Manu Sporny <msporny@digitalbazaar.com>
 */
(function($) {
  RDF_TYPE = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type';
  RDF_PLAIN_LITERAL = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#PlainLiteral';
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
    
    // Initialize CodeMirror output display
    var outputDisplay = document.getElementById('outputDisplay');
    var outputOptions = {
      mode: 'text/n-triples',
      readOnly: true
    };
    play.outputDisplay = CodeMirror.fromTextArea(outputDisplay, outputOptions);
    
    // bind to tab change events
    $('a[data-toggle=tab]').bind('click', play.tabSelected);
  };

  play.tabSelected = function(e) {
    // e.target is the new active tab according to docs
    // so save the reference in case it's needed later on
    play.activeTab = e.target;
    
    // update the display
    play.process();
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
       RDFa.attach(preview);
    }
    else
    {
       RDFa.attach(preview, true);       
    }
    
    // iterate through all triples and insert them into the output display
    var tLite = play.toTurtleLite(preview.data);    
    var d3Nodes = play.toD3TreeGraph(preview.data);
    play.outputDisplay.setValue(tLite);
    play.viz.redraw(d3Nodes);
  };

  /**
   * Attempts to retrieve the short name of an IRI based on the fragment
   * identifier or last item in the path.
   *
   * @param iri the IRI to process
   * @returns a short name or the original IRI if a short name couldn't be
   *          generated.
   */
  play.getIriShortName = function(iri) {
    var rval = iri;
    
    // find the last occurence of # or / - short name is everything after it
    if(iri.indexOf('#') >= 0) {
      rval = iri.split('#').pop();
    }
    else if(iri.indexOf('/') >= 0) {
      rval = iri.split('/').pop();
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
      var triples = data.getSubjectTriples(s);
      var predicates = data.getSubjectTriples(s).predicates;
      var node = {
        'name': '',
        'children': []
      };
      
      // calculate the short name of the node
      if(s.charAt(0) == '_') {
        node.name = 'Item ' + bnodeNames[s];
      }
      else {
        node.name = '#' + play.getIriShortName(s);
      }
      
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
          var child = {
             'name': ''
          };
          
          // if the object is a bnode, use the generated name
          if(o.type == RDF_OBJECT && o.value.charAt(0) == '_')
          {            
            if(bnodeNames.hasOwnProperty(o.value)) {
              value = 'Item ' + bnodeNames[o.value];
            }
          }
          else if(o.type == RDF_OBJECT && p == RDF_TYPE)
          {
            // if the property is an rdf:type, shorten the IRI
            value = play.getIriShortName(o.value);
          }
          else
          {
            value = o.value;
          }
          
          // generate the leaft node name
          child.name = play.getIriShortName(p) + ': ' + value;
          
          node.children.push(child);
        }        
      }
      
      rval.children.push(node);
    }
    
    // clean up any top-level children with no data
    for(c in rval.children)
    {
      var child = rval.children[c];
      if(child.children && child.children.length == 0)
      {
        rval.children.splice(c, 1);
      }
    }
    
    console.log("D3 Tree Graph:", rval);

    return rval;
  };
  
  /**
   * Converts the RDFa data in the page to a D3 tree graph for visualization.
   *
   * @param data the reference to the RDFa DataDocument API.
   */
  play.toTurtleLite = function(data) {
    var rval = '';
    var subjects = data.getSubjects();
    for(si in subjects) {
      var s = subjects[si];
      var triples = data.getSubjectTriples(s);
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
    console.log("TURTLE Lite:", rval);
    
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

})(jQuery);
