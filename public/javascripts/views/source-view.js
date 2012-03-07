var SourceView = Backbone.View.extend({
  attributes: {
    "class":        "row alert fade in",
    "data-dismiss": "alert"
  },

  render: function () {
    var that = this;
    this.$el.append('<a class="close">x</a>').alert();
    
    _.each(this.model, function(tc) {
      that.$el.append(
        $('<a target="_blank"/>')
          .attr('href', tc.doc_uri)
          .text(tc.suite_version))
        .append($('<br/>'));
    });
    return this;
  }
});
