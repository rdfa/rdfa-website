window.ProgressView = Backbone.View.extend({

  initialize: function () {
    this.setElement($("div#test-progress"));
    this.model.bind('change', this.render, this);
    this.$el.hide();
  },

  render: function(event) {
    this.$el.show();
    var passed = this.model.passed;
    var failed = this.model.failed;
    var total = _.reduce(this.model.models, function(memo, test) {
      return memo + (_.include(["PASS", "FAIL"], test.get('result')) ? 1 : 0);
    }, 0);
    console.debug("total: " + total + ", length: " + this.model.length);
    this.$('.bar').width(((total/this.model.length)*100).toString() + "%");
    this.$(".test-passed").text(passed.toString());
    this.$(".test-failed").text(failed.toString());
  }
});
