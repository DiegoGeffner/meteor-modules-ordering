Package.describe({
  summary: "Utility to manage the initialization order of modules in meteor's client side"
});

Package.on_use(function (api) {
  api.use('coffeescript', 'client');
  api.add_files('ModulesOrdering.coffee', 'client');
});

Package.on_test(function (api) {
  /* 
  This still needs testing
  api.use('coffeescript', 'client', 'server');
  api.add_files(['ModulesOrdering.coffee', 'ModulesOrderingTests.coffee'],
                ['client', 'server']);
	*/
});
