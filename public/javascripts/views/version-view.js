window.VersionView = Backbone.View.extend({

  initialize: function () {
    this.setElement($("div#versions"));
    this.model.bind('change', this.render, this);
  },

  events: {
    "click .versions": "version"
  },

  render: function(event) {
    // Synchronize button with version state
    this.$("button").removeClass('active');
    this.$("button." + this.model.get("version").replace(/[\.-]/, '_')).addClass('active');
  },

  version: function (event) {
    this.model.set({version: $(event.target).attr('data-version')});
    app.navigate(this.model.get('version'), {trigger: true});
  }
});
