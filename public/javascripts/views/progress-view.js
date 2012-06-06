window.ProgressView = Backbone.View.extend({

  initialize: function () {
    this.setElement($("div#test-progress"));
    this.model.bind('change', this.render, this);
    this.model.bind('reset', this.render, this);
    this.$el.hide();
  },

  events: {
    "click #earl a.show": "earl",
    "click #earl a.source": "earlSource"
  },

  render: function(event) {
    if (this.model.running) {
      this.$el.show();
      var passed = this.model.passed;
      var failed = this.model.failed;
      var total = passed + failed;
      if (total == this.model.length) {
        this.$('button').show();
      } else {
        this.$('button').hide();
      }
      console.debug("total: " + total + ", length: " + this.model.length);
      this.$('.bar').width(((total/this.model.length)*100).toString() + "%");
      if (failed > 0) {
        this.$('.progress').removeClass('progress-success').addClass('progress-danger');
      } else {
        this.$('.progress').removeClass('progress-danger').addClass('progress-success');
      }
      this.$(".test-total").text(total.toString());
      this.$(".test-passed").text(passed.toString());
      this.$(".test-failed").text(failed.toString());
    } else {
      this.$el.hide();
    }
  },

  // Generate EARL report
  earl: function(event) {
    var earlView = new EarlView({model: this.model});
    // Write EARL report to a new document
    var w = window.open();
    w.document.write(earlView.render().$el.html());
    w.document.close();
  },

  // Generate EARL report
  earlSource: function(event) {
    var earlView = new EarlView({model: this.model});
    // Write EARL report to a new document
    var w = window.open();
    w.document.close();
    var $html = $('<html/>')
      .append($('<head/>').append($('<base href="http://rdfa.info/test-suite/"/>')))
      .append($('<body/>').append(earlView.render().$el.html()));
    var $pre = $("<pre/>").text(
      "<!DOCTYPE html>\n<html>\n" +
      $html.html() +
      "</html>"
    );
    //w.document.write($pre.html());
    $('body', w.document).append($pre);
  }
});
