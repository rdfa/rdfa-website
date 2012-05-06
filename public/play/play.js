/**
 * The RDFa play is used to test out RDFa markup in HTML.
 *
 * @author Manu Sporny <msporny@digitalbazaar.com>
 */
(function($) {
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
    RDFa.attach(preview);
    
    // iterate through all triples and insert them into the output display
    var ntriples = '';
    var subjects = preview.data.getSubjects();
    for(si in subjects) {
      var s = subjects[si];
      var triples = preview.data.getSubjectTriples(s);
      var predicates = triples.predicates;
      
      // print the subject
      if(s.charAt(0) == '_') {
        ntriples += s + ' ';
      }
      else {
        ntriples += '<' + s + '> ';
      }
      
      for(p in predicates)
      {
        var objects = triples.predicates[p].objects;
        
        // print the predicate
        ntriples += '<' + p + '> ';
        
        for(oi in objects) {
          var o = objects[oi];
          // print the object
          if(o.type == 'http://www.w3.org/1999/02/22-rdf-syntax-ns#PlainLiteral') {
             ntriples += '"' + o.value.replace('"', '\\"') + '"';
             if(o.language != null) {
                ntriples += '@' + o.language;
             }
          }
          else if(o.type == '') {
          }
        }
      }
      
      ntriples += '.\n';
    }
    console.log(ntriples);
    
    play.outputDisplay.setValue(ntriples);
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
