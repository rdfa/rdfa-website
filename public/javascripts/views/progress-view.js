window.ProgressView = Backbone.View.extend({

  initialize: function () {
    this.setElement($("div#test-progress"));
    this.model.bind('change', this.render, this);
    this.model.bind('reset', this.render, this);
    this.$el.hide();
  },

  render: function(event) {
    if (this.model.running) {
      this.$el.show();
      var passed = this.model.passed;
      var failed = this.model.failed;
      var total = _.reduce(this.model.models, function(memo, test) {
        return memo + (_.include(["PASS", "FAIL"], test.get('result')) ? 1 : 0);
      }, 0);
      console.debug("total: " + total + ", length: " + this.model.length);
      this.$('.bar').width(((total/this.model.length)*100).toString() + "%");
      if (failed > 0) {
        this.$('.progress').removeClass('progress-success').addClass('progress-danger');
      } else {
        this.$('.progress').removeClass('progress-danger').addClass('progress-success');
      }
      this.$(".test-passed").text(passed.toString());
      this.$(".test-failed").text(failed.toString());
    } else {
      this.$el.hide();
    }
  }
});
