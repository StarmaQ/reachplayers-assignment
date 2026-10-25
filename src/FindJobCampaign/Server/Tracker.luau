--[[
	Sends campaign events to the external analytics system.
	For now "sending" means printing JSON to the console.

	Every event carries the same envelope (campaign, version, place, server, user, time)
	so data from different host games can be compared side by side.

	What we measure and why:

	Funnel (where do players drop off?)
		NpcSeen               player walked near the stand           -> reach / impressions
		ConversationStarted   player talked to the recruiter         -> engagement rate
		DialogueSkipped       lines skipped while she was typing     -> is the copy too long?
		QuestionAnswered      which answer, how long they thought    -> question clarity
		Classified            field + scores + margin                -> how confident the match was
		MissionStarted        reached the station                    -> guide works?
		MissionAttempt        every answer (step + mistakes)         -> difficulty, which step is hard
		SubmissionRejected    malformed submissions                  -> abuse attempts
		MissionCompleted      attempts, time, first-try accuracy     -> completion rate
		RewardGranted         reward + whether the host handled it   -> reward delivery across games
		Exited                step they left at                      -> drop-off point

	Match quality (was the job we picked actually right?)
		FitFeedback           player says the job felt like them or not
		                      + mission performance + classification margin, summed up as a verdict:
		                      confirmed / likely / unsure_questions / mismatch.
		                      Lots of unsure_questions or mismatch = our questions need work.

	Brand exposure
		SessionEnded          total seconds spent with the FindJob experience
]]

local HttpService = game:GetService("HttpService")

-------------------------------------------------------------------------------
-- TRACKING SETTINGS
-------------------------------------------------------------------------------
local Settings = {
	-- Turns all tracking on or off
	Enabled = true,

	-- Identifies this campaign in the data. Bump Version when the questions or missions
	-- change, so results from before and after can be told apart.
	CampaignId = "findjob_career_match",
	Version = "2.0.0",

	-- Prints every event to the output as "[FindJob:Track] {json}"
	PrintToConsole = true,

	-- Leave out events you don't want to collect, e.g. { NpcSeen = true }
	Ignored = {},
}
-------------------------------------------------------------------------------

local Tracker = {}

-- Events the client is allowed to report through the Track remote.
-- Everything else is tracked by the server itself, so clients can't fake it.
Tracker.ClientEvents = {
	NpcSeen = true,
	DialogueSkipped = true,
}

local function sendData(payload)
	if Settings.PrintToConsole then
		print("[FindJob:Track]", HttpService:JSONEncode(payload))
	end
	-- [TODO] Replace with the real analytics call: batch the payloads and post them
	-- with HttpService:PostAsync (needs HTTP requests enabled in the host game)
end

function Tracker.track(player, eventName, data)
	if not Settings.Enabled or Settings.Ignored[eventName] then
		return
	end

	sendData({
		event = eventName,
		campaign = Settings.CampaignId,
		version = Settings.Version,
		placeId = game.PlaceId,
		serverId = game.JobId,
		userId = player.UserId,
		timestamp = DateTime.now().UnixTimestampMillis,
		data = data or {},
	})
end

return Tracker
