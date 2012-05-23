window.HostLanguageView = Backbone.View.extend({

  initialize: function () {
    this.setElement($("div#host-languages"));
    this.model.bind('change', this.render, this);
  },

  events: {
    "click button": "hostLanguage"
  },

  render: function(event) {
    var that = this;
    this.$el.empty();
    _.sortBy(this.model.hostLanguages(), function(hl) {
      var sel = hl.toLowerCase();
      that.$el.append(
        $("<button class='btn suite' href='#'/>")
          .addClass(sel)
          .attr('data-suite', sel)
          .text(hl)
      );
    });
    this.$("button." + this.model.get("hostLanguage")).addClass('active');
  },

  hostLanguage: function (event) {
    this.model.set({hostLanguage: $(event.target).attr('data-suite')});
    app.navigate(this.model.get('version') + '/' + this.model.get('hostLanguage'), {trigger: true});
  }
});
