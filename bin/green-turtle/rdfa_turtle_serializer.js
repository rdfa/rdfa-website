
  RDF_TYPE = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type';
  RDF_PLAIN_LITERAL = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#PlainLiteral';
  RDF_TYPED_LITERAL = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#TypedLiteral';
  RDF_OBJECT = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#object';

  play.toTurtle = function(data) {
    var rval = '';
    var prefixesUsed = {};
    // TODO: get properly and pass to iriToCurie (don't store in play!):
    play.knownPrefixes = data._data_.prefixes

    var subjects = data.getSubjects();
    for(si in subjects) {
      var s = subjects[si];
      var triples = data.getSubjectTriples(s);
      var predicates = triples.predicates;

      // print the subject
      if(s.charAt(0) == '_') {
        rval += s;
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

        for (oi in objects) {
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
  }

  play.iriToCurie = function(iri, prefixes) {
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
  }

