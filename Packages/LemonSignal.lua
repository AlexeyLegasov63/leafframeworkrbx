local REQUIRED_MODULE = require(script.Parent._Index["kineticwallet_lemon-signal@1.10.0"]["lemon-signal"])
export type Connection<U...> = REQUIRED_MODULE.Connection<U...>
export type Signal<T...> = REQUIRED_MODULE.Signal<T...>
return REQUIRED_MODULE
