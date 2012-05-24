window.ProcessorView = Backbone.View.extend({

  initialize: function () {
    this.setElement($("div#processor"));
    this.model.bind('change', this.render, this);
    this.render();
  },

  events: {
    "click a":        "processor",
    "change input":  "url"
  },

  render: function (event) {
    var that = this;

    // Load up set of processors
    this.$('ul').empty();

    $.each(this.model.get("processors"), function(key, value) {
      var elt = _.template("<li><a href='#' data-name='<%= key %>'><%= key %></a></li>", {key: key});
      if (value.endpoint) {that.$('ul').append($(elt));}
    });

    this.$('#processor-url').val(this.model.get('processorURL'));
  },

  processor: function(event) {
    var name = $(event.target).attr('data-name');
    var processor = this.model.get('processors')[name];
    this.model.set({
      processorName: name,
      processorURL: processor.endpoint,
      processorDOAP: processor.doap
    });
    // Navigate to cause tests to be reloaded
    app.navigate(this.model.get('version') + '/' + this.model.get('hostLanguage'), {trigger: true});
  },
  
  url: function(event) {
    this.model.set({
      processorName: $(event.target).val(),
      processorURL: $(event.target).val(),
      processorDOAP: $(event.target).val()
    });
    // Navigate to cause tests to be reloaded
    app.navigate(this.model.get('version') + '/' + this.model.get('hostLanguage'), {trigger: true});
  }
});
