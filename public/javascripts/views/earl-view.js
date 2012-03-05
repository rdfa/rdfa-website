var EarlItemView = Backbone.View.extend({
  template: _.template($('#earl-item-template').html()),

  attributes: {
    "typeof": "earl:Assertion" 
  },

  initialize: function() {
    // Updates to the model re-render the view
    this.model.bind('change', this.render, this);
  },

  render: function () {
    var JSON = _.extend({
      processorURL: this.model.processorURL()
    }, this.model.toJSON());

    this.$el.html(this.template(JSON));
    this.$el.attr("about", this.model.detailsURL());
    this.$(".resource.processorURL").attr("resource", this.model.processorURL());
    this.$(".resource.docURL").attr("resource", this.model.docURL());
    this.$(".resource.outcome").attr("resource", 'earl:' + this.model.get('result').toLowerCase());
    return this;
  }
});

window.EarlView = Backbone.View.extend({
  template: _.template($('#earl-report-template').html()),

  render:function (eventName) {
    var that = this;
    var JSON = this.model.version.toJSON();

    this.$el.html(this.template(JSON));
    this.$(".resource.processorURL").attr("resource", JSON.processorURL);
    this.$(".href.processorURL").attr("href", JSON.processorURL);

    _.each(this.model.models, function (test) {
      if (test.get('result')) {
        var earlView = new EarlItemView({model: test});
        that.$(">div").append(earlView.render().el);
      }
    });
    return this;
  }
});
