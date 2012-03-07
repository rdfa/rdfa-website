var DetailsView = Backbone.View.extend({
  template: _.template($('#details-template').html()),

  attributes: {
    "class":        "row alert fade in",
    "data-dismiss": "alert"
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
    this.$el.html(this.template(this.model));
    this.$(".doc_url a").attr('href', this.model.doc_url);
    this.$(".extract_url a").attr('href', this.model.extract_url);
    this.$(".sparql_url a").attr('href', this.model.sparql_url);
    return this;
  }
});
