-- Tiny signal class so the host game can listen to campaign events with :Connect,
-- the same way it would with any Roblox event.

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _listeners = {} }, Signal)
end

function Signal:Connect(callback)
	local connection = {}
	function connection.Disconnect()
		self._listeners[connection] = nil
	end

	self._listeners[connection] = callback
	return connection
end

function Signal:Fire(...)
	for _, callback in self._listeners do
		task.spawn(callback, ...)
	end
end

function Signal:HasConnections()
	return next(self._listeners) ~= nil
end

return Signal
