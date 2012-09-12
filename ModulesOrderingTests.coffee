Module.define { named: "Module Ordering Tests", requires: [-> typeof mocha != "undefined"], definedBy: ->
	this.mocha.setup 'tdd'
	
	assert = chai.assert
	
	startupCallbacks = undefined
	global = undefined
	module = undefined
	initializedModulesLog = undefined

	addStartupCallback = (callback) ->
		startupCallbacks.push(callback)

	executeStartupCallbacks = ->
		_.each startupCallbacks, (startupCallback) -> startupCallback()

	initializeModuleExecutionOrdering = ->
		global = {}
		startupCallbacks = []
		initializedModulesLog = []
		module = ModuleExecutionOrdering.initializeForMeteor(global, addStartupCallback)
			
	defineTestModule = ({named: moduleName, requires: requirements}) -> 
			module.define { named: moduleName, requires: requirements, definedBy: -> initializedModulesLog.push(moduleName) }

	assertAppearsBefore = ({element: firstElement, appearsBefore: secondElement, in: array}) ->
		firstElementIndex = array.indexOf(firstElement)
		secondElementIndex = array.indexOf(secondElement)
		assert.notEqual(firstElementIndex, -1)
		assert.notEqual(secondElementIndex , -1)
		assert(firstElementIndex < secondElementIndex, "The requirement <" + firstElement + "> didn't appear before the module <" + secondElement + ">.")
	
	verifyModulesWereInitializedAs = (modulesOrder) ->
		executeStartupCallbacks()
		assert.equal(JSON.stringify(initializedModulesLog), JSON.stringify(modulesOrder))
		
	verifyAllExecutionOrdersWork  = (modulesDefinitions) ->
		_.each permute(modulesDefinitions), (permutation) ->
			verifyExecutionOrdersWork permutation

	verifyExecutionOrdersWork = (modulesDefinitions) =>
		initializeModuleExecutionOrdering()
		_.each modulesDefinitions, (moduleDefinition) ->
			defineTestModule moduleDefinition
		executeStartupCallbacks()

		_.each modulesDefinitions, (moduleDefinition) ->
			_.each moduleDefinition.requirements, (requirement) ->
				assertAppearsBefore({element: requirement, appearsBefore: moduleDefinition.name, in: initializedModulesLog})
				
	setup initializeModuleExecutionOrdering

	suite "Module Execution Ordering", ->
		
		suite "Unloadable modules", ->

			test "Single module with unexistent required module", ->

				module.define { named: "My Module", requires: ["Non Existant Module"], definedBy: -> }

				assert.throws(executeStartupCallbacks, /The module <My Module> was never loaded due to missing dependencies\./)

			test "Multiple modules with unexistent required modules", ->

				module.define { named: "My Module", requires: ["Non Existant Module"], definedBy: -> }
				module.define { named: "My Other Module", requires: ["Other Non Existant Module"], definedBy: -> }

				chai.assert.throws(executeStartupCallbacks, /The modules \[<My Module>, <My Other Module>\] were never loaded due to missing dependencies\./)

			test "Single module with unsatisfiable requirement function", ->

				module.define { named: "My Module", requires: [(-> false)], definedBy: -> }

				assert.throws(executeStartupCallbacks, /The module <My Module> was never loaded due to missing dependencies\./)

			test "Module with unexistent required module and other with unsatisfiable requirement function", ->

				module.define { named: "My Module", requires: [(-> false)], definedBy: -> }
				module.define { named: "My Other Module", requires: ["Other Non Existant Module"], definedBy: -> }

				chai.assert.throws(executeStartupCallbacks, /The modules \[<My Module>, <My Other Module>\] were never loaded due to missing dependencies\./)

			test "Multiple modules with unsatisfiable requirement functions", ->

				module.define { named: "My Module", requires: [(-> false)], definedBy: -> }
				module.define { named: "My Other Module", requires: [(-> false)], definedBy: -> }

				chai.assert.throws(executeStartupCallbacks, /The modules \[<My Module>, <My Other Module>\] were never loaded due to missing dependencies\./)

			test "Cyclic modules' requirements", ->

				module.define { named: "A", requires: ["B"], definedBy: -> }
				module.define { named: "B", requires: ["C"], definedBy: -> }
				module.define { named: "C", requires: ["D", "F"], definedBy: -> }
				module.define { named: "D", requires: ["A"], definedBy: -> }
				module.define { named: "F", requires: ["E"], definedBy: -> }
				module.define { named: "E", requires: [(-> true)], definedBy: -> }

				chai.assert.throws(executeStartupCallbacks, /The modules \[<A>, <B>, <C>, <D>\] were never loaded due to missing dependencies\./)

		suite "Invalid methods' definitions", ->
		
			test "Define module with an already utilized name", ->
				module.define { named: "A", requires: ["B"], definedBy: -> }
				module.define { named: "B", requires: ["C"], definedBy: -> }
				assert.throws((-> module.define { named: "A", requires: ["H"], definedBy: -> }), /A module has already been defined with the name <A>\./)

			test "Define module without definition function", ->
				assert.throws((-> module.define { named: "A", requires: ["B"]}), /<A> module has no definition function\./)

			test "Define module without name", ->
				assert.throws((-> module.define {requires: ["B"]}), /Module has no name\./)

		suite "Lloadable modules", ->
			
			test "No modules defined", ->
				executeStartupCallbacks()
				### No exception is thrown ###

			test "Define single module with no requirements", ->

				myModuleWasInitialized = false
				module.define { named: "My Module", requires: ["Non Existant Module"], definedBy: -> myModuleWasInitialized = true }

				assert.throws(executeStartupCallbacks, /The module <My Module> was never loaded due to missing dependencies\./)

			test "Define two modules in the correct order", ->

				first = "First"
				second = "Second"

				defineTestModule({named: first, requires: []})
				defineTestModule({named: second, requires: [first]})

				verifyModulesWereInitializedAs [first, second]

			test "Define two modules in the inversed order", ->

				first = "First"
				second = "Second"

				defineTestModule({named: second, requires: [first]})
				defineTestModule({named: first, requires: []})

				verifyModulesWereInitializedAs [first, second]

			test "Check all execution orders give proper results for 1 <- 2 <- 3", ->

				first = "1"
				second = "2"
				third = "3"
				
				moduleDefinitions = 
				[({named: first, requires: []}),
				({named: second, requires: [first]}),
				({named: third, requires: [second]})]
				
				validOrderings = [[first, second, third]]

				verifyAllExecutionOrdersWork moduleDefinitions
			
			test "Check all execution orders give proper results for 1 <- 2 <- (and 1) 3", ->

				first = "1"
				second = "2"
				third = "3"
				
				moduleDefinitions = 
				[({named: first, requires: []}),
				({named: second, requires: [first]}),
				({named: third, requires: [second, first]})]
				
				validOrderings = [[first, second, third]]

				verifyAllExecutionOrdersWork moduleDefinitions
				
			test "Check all execution orders give proper results for a complex case", ->
				###
				5040 possible orderings
				78 are valid

				6
				 4 5  6
					 2 3
						1        7
				###
				
				first = "1"
				second = "2"
				third = "3"
				fourth = "4"
				fifth = "5"
				sixth = "6"
				seventh = "7"
				
				moduleDefinitions = 
				[({named: first, requires: [second, third]}),
				({named: second, requires: [fourth, fifth]}),
				({named: third, requires: [sixth]}),
				({named: fourth, requires: [sixth]}),
				({named: fifth, requires: []}),
				({named: sixth, requires: []}),
				({named: seventh, requires: []})]

				verifyAllExecutionOrdersWork moduleDefinitions
	}