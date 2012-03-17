window.UnauthorizedView = Backbone.View.extend({
  unauthorizedTemplate: _.template($('#unauthorized').html()),

  initialize: function () {
    this.setElement($("div#tests"));
    this.render();
  },

  render:function (eventName) {
    return this.$el.append(this.unauthorizedTemplate({}));
  }
});
