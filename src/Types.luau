--!strict

local Signal = require(script.Parent.Utils.Signal)

export type Node = {
	--[[
        The name of the node in the Leaf registry
    ]]
	Name: string,
}

export type LifeCycleHooks = {
	--[[
        Called every frame

        @param self LifeCycleHooks
        @param delta Time since last frame
    ]]
	onTick: (self: LifeCycleHooks, delta: number) -> ()?,

	--[[
        Called every render frame (Client-only)

        @param self LifeCycleHooks
        @param delta Time since last render frame
    ]]
	onRender: (self: LifeCycleHooks, delta: number) -> ()?,

	--[[
        Called every physics frame

        @param self LifeCycleHooks
        @param delta Time since last physics frame
    ]]
	onPhysics: (self: LifeCycleHooks, delta: number) -> ()?,
}

--[[
    All valid cleaner tasks
]]
export type CleanerTask = Instance | (() -> ()) | nil | Cleaner | thread | RBXScriptConnection | {
	Disconnect: (self: CleanerTask) -> (),
} | {
	Destroy: (self: CleanerTask) -> (),
} | {
	Cancel: (self: CleanerTask) -> (),
} | {
	disconnect: (self: CleanerTask) -> (),
} | {
	destroy: (self: CleanerTask) -> (),
} | {
	cancel: (self: CleanerTask) -> (),
}

--[[
    All allowed attributes for the instance 
]]
export type ValidAttribute =
	boolean
	| number
	| string
	| BrickColor
	| Color3
	| ColorSequence
	| DateTime
	| NumberRange
	| NumberSequence
	| PhysicalProperties
	| Ray
	| Rect
	| CFrame
	| UDim
	| UDim2
	| Vector2
	| Vector2int16
	| Vector3
	| Vector3int16
	| EnumItem
	| Instance

export type Cleaner = {
	--[[
        Adds a task to the cleaner

        @param self Cleaner
        @param task Task to add 
        @return Task 
    ]]
	add: (self: Cleaner, task: CleanerTask) -> CleanerTask,
	--[[
        Creates a sub cleaner that extends the current cleaner 
        and will be destroyed with it

        @param self Cleaner
        @return Cleaner
    ]]
	extend: (self: Cleaner) -> Cleaner,
	--[[
        Destroys the cleaner and all of its tasks
        @param self Cleaner
        @return void
    ]]
	cleanup: (self: Cleaner) -> (),
}

export type Connection<U...> = Signal.Connection<U...>

export type Signal<T...> = Signal.Signal<T...>

export type Component<IT, ST = nil, Args... = ()> = LifeCycleHooks & Node & {
	Instance: IT, -- Instance
	Tag: string?, -- Tag
	Super: ST?, -- Superclass

	--[[
        Checks if the instance is of the component (Classical InstanceOf like)
        @param self Component instance
        @param instance Instance to check
        @return boolean True if the instance is of the component
    ]]
	isA: (self: Component<IT, ST>, component: string | any) -> boolean,

	-- Lifecycle

	--[[
        Called when the component is spawned
        @param self Component instance
        @param Args... The arguments passed to the component
        @return void
    ]]
	onSpawn: (self: Component<IT, ST>, Args...) -> (),

	--[[
        Called when the component is despawned
        @param self Component instance
        @return void
    ]]
	onDespawn: (self: Component<IT, ST>) -> (),
}

--[[
    BaseComponent class for all components

    @param IT Instance
    @param ST? Superclass
]]
export type BaseComponent<IT, ST = nil, Args... = ()> = Component<IT, ST, Args...> & {
	--[[
        Attributes for the instance with automatic two-way binding
    ]]
	Attributes: { [string]: ValidAttribute }?,

	--[[
        Cleaner for the instance
    ]]
	Cleaner: Cleaner,

	WhitelistedAncestors: { Instance }?,
	BlacklistedAncestors: { Instance }?,

	--[[
        Predicate for the instance
        @param instance Instance to check
        @return boolean True if the instance is valid
    ]]
	Predicate: (instance: Instance) -> boolean?,

	--[[
        Adds a task to the cleaner
        @param self BaseComponent
        @param task Task to add
        @return Task
    ]]
	onDestroy: (self: BaseComponent<IT, ST>, task: CleanerTask) -> CleanerTask,

	--[[
        Add components to the instance which will be destroyed
        when the component is destroyed
        @param self BaseComponent
        @param bundle { string | Component } An array of components, either names or modules
        @return void
	]]
	componentsBundle: (self: BaseComponent<IT, ST>, bundle: { string | any }) -> (),

	--[[
        Connects a callback to a specific attribute change
        @param self BaseComponent
        @param attribute string Attribute name
        @param callback Callback function hook
        @return RBXScriptConnection Connection
    ]]
	onAttributeChanged: (
		self: BaseComponent<IT, ST>,
		attribute: string,
		callback: (newValue: any, oldValue: any) -> ()
	) -> RBXScriptConnection,

	--[[
        Destroys the component and all its children with the instance.
        * Doesn't cancel the current task, so return the function manually
        @param self BaseComponent
        @return void
    ]]
	destroy: (self: BaseComponent<IT, ST>) -> (),

	--[[
        Removes the component from the instance.
        * Doesn't destroy the instance itself, but removes the component and all its children
        * Doesn't cancel the current task, so return the function manually
        @param self BaseComponent
        @return void
    ]]
	remove: (self: BaseComponent<IT, ST>) -> (),
}

--------------------------------------------------------------------------

export type FrameworkConfig = {
	--[[
        Enable/disable profiling in lifecycle hooks. Default is false
    ]]
	profiling: boolean?,
	--[[
        Timeout for promises in lifecycle hooks. Default is 10 seconds
    ]]
	promiseTimeout: number?,
}

return 0
