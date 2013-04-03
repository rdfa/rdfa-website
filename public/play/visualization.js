/**
 * The RDFa play visualizer is used to visualize RDF graphs.
 *
 * @author Manu Sporny <msporny@digitalbazaar.com>
 */
(function($) {
  // create the play instance if it doesn't already exist
  window.play.viz = window.play.viz || {};
  var viz = window.play.viz;  
  
  // setup the visualization viewport
  var m = [20, 120, 20, 120],
      w = 1024 - m[1] - m[3],
      h = 450 - m[0] - m[2],
      i = 0,
      root;

  /**
   * Redraw the graph visualization on the screen.
   */  
  viz.redraw = function(nodes) {
    // delete any old SVG document
    $('#graph').empty();
  
    // create a new tree layout
    viz.tree = d3.layout.tree()
      .size([h, w])
      .separation(function (a, b) { 
        var descendants = function(node) {
          var count = 0;
          for(d in node.children) {
            count++;
            count += descendants(node.children[d]);
          }
          return count;
        };
        var aDesc = Math.max(descendants(a), a.parent == b.parent ? 1 : 2);
        var bDesc = Math.max(descendants(b), a.parent == b.parent ? 1 : 2);
        return (aDesc + bDesc) / 2;
      });
    
    // create the projection
    viz.diagonal = d3.svg.diagonal()
      .projection(function(d) { return [d.y, d.x]; });

    // create the view for the graph
    viz.view = d3.select("#graph").append("svg:svg")
        .attr("width", w + m[1] + m[3])
        .attr("height", h + m[0] + m[2])
      .append("svg:g")
        .attr("transform", "translate(" + m[3] + "," + m[0] + ")");

    // set the root value
    root = nodes;
    
    // if root is invalid, fix it
    if(root == undefined)
    {
      root = {'name': 'Web Page'};
    }
      
    // set the RDF data
    viz.tree.nodes(root);

    // set the root X and Y starting location? I don't really know what this does.
    root.x0 = h / 2;
    root.y0 = 0;

    // update the visualization
    viz.update(root);
  };

  viz.update = function(source) {
    var duration = d3.event && d3.event.altKey ? 5000 : 500;

    // Compute the new tree layout.
    var nodes = viz.tree.nodes(root).reverse();

    // Normalize for fixed-depth.
    nodes.forEach(function(d) { d.y = d.depth * 180; });

    // Update the nodes…
    var node = viz.view.selectAll("g.node")
        .data(nodes, function(d) { return d.id || (d.id = ++i); });

    // Enter any new nodes at the parent's previous position.
    var nodeEnter = node.enter().append("svg:g")
        .attr("class", "node")
        .attr("transform", function(d) { return "translate(" + source.y0 + "," + source.x0 + ")"; })
        .on("click", function(d) { viz.toggle(d); viz.update(d); });

    nodeEnter.append("svg:circle")
        .attr("r", 1e-6)
        .style("fill", function(d) { return d._children ? "lightsteelblue" : "#fff"; });

    nodeEnter.append("svg:text")
        .attr("x", function(d) { return d.children || d._children ? -10 : 10; })
        .attr("dy", ".35em")
        .attr("text-anchor", function(d) { return d.children || d._children ? "end" : "start"; })
        .text(function(d) { return d.name; })
        .style("fill-opacity", 1e-6);

    // Transition nodes to their new position.
    var nodeUpdate = node.transition()
        .duration(duration)
        .attr("transform", function(d) { return "translate(" + d.y + "," + d.x + ")"; });

    nodeUpdate.select("circle")
        .attr("r", 4.5)
        .style("fill", function(d) { return d._children ? "lightsteelblue" : "#fff"; });

    nodeUpdate.select("text")
        .style("fill-opacity", 1);

    // Transition exiting nodes to the parent's new position.
    var nodeExit = node.exit().transition()
        .duration(duration)
        .attr("transform", function(d) { return "translate(" + source.y + "," + source.x + ")"; })
        .remove();

    nodeExit.select("circle")
        .attr("r", 1e-6);

    nodeExit.select("text")
        .style("fill-opacity", 1e-6);

    // Update the links…
    var link = viz.view.selectAll("path.link")
        .data(viz.tree.links(nodes), function(d) { return d.target.id; });

    // Enter any new links at the parent's previous position.
    link.enter().insert("svg:path", "g")
        .attr("class", "link")
        .attr("d", function(d) {
          var o = {x: source.x0, y: source.y0};
          return viz.diagonal({source: o, target: o});
        })
      .transition()
        .duration(duration)
        .attr("d", viz.diagonal);

    // Transition links to their new position.
    link.transition()
        .duration(duration)
        .attr("d", viz.diagonal);

    // Transition exiting nodes to the parent's new position.
    link.exit().transition()
        .duration(duration)
        .attr("d", function(d) {
          var o = {x: source.x, y: source.y};
          return viz.diagonal({source: o, target: o});
        })
        .remove();

    // Stash the old positions for transition.
    nodes.forEach(function(d) {
      d.x0 = d.x;
      d.y0 = d.y;
    });
  };

  // Toggle children.
  viz.toggle = function(d) {
    if (d.children) {
      d._children = d.children;
      d.children = null;
    } else {
      d.children = d._children;
      d._children = null;
    }
  }

  viz.redraw();

})(jQuery);
