var EarlItemView = Backbone.View.extend({
  template: _.template($('#earl-item-template').html()),

  attributes: {
    "typeof": "earl:TestCase" 
  },

  initialize: function() {
    // Updates to the model re-render the view
    this.model.bind('change', this.render, this);
  },

  render: function () {
    var JSON = this.model.toJSON();
    JSON.processorURL = this.options.processorURL;

    this.$el.html(this.template(JSON));
    this.$el.attr("resource", this.model.testURI());
    this.$(".resource.processorURL").attr("resource", JSON.processorURL);
    this.$(".resource.detailsURL").attr("resource", this.model.detailsURL());
    this.$(".resource.testURI").attr("resource", this.model.testURI());
    this.$(".resource.outcome").attr("resource", 'earl:' + this.model.get('result').toLowerCase() + 'ed');
    return this;
  }
});

window.EarlView = Backbone.View.extend({
  template: _.template($('#earl-report-template').html()),

  render:function (eventName) {
    var that = this;
    var JSON = this.model.version.toJSON();
    var total = this.model.models.length;
    var passed = _.filter(this.model.models, function(m) {return m.get('result') == 'PASS';}).length;
    JSON = _.extend({total: total, passed: passed}, JSON);

    this.$el.html(this.template(JSON));
    this.$(".href.processorURL").attr("href", JSON.processorDOAP);

    _.each(this.model.models, function (test) {
      if (test.get('result')) {
        var earlView = new EarlItemView({model: test, processorURL: JSON.processorDOAP});
        that.$("#items").append(earlView.render().el);
      }
    });
    return this;
  }
});
