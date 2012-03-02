window.HostLanguageView = Backbone.View.extend({

  initialize: function () {
    this.setElement($("div#host-languages"));
    this.model.bind('change', this.render, this);
  },

  events: {
    "click button": "hostLanguage"
  },

  render: function(event) {
    // Synchronize button with hostLanguge state
    this.$("button").removeClass('active').hide();
    _.each(this.model.hostLanguages(), function (suite) {
      // Only show suites that are associated with this version.
      this.$("button." + suite.toLowerCase()).show();
    });
    this.$("button." + this.model.get("hostLanguage")).addClass('active');
  },

  hostLanguage: function (event) {
    this.model.set({hostLanguage: $(event.target).attr('data-suite')});
    app.navigate(this.model.get('version') + '/' + this.model.get('hostLanguage'), {trigger: true});
  }
});
