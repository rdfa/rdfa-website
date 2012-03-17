var TestItemView = Backbone.View.extend({
  template: _.template($('#test-template').html()),
  
  initialize: function() {
    // Updates to the model re-render the view
    this.model.bind('change', this.render, this);
  },
  
  // Test events
  events: {
    "click .test":    "run",
    "click .source":  "source",
    "click .details": "details"
  },
  
  render: function () {
    var templJSON = this.model.toJSON();
    if (!this.model.get('expectedResults')) {
      templJSON = _.extend({negativeTest: ": (Negative parser test)"}, templJSON);
    } else {
      templJSON = _.extend({negativeTest: ""}, templJSON);
    }
    this.$el.html(this.template(templJSON));
    
    // Set Bootstrap.js behaviors
    this.$('button').button();

    var result = this.model.get('result');
    this.$('button.test').text(result || 'Test');

    switch (result) {
      case 'PASS':
        this.$('button.test').removeClass('btn-primary').addClass('btn-success');
        break;
      case 'FAIL':
        this.$('button.test').removeClass('btn-primary').addClass('btn-danger');
        break;
      case 'error':
        this.$('button.test').removeClass('btn-primary').addClass('btn-danger');
        break;
    }
    return this;
  },
  
  run: function(event) {
    // Update to running
    $(event.target).button('loading');
    // Run the test with the current processor-url
    this.model.run();
  },
  
  source: function(event) {
    var that = this;
    var button = $(event.target);
    button.button('loading');

    // Retrieve source data and create a vew to display it
    this.model.source(function(data) {
      that.sourceView = new SourceView({model: data});
      that.$el.append(that.sourceView.render().el);
      button.button('complete');
    });
  },
  
  details: function(event) {
    // Get details with the current processor-url
    var that = this;
    var button = $(event.target);
    button.button('loading');

    // Retrieve details data and create a vew to display it
    this.model.details(function(data) {
      if (that.model.get('expectedResults')) {
        data = _.extend({expected: ""}, data);
      } else {
        data = _.extend({expected: ": (Negative parser test)"}, data);
      }
      that.detailsView = new DetailsView({model: data});
      that.$el.append(that.detailsView.render().el);
      button.button('complete');
    });
  }
});

window.TestListView = Backbone.View.extend({
  loadingTemplate: _.template($('#test-loading').html()),

  initialize: function () {
    this.setElement($("div#tests"));
    // Updates to the model re-render the view
    this.model.bind('reset', this.render, this);
  },

  render:function (eventName) {
    var that = this;

    this.$el.empty();
    if (this.model.length === 0) { this.$el.append(this.loadingTemplate({})); }

    _.each(this.model.models, function (test) {
      var testView = new TestItemView({model: test, id: "test-" + test.get('num')});
      that.$el.append(testView.render().el);
    });
    return this;
  }
});
