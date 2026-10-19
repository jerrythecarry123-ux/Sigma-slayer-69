--!strict
-- Pure authorization state. Positions and living character checks belong to the server.
local Rules = {}
Rules.Destinations = table.freeze({
	table.freeze({ Id = "harbor", Name = "Sundrift Harbor", Detail = "Town & fishing pier" }),
	table.freeze({ Id = "blossom", Name = "Petalwind Grove", Detail = "Blossom pond" }),
	table.freeze({ Id = "forest", Name = "Evergreen Reach", Detail = "Forest fishing" }),
	table.freeze({ Id = "cove", Name = "Tideglass Cove", Detail = "Beach & lagoon" }),
	table.freeze({ Id = "summit", Name = "Starfall Lookout", Detail = "Mountaintop pond" }),
})
Rules.MaxDistance = 18
Rules.MenuLifetime = 30
Rules.Cooldown = 1.5
local destinationIds: { [string]: boolean } = {}
for _, destination in Rules.Destinations do destinationIds[destination.Id] = true end

export type Ticket = { source: string, destination: string }
type Menu = { source: string, expiresAt: number }
type Data = {
	menus: { [number]: Menu }, pending: { [number]: Ticket },
	lastOpen: { [number]: number }, lastRequest: { [number]: number },
}
Rules.__index = Rules
export type TravelState = typeof(setmetatable({} :: Data, Rules))

local function finite(value: number): boolean
	return value == value and math.abs(value) < math.huge
end

function Rules.isDestination(value: any): boolean
	return type(value) == "string" and #value <= 16 and destinationIds[value] == true
end

local function near(distance: number): boolean
	return finite(distance) and distance >= 0 and distance <= Rules.MaxDistance
end

function Rules.new(): TravelState
	return setmetatable({ menus = {}, pending = {}, lastOpen = {}, lastRequest = {} }, Rules)
end

function Rules.open(self: TravelState, userId: number, source: string, now: number, distance: number): boolean
	if not Rules.isDestination(source) or not finite(now) or not near(distance) or self.pending[userId] then return false end
	local previous = self.lastOpen[userId]
	if previous and now - previous < 0.4 then return false end
	local lastRequest = self.lastRequest[userId]
	if lastRequest and now - lastRequest < Rules.Cooldown then return false end
	self.lastOpen[userId] = now
	self.menus[userId] = { source = source, expiresAt = now + Rules.MenuLifetime }
	return true
end

function Rules.source(self: TravelState, userId: number): string?
	local menu = self.menus[userId]
	return if menu then menu.source else nil
end

function Rules.take(self: TravelState, userId: number, destination: any, now: number, distance: number): Ticket?
	local menu = self.menus[userId]
	if not menu or self.pending[userId] or not Rules.isDestination(destination) or destination == menu.source
		or not finite(now) or now >= menu.expiresAt or not near(distance) then return nil end
	local previous = self.lastRequest[userId]
	if previous and now - previous < Rules.Cooldown then return nil end
	local ticket = { source = menu.source, destination = destination :: string }
	self.menus[userId], self.pending[userId], self.lastRequest[userId] = nil, ticket, now
	return ticket
end

function Rules.isPending(self: TravelState, userId: number, ticket: Ticket): boolean
	return self.pending[userId] == ticket
end

function Rules.finish(self: TravelState, userId: number, ticket: Ticket): boolean
	if self.pending[userId] ~= ticket then return false end
	self.pending[userId] = nil
	return true
end

function Rules.remove(self: TravelState, userId: number)
	self.menus[userId], self.pending[userId], self.lastOpen[userId], self.lastRequest[userId] = nil, nil, nil, nil
end

return Rules
