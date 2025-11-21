repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
local queue_on_teleport = (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport) or queue_on_teleport or function(Script) end

local Utilities = {}
do

    function Utilities.CombineTables(Base, ToAdd)

        Base = Base or {}
        ToAdd = ToAdd or {}

        for i, v in pairs(ToAdd) do

            local BaseValue = Base[i] or false
            if (typeof(v) == "table" and typeof(BaseValue) == "table") then
                Utilities.CombineTables(BaseValue, v)
                continue
            end

            Base[i] = v
        end

        return Base
    end

    function Utilities.DeepCopy(Original)

        assert(typeof(Original) == "table", "invalid type for Original (expected table)")

        local Copy = {}

        for i, v in pairs(Original) do

            if (typeof(v) == "table") then
                v = Utilities.DeepCopy(v)
            end

            Copy[i] = v
        end

        return Copy
    end
end

local HopManager = {}
HopManager.__index = HopManager
HopManager.__type = "HopManager"
do

    HopManager.DefaultData = {
        HopMode = "Random", 
        KickBeforeTeleport = true,
        KickMessage = "Teleporting...",
        MinimumPlayers = 1,
        MaximumPlayers = 1/0,
        HopInterval = 300,
        RetryDelay = 1,
        DataRetryDelay = 1,
        SaveLocation = "recenthops.json",
        ServerFormat = "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&excludeFullGames=true&cursor=%s",
        RecentHops = {},
        MassServerList = {
            Enabled = false,
            RemoveAfterTeleport = false,
            Refresh = 300,
            Amount = 500,
            MinimumServers = 100,
            SaveLocation = "massserver.json",
        },
        RetrySame = {
            Enum.TeleportResult.Flooded
        }
    }

    function HopManager.new(Data)

        Data = Data or {}
        assert(typeof(Data) == "table", "invalid type for Data (expected table)")

        local self = setmetatable({}, HopManager)

        self.Data = Utilities.CombineTables(Utilities.DeepCopy(HopManager.DefaultData), Data)

        self:LoadFromFile()

        return self
    end

    function HopManager:LoadFromFile()

        local Data = self.Data
        local RecentHopData = isfile(Data.SaveLocation) and readfile(Data.SaveLocation) or "{}"

        local _, RecentHops = pcall(HttpService.JSONDecode, HttpService, RecentHopData)
        Data.RecentHops = typeof(RecentHops) == "table" and RecentHops or {}

        return Data.RecentHops
    end

    function HopManager:Save()
        local Data = self.Data
        writefile(Data.SaveLocation, HttpService:JSONEncode(Data.RecentHops))
    end

    function HopManager:SaveJobId(JobId)

        assert(typeof(JobId) == "string", "invalid type for JobId (expected string)")

        self.Data.RecentHops[JobId] = DateTime.now().UnixTimestamp
        self:Save()

        return true
    end

    function HopManager:ValidateServer(Server)

        local Data = self.Data
        local PlayerCount = Server.playing or 0
        local MaxPlayers = Server.maxPlayers or 1/0
        local ServerJobId = Server.id

        if (game.JobId == ServerJobId) then
            return false
        end

        if not (PlayerCount >= Data.MinimumPlayers and PlayerCount <= MaxPlayers and PlayerCount <= Data.MaximumPlayers) then
            return false
        end

        local Now = DateTime.now().UnixTimestamp
        local HopData = Data.RecentHops[ServerJobId]
        if (HopData and (Now - HopData) > Data.HopInterval) then
            return false
        end

        return true
    end

    function HopManager:GetServerDataURL(Url)

        local Data

        while (not Data) do

            pcall(function()
                Data = HttpService:JSONDecode(game:HttpGet(Url))
            end)

            if (Data) then
                break
            end

            local Delay = self.Data.DataRetryDelay
            print("GetServerDataURL errored, retrying in", Delay, "seconds")

            task.wait(Delay)
        end

        return Data
    end

    function HopManager:GetMassServerListCreate(PlaceId, Count)

        local Data = self.Data
        Count = Count or Data.MassServerList.Amount
        PlaceId = PlaceId or game.PlaceId
        assert(typeof(PlaceId) == "number", "invalid type for PlaceId (expected number)")
        assert(typeof(Count) == "number", "invalid type for Count (expected number)")

        local ServerListPlaceId = {}

        local Cursor = ""
        while (true) do

            if (not Cursor or #ServerListPlaceId >= Count) then
                break
            end

            local ServersURL = Data.ServerFormat:format(PlaceId, Cursor)
            local ServerData = self:GetServerDataURL(ServersURL)

            for _, Server in ipairs(ServerData.data) do

                if (#ServerListPlaceId >= Count) then
                    break
                end

                if (not self:ValidateServer(Server)) then
                    continue
                end

                table.insert(ServerListPlaceId, Server)
            end

            Cursor = ServerData.nextPageCursor
        end

        return ServerListPlaceId
    end
    function HopManager:GetMassServerList(PlaceId)

        PlaceId = PlaceId or game.PlaceId
        assert(typeof(PlaceId) == "number", "invalid type for PlaceId (expected number)")
        local sPlaceId = tostring(PlaceId)

        local ConfigData = self.Data.MassServerList
        if (not isfile(ConfigData.SaveLocation)) then
            writefile(ConfigData.SaveLocation, "{}")
        end

        local Now = DateTime.now().UnixTimestamp

        local _, ServerList = pcall(HttpService.JSONDecode, HttpService, readfile(ConfigData.SaveLocation))
        ServerList = ServerList or {}
        ServerList.Time = ServerList.Time or Now
        ServerList[sPlaceId] = ServerList[sPlaceId] or {}

        if (#ServerList[sPlaceId] <= ConfigData.MinimumServers) or (Now - ServerList.Time > ConfigData.Refresh)  then
            ServerList[sPlaceId] = self:GetMassServerListCreate(PlaceId)
            ServerList.Time = Now
            writefile(ConfigData.SaveLocation, HttpService:JSONEncode(ServerList))
        end

        return ServerList
    end

    function HopManager:GetServerList(PlaceId)

        PlaceId = PlaceId or game.PlaceId
        assert(typeof(PlaceId) == "number", "invalid type for PlaceId (expected number)")

        return self.Data.MassServerList.Enabled and self:GetMassServerList(PlaceId) or {
            Time = DateTime.now().UnixTimestamp,
            [tostring(PlaceId)] = self:GetMassServerListCreate(PlaceId, 100)
        }
    end

    function HopManager:FailsafeHop(...)

        local ExtraArgs = {...}
        local Data = self.Data

        local Connection
        Connection = TeleportService.TeleportInitFailed:Connect(function(Player, TeleportResult, ErrorMessage, PlaceId, TeleportOptions)

            if (Player ~= LocalPlayer) then
                return
            end

            local JobId = table.find(Data.RetrySame, TeleportResult) and TeleportOptions.ServerInstanceId

            print("Teleport failed, TeleportResult: " .. TeleportResult.Name)
            Connection:Disconnect()

            task.delay(Data.RetryDelay, function()
                print("Reattempting teleport")
                self:Hop(PlaceId, JobId, unpack(ExtraArgs))
            end)
        end)

        return Connection
    end

    function HopManager:Hop(PlaceId, JobId, Script)

        PlaceId = PlaceId or game.PlaceId
        Script = Script or ""
        assert(typeof(PlaceId) == "number", "invalid type for PlaceId (expected number)")
        assert(typeof(JobId) == "string" or JobId == nil, "invalid type for JobId (expected string or nil)")
        assert(typeof(Script) == "string", "invalid type for Script (expected string)")

        local sPlaceId = tostring(PlaceId)
        local Servers
        if (not JobId) then

            local HopMode = self.Data.HopMode
            Servers = self:GetServerList(PlaceId)
            local PlaceServers = Servers[sPlaceId]
            assert(PlaceServers, "unable to get PlaceServers")

            if (#PlaceServers == 0) then

                print("Got 0 servers, trying again...")
                return self:Hop(PlaceId, JobId, Script)
            end

            local i = HopMode
            if (typeof(HopMode) == "string") then
                if (HopMode == "Random") then
                    i = math.random(1, #PlaceServers)
                elseif (HopMode == "Middle") then
                    i = math.round(#PlaceServers / 2)
                end
            end
            local TargetServer = PlaceServers[i]

            JobId = TargetServer.id
        end

        self:SaveJobId(JobId)

        queue_on_teleport(Script)

        if (self.Data.KickBeforeTeleport) then
            LocalPlayer:Kick(self.Data.KickMessage)
            task.wait()
        end

        local MassServerList = self.Data.MassServerList
        if (Servers and MassServerList.Enabled and MassServerList.RemoveAfterTeleport) then
            table.remove(Servers[sPlaceId], 1)
            writefile(MassServerList.SaveLocation, HttpService:JSONEncode(Servers))
        end

        self:FailsafeHop(Script)
        TeleportService:TeleportToPlaceInstance(PlaceId, JobId)
    end
end

return HopManager, Utilities
