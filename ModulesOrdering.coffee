class ModuleExecutionOrdering
	constructor: (@functionCaller) ->
		@modulesNotYetLoaded = {}
		@modulesAlreadyLoaded = {}

	hasNameBeenUsed: (name) ->
		name of @modulesNotYetLoaded || name of @modulesAlreadyLoaded
		
	define: ({named: name, requires: requirements, definedBy: definitionFunction}) ->
		if typeof name == "undefined"
			throw {message: "Module has no name."}
			
		if @hasNameBeenUsed name
			throw {message: "A module has already been defined with the name <" + name + ">."}
			
		if typeof definitionFunction == "undefined"
			throw {message: "<" + name + "> module has no definition function."}
			
		moduleDescription = {name: name, requirements: requirements, definitionFunction: definitionFunction}

		if @areRequirementsSatisfied requirements
			@load moduleDescription
			@loadAllPossibleModules()
		else
			@modulesNotYetLoaded[name] = moduleDescription

	modulesNotYetLoadedNames: -> 
		names = _.map @modulesNotYetLoaded, (moduleNotYetLoaded) -> "<" + moduleNotYetLoaded.name + ">"
		names.sort()

	haveAllModulesBeenLoaded: -> 
		@modulesNotYetLoadedCount() == 0

	modulesNotYetLoadedCount: -> 
		Object.keys(@modulesNotYetLoaded).length

	isRequirementSatisfied: (requirement) -> 
		switch typeof requirement
			when "string" then requirement of @modulesAlreadyLoaded
			when "function" then @functionCaller(requirement)
			else throw {message: "A requirement of type " + typeof requirement + " isn't supported."}
			
	areRequirementsSatisfied: (requirements) -> _.all requirements, (requirement) => @isRequirementSatisfied requirement
			
	load: (moduleDescription) -> 
		@functionCaller(moduleDescription.definitionFunction)
		@modulesAlreadyLoaded[moduleDescription.name] = moduleDescription
		
	loadAllPossibleModules: ->
			anotherModuleWasLoaded = true
			while (anotherModuleWasLoaded)
				anotherModuleWasLoaded = false
				_.each @modulesNotYetLoaded, (moduleDescription, moduleName) =>
					if @areRequirementsSatisfied moduleDescription.requirements
						@load moduleDescription
						delete @modulesNotYetLoaded[moduleName]
						anotherModuleWasLoaded = true
				null

	verifyAllModulesWereLoaded: -> 
		if !@haveAllModulesBeenLoaded()
			message = if @modulesNotYetLoadedCount() == 1
				("The module " + @modulesNotYetLoadedNames()[0] + " was never loaded due to missing dependencies.")
			else
				("The modules [" + @modulesNotYetLoadedNames().join(", ") + "] were never loaded due to missing dependencies.")
			throw {message: message}

ModuleExecutionOrdering.initializeForMeteor = (global, addStartupCallback) ->
	moduleExecutionOrdering = new ModuleExecutionOrdering((functionToCall) -> functionToCall.call(global))

	addStartupCallback -> 
		moduleExecutionOrdering.loadAllPossibleModules()
		moduleExecutionOrdering.verifyAllModulesWereLoaded()

	{define: (parameters) -> moduleExecutionOrdering.define(parameters)}

this.Module = ModuleExecutionOrdering.initializeForMeteor(this, Meteor.startup)