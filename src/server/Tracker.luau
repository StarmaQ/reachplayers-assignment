--[[
	Sends campaign events to the (pretend) external analytics system.
	For now "sending" means printing JSON to the console.

	Every event carries the same envelope (campaign, version, place, server, user)
	so data from different host games can be compared side by side.

	What we measure and why:

	Funnel (where do players drop off?)
		NpcSeen               player walked near the building        -> reach / impressions
		ConversationStarted   player talked to the recruiter         -> engagement rate
		QuestionAnswered      which answer, how long they thought    -> question clarity
		Classified            field + scores + margin                -> how confident the match was
		MissionStarted        reached the station                    -> guide works?
		MissionAttempt        every submission, with mistakes        -> difficulty
		MissionCompleted      attempts, time, first-try accuracy     -> completion rate
		RewardGranted         reward + whether the host handled it   -> reward delivery across games
		Exited                step they left at                      -> drop-off point

	Match quality (was the job we picked actually right?)
		FitFeedback           player says the job felt like them or not
		                      + mission performance + classification margin.
		                      Low margin + many mistakes + "no" = our questions need work.

	Brand exposure
		SessionEnded          total seconds spent with the FindJob experience
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.FindJobCampaign.Config)

local Tracker = {}

-- Events the client is allowed to report through the Track remote.
-- Everything else is tracked by the server itself.
Tracker.ClientEvents = {
	NpcSeen = true,
	DialogueSkipped = true,
}

function Tracker.track(player, eventName, data)
	if not Config.Tracking.Enabled then
		return
	end

	local payload = {
		event = eventName,
		campaign = Config.CampaignId,
		version = Config.Version,
		placeId = game.PlaceId,
		serverId = game.JobId,
		userId = player.UserId,
		timestamp = DateTime.now().UnixTimestampMillis,
		data = data or {},
	}

	if Config.Tracking.PrintToConsole then
		print("[FindJob:Track]", HttpService:JSONEncode(payload))
	end
	-- A real build would batch these and post them with HttpService:PostAsync
end

return Tracker
