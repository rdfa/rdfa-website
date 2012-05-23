window.VersionView = Backbone.View.extend({

  initialize: function () {
    this.setElement($("div#versions"));
    this.model.bind('change', this.render, this);
  },

  events: {
    "click .versions": "version"
  },

  render: function(event) {
    var that = this;
    var versions = _.keys(this.model.get("versionHostLanguageMap"));
    var versionNames = this.model.get("versionNames");

    this.$el.empty();

    // Load processor buttons
    _.sortBy(versions, function(key) {
      var sel = key.replace(/[\.\-]/, '_');
      that.$el.append(
        $("<button class='btn versions' href='#'/>")
          .addClass(sel)
          .attr('data-version', key)
          .attr('data-selector', sel)
          .text(versionNames[key])
      );
    });

    // Synchronize button with version state
    this.$("button." + this.model.get("version").replace(/[\.\-]/, '_')).addClass('active');
  },

  version: function (event) {
    this.model.set({version: $(event.target).attr('data-version')});
    app.navigate(this.model.get('version'), {trigger: true});
  }
});
