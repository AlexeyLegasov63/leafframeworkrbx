--!nocheck
--!optimize 2
--!native

--[[
    Originally from **LemonSignal** (1.10.0) Module by Kineticwallet

    Implements a minimal, disconnectable signal system for event handling.
    Provides 'Connect' and 'Fire' methods, similar to Roblox's RBXScriptSignal.
    Connections are stored in a weak table to prevent memory leaks if the Connection object is GCed.
]]

export type Connection<U...> = {
	Connected: boolean,

	Disconnect: (self: Connection<U...>) -> (),
	Reconnect: (self: Connection<U...>) -> (),
}

export type Signal<T...> = {
	RBXScriptConnection: RBXScriptConnection?,

	Connect: <U...>(self: Signal<T...>, fn: (...any) -> (), U...) -> Connection<U...>,
	Once: <U...>(self: Signal<T...>, fn: (...any) -> (), U...) -> Connection<U...>,
	Wait: (self: Signal<T...>) -> T...,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
	Destroy: (self: Signal<T...>) -> (),
}

local freeThreads: { thread } = {}

local function runCallback(callback, thread, ...)
	callback(...)
	table.insert(freeThreads, thread)
end

local function yielder()
	while true do
		runCallback(coroutine.yield())
	end
end

local Connection = {}
Connection.__index = Connection

local function disconnect<U...>(self: Connection<U...>)
	if not self.Connected then
		return
	end
	self.Connected = false

	local next = self._next
	local prev = self._prev

	if next then
		next._prev = prev
	end
	if prev then
		prev._next = next
	end

	local signal = self._signal
	if signal._head == self then
		signal._head = next
	end
end

local function reconnect<U...>(self: Connection<U...>)
	if self.Connected then
		return
	end
	self.Connected = true

	local signal = self._signal
	local head = signal._head
	if head then
		head._prev = self
	end
	signal._head = self

	self._next = head
	self._prev = false
end

Connection.Disconnect = disconnect
Connection.Reconnect = reconnect

--\\ Signal //--
local Signal = {}
Signal.__index = Signal

-- stylua: ignore
local rbxConnect, rbxDisconnect do
	if task then
		local bindable = Instance.new("BindableEvent")
		rbxConnect = bindable.Event.Connect
		rbxDisconnect = bindable.Event:Connect(function() end).Disconnect
		bindable:Destroy()
	end
end

local function connect<T..., U...>(self: Signal<T...>, fn: (...any) -> (), ...: U...): Connection<U...>
	local head = self._head
	local cn = setmetatable({
		Connected = true,
		_signal = self,
		_fn = fn,
		_varargs = if not ... then false else { ... },
		_next = head,
		_prev = false,
	}, Connection)

	if head then
		head._prev = cn
	end
	self._head = cn

	return cn
end

local function once<T..., U...>(self: Signal<T...>, fn: (...any) -> (), ...: U...)
	local cn
	cn = connect(self, function(...)
		disconnect(cn)
		fn(...)
	end, ...)
	return cn
end

local function wait<T...>(self: Signal<T...>): ...any
	local thread = coroutine.running()
	local cn
	cn = connect(self, function(...)
		disconnect(cn)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

local function fire<T...>(self: Signal<T...>, ...: any)
	local cn = self._head
	while cn do
		local thread
		if #freeThreads > 0 then
			thread = freeThreads[#freeThreads]
			freeThreads[#freeThreads] = nil
		else
			thread = coroutine.create(yielder)
			coroutine.resume(thread)
		end

		if not cn._varargs then
			task.spawn(thread, cn._fn, thread, ...)
		else
			local args = cn._varargs
			local len = #args
			local count = len
			for _, value in { ... } do
				count += 1
				args[count] = value
			end

			task.spawn(thread, cn._fn, thread, table.unpack(args))

			for i = count, len + 1, -1 do
				args[i] = nil
			end
		end

		cn = cn._next
	end
end

local function disconnectAll<T...>(self: Signal<T...>)
	local cn = self._head
	while cn do
		disconnect(cn)
		cn = cn._next
	end
end

local function destroy<T...>(self: Signal<T...>)
	disconnectAll(self)
	local cn = self.RBXScriptConnection
	if cn then
		rbxDisconnect(cn)
		self.RBXScriptConnection = nil
	end
end

--\\ Constructors
function Signal.new<T...>(): Signal<T...>
	return setmetatable({ _head = false }, Signal)
end

--\\ Methods
Signal.Connect = connect
Signal.Once = once
Signal.Wait = wait
Signal.Fire = fire
Signal.DisconnectAll = disconnectAll
Signal.Destroy = destroy

return Signal
