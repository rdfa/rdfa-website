window.ProcessorView = Backbone.View.extend({

  initialize: function () {
    var that = this;
    this.setElement($("div#processor"));
    this.model.bind('change', this.render, this);
    
    // Load up set of processors
    $.each(this.model.processors, function(key, value) {
      elt = _.template("<li><a href='#' data-processor='<%= value %>'><%= key %></a></li>", {key: key, value: value});
      $("div#processor ul").append($(elt));
    });
    this.render();
  },

  events: {
    "click a":        "processor",
    "change input":  "url"
  },

  render: function (event) {
    this.$('#processor-url').val(this.model.get('processorURL'));
  },

  processor: function(event) {
    this.model.set({processorURL: $(event.target).attr('data-processor')});
    // Navigate to cause tests to be reloaded
    app.navigate(this.model.get('version') + '/' + this.model.get('hostLanguage'), {trigger: true});
  },
  
  url: function(event) {
    this.model.set({processorURL: $(event.target).val()});
    // Navigate to cause tests to be reloaded
    app.navigate(this.model.get('version') + '/' + this.model.get('hostLanguage'), {trigger: true});
  }
});
