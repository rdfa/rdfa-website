var DetailsView = Backbone.View.extend({
  template: _.template($('#details-template').html()),

  attributes: {
    "class":        "row alert fade in",
    "data-dismiss": "alert"
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
