var SourceView = Backbone.View.extend({
  attributes: {
    "class":        "row alert fade in"
  },

  // Open linkes in a new window/tab
  events: {
    "click a.window": "open_window"
  },
  
  open_window: function(event) {
    window.open($(event.target).attr('href'));
    return false;
  },

  render: function () {
    var that = this;
    this.$el.append('<a data-dismiss="alert" class="close">x</a>').alert();
    
    _.each(this.model, function(tc) {
      that.$el.append(
        $('<a class="window"/>')
          .attr('href', tc.doc_uri)
          .text(tc.suite_version))
        .append($('<br/>'));
    });
    return this;
  }
});
