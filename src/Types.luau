--!strict

local Signal = require(script.Parent.Utils.Signal)

export type Node = {
	Name: string,
}

export type LifeCycleHooks = {
    onTick: (self: LifeCycleHooks, delta: number) -> ()?,
    onRender: (self: LifeCycleHooks, delta: number) -> ()?,
    onPhysics: (self: LifeCycleHooks, delta: number) -> ()?,
}

export type Cleaner = {
    add: <T> (self: Cleaner, task: T) -> T,
    extend: (self: Cleaner) -> Cleaner,
    cleanup: (self: Cleaner) -> (),
}

export type Connection<U...> = Signal.Connection<U...>

export type Signal<T...> = Signal.Signal<T...>

export type Component<IT, ST = nil, Args... = ()> = LifeCycleHooks & Node & {
	Instance: IT, -- Instance
	Tag: string?, -- Tag
	Super: ST?, -- Superclass

    -- InstanceOf check
    isA: (self: Component<IT, ST>, component: string) -> boolean,

    -- Lifecycle
    onSpawn: (self: Component<IT, ST>, Args...) -> (),
    onDespawn: (self: Component<IT, ST>) -> (),
}

--[[
    BaseComponent class

    @param IT Instance
    @param ST? Superclass
]]
export type BaseComponent<IT, ST = nil, Args... = ()> = Component<IT, ST, Args...> & {
	Attributes: { [string]: any }?,

    Cleaner: Cleaner,

    WhitelistedAncestors: { Instance }?,
    BlacklistedAncestors: { Instance }?,

    Predicate: (instance: Instance) -> boolean?,

    -- Cleaner:add shortcut
    onDestroy: <T> (self: BaseComponent<IT, ST>, task: T) -> T,

    -- Attribute access
    onAttributeChanged: (self: BaseComponent<IT, ST>, attribute: string, callback: (newValue: any, oldValue: any) -> ()) -> RBXScriptConnection,

    -- Utility (Destroys the instance)
    destroy: (self: BaseComponent<IT, ST>) -> (),

    -- Utility (Removes the component from the instance)
    remove: (self: BaseComponent<IT, ST>) -> (),
}

export type Components = {
    waitForFirstComponent: <T> (self: Components, component: string) -> (self: Components, component: string) -> T,
    watchComponent: (self: Components, component: string, callback: (instance: Instance) -> ()) -> RBXScriptConnection,
    
    getComponents: (self: Components, component: string) -> { Instance },
    getDescendantsOf: (self: Components, component: string) -> { string },
    getInstancesWithComponent: (self: Components, component: string, excludeDescendants: boolean?) -> { Instance },

    addComponent: (self: Components, instance: Instance, componentName: string, skipTest: boolean?, ...any) -> (),
    removeComponent: (self: Components, instance: Instance, componentName: string) -> boolean,

    getComponent: <T> (self: Components, instance: Instance, componentName: string) -> T?,
    hasComponent: (self: Components, instance: Instance, componentName: string) -> boolean,

    componentIsA: (self: Components, instance: Instance, componentName: string, component: string) -> boolean,

    onComponentSpawned: Signal<string, BaseComponent<Instance>>,
    onComponentDespawned: Signal<string, BaseComponent<Instance>>,
}

--------------------------------------------------------------------------

export type FrameworkConfig = {
	profiling: boolean?, -- Enable/disable profiling
	promiseTimeout: number?, -- Timeout for promises in lifecycle hooks
}

return 0
