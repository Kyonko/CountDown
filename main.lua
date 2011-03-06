--[[
CountDown plugin, written by Scuba Steve 9.0.

Copyright info: 
Copyright Tyler Gibbons(Scuba Steve 9.0), 2011. Feel free to use, distribute, and modify any and all sections of code as 
	long as I am attributed as the original author of any code used, modified, or distributed. If you make something cool
	using this code, I'd love to know. Send me a message on IRC @ slashnet.org as 'kavec' and say hi!

This file is the entire plugin, I guess. It adds some new elements to the HUD to give conquering players better situational
awareness about timers and the like.
--]]

declare("turret_countdown", {})

--Bind to local variable to make name-changing easier if needed
local cd = turret_countdown
local active = false
cd.VERSION = "1.0.3"
--[#] = {time_of_death_notification|false}
cd.turrets = {}
--[[--------------------------Interp/Comm Functions-------------------------]]--
local needs_update = true
function cd.ReadGroupMsg(e, msg)
	if not msg then msg = e end
	if(type(msg) == "table") then msg = msg.msg or "" end
	local tNum = tonumber(msg:match("destroyed .+Turret (%d+)") or 0)
	--We have at least tNum turrets. Let's make sure our table reflects that
	for i=1, (tNum-1) do
		if(not cd.turrets[i]) then
			table.insert(cd.turrets, i, "none")
		end
	end
	--And bam, let's start our countdown
	
	if tNum ~= 0 then 
		if(cd.turrets[tNum]) then 
			cd.turrets[tNum] = gkmisc.GetGameTime() 
			return
		end
		table.insert(cd.turrets, tNum, gkmisc.GetGameTime()) 
	end
end

RegisterEvent(cd.ReadGroupMsg, "CHAT_MSG_DEATH") --local
--The rest are candidates to the group message, more testing will be needed to whittle this list down
RegisterEvent(cd.ReadGroupMsg, "CHAT_MSG_SERVER")
RegisterEvent(cd.ReadGroupMsg, "CHAT_MSG_GLOBAL_SERVER")
RegisterEvent(cd.ReadGroupMsg, "CHAT_MSG_CONFIRMATION")

function cd.GenRequestMsg(name)
	if not name then return nil end

	local rqst_msg = ("#countdown#Rqst: %s"):format(name)
	return rqst_msg
end
	
		
function cd.RequestMsgReply()
	if not active then return end
	local rep = {}
	for dex, val in ipairs(cd.turrets) do
		table.insert(rep, ("\"%s\""):format(val))
	end
	return ("#countdown#Rply: {%s}"):format(table.concat(rep, ","))
end

function cd.ParseReqMsgReply(msg)
	return {unpack(msg:match("{.+}"))}
end

cd.PDAChatLog = {}
cd.StationChatLog = {}
cd.CapShipChatLog = {}
function cd.HideCountDownMsgs()
	--Fuck it. Remove the next line if you have figured out how to hide this shit 
	--from the PDA, Station, and CapShip chats. 
	--The below doesn't work, ffffuu
	if(true) then return end
	
	
	--Okay, now hide our message from the specific private.
	_generalchatlog = GeneralChatPanel.log
	local found, dex = false, #_generalchatlog
	while (not found) and dex ~= 1 do 
		if(_generalchatlog[dex]:find("#countdown#", 10, true)) then
			found = true
			dex = dex + 1
		end
		dex = dex - 1
	end
	local rem = table.remove(_generalchatlog, dex)
	_generalchatlog.updated = false
	GeneralChatPanel.log = _generalchatlog
	GeneralChatPanel.chattext.value = table.concat(_generalchatlog, "\n")
	cd.PDAChatLog.value = table.concat(_generalchatlog, "\n")
	cd.StationChatLog.value = table.concat(_generalchatlog, "\n")
	cd.CapShipChatLog.value = table.concat(_generalchatlog, "\n") 
	iup.Refresh(PDAChatArea)
	iup.Refresh(StationChatArea)
	iup.Refresh(CapShipChatArea)
	return found
end

function cd.ProcessCountDownMsgs(e, info)
	local msg = info.msg
	if msg:find("#countdown#", 1, true) ~= 1 then return end
	
	local r_type, r_msg = msg:match("#countdown#(.-): (.*)")
	if(r_type == "Rqst" and r_msg == GetPlayerName(GetCharacterID())) then
		HUD:PrintSecondaryMsg(("Posted conquerable turret status to group"))
		SendChat(cd.RequestMsgReply(), "GROUP")
	elseif(r_type == "Rply" and (needs_update or not active)) then
		--Turn on and receive update if we see a reply to a request
		active = true
		needs_update = false
		ProcessEvent("MSG_NOTIFICATION", "Turret data seen, CountDown turning on.")
		
		local loaded = loadstring(("return %s"):format(r_msg))
		cd.turrets = loaded()
		HUD:PrintSecondaryMsg(("Received conquerable turret status from group"))
	end
end

RegisterEvent(cd.ProcessCountDownMsgs, "CHAT_MSG_GROUP")
local name_index = 1
cd.jointimer = Timer()
local show_msg = false
function cd.onGroupJoin()
	cd.turrets = {}
	if not active then 
		if not show_msg then
			HUD:PrintSecondaryMsg("CountDown is off. Use '/countdown on' to turn it on.")
			show_msg = true
		end
		return 
	end
	needs_update = true
	if (not IsGroupMember(GetCharacterID())) or not needs_update then 
		name_index = 1
		return 
	end
	
	local num_gmemb = GetNumGroupMembers()
	if(name_index > num_gmemb) then name_index = 1 end
	local name = GetPlayerName(GetGroupMemberID(name_index))
	if(name == GetPlayerName(GetCharacterID())) then
		--Don't need to ask ourselves
		name_index = name_index + 1
		name = GetPlayerName(GetGroupMemberID(name_index))
	end
	name_index = name_index + 1
	
	SendChat(cd.GenRequestMsg(name), "GROUP")
	HUD:PrintSecondaryMsg(("Requested conquerable turret status from %s."):format(name))
	--If we don't get a reply in 10 seconds, ask someone else
	cd.jointimer:SetTimeout(10000, function()
										if(needs_update) then
											cd.onGroupJoin()
											cd.jointimer:SetTimeout(10000)
										end
									end)
end

function cd.onGroupCreate()
	if not active then 
		HUD:PrintSecondaryMsg("CountDown is off. Use '/countdown on' to turn it on.")
		return 
	end
	HUD:PrintSecondaryMsg("CountDown is currently turned on.")
end

function cd.onGroupLeave()
	name_index = 1
	needs_update = true
	show_msg = true
end

RegisterEvent(cd.onGroupJoin, "GROUP_SELF_JOINED")
RegisterEvent(cd.onGroupCreate, "GROUP_CREATED")
--I forget if you automatically rejoin groups on login. This will set up for that
RegisterEvent(cd.onGroupJoin, "PLAYER_ENTERED_GAME")
RegisterEvent(cd.onGroupLeave, "GROUP_SELF_LEFT")
RegisterEvent(cd.onGroupLeave, "PLAYER_LOGGED_OUT")

	
	

--[[----------------------------Update Functions----------------------------]]--
--Length of respawn timer in seconds.
cd.respawn_time = 900

function time_color(secs)
	secs = 1 - secs/cd.respawn_time
	local g = (1.25*secs);	
	local r = (1.25*(1.0 - secs));
	if g > 1 then g = 1 end
	if r > 1 then r = 1 end
	r = r*255 + 10
	g = g*255 + 10
	if r > 255 then r = 255 end
	if g > 255 then g = 255 end
	return string.format("%.2x%.2x10", r,g)
end

local function flash_color(tog)
	return (tog == 1 and "40ccff") or "ff2010"
end

text_index = 1
function cd.scrolling_text(text, num_chars)
	--Reduce num_chars so we don't go overboard and overflow our area
	num_chars = math.floor(num_chars * .9)

	--Return if we fit in scroll area
	local no_color_tlen = text:gsub("\127%x%x%x%x%x%x", ""):len()
	if(no_color_tlen <= num_chars) then return text, false end
	
	--Scroll otherwise!
	local dtext = ("%s \127ffffff\/\/ %s"):format(text, text)
	local explod, ex_key, sanitext = {},  {}, dtext:gsub("\127%x%x%x%x%x%x", "")
	local find_start = 1
	for m in dtext:gmatch("\127%x%x%x%x%x%x[^\127]+") do
		local color = m:sub(1,7)
		local t = m:sub(8)
		local b1, b2 = sanitext:find(t, find_start, true)
		find_start = b2
		--Get rid of stuff we've already looked at
		table.insert(explod, {color = color, b1 = b1, b2 = b2})
		local tlen = #t
		for i=1, tlen do
			local elen = #explod
			table.insert(ex_key, elen)
		end
	end	
	local scrolltab = {}
	
	local dex = text_index
	while dex < (text_index + num_chars) do
		local dex_end = ((explod[ex_key[dex]].b2 > text_index + num_chars-1) and (text_index + num_chars -1)) or explod[ex_key[dex]].b2
		table.insert(scrolltab, ("%s%s"):format(explod[ex_key[dex]].color, sanitext:sub(dex, dex_end)))
		dex = explod[ex_key[dex]+1].b1
	end
	text_index = (text_index < (no_color_tlen+4) and (text_index + 1)) or 1		
	return table.concat(scrolltab), true
end

--Make sure to debug prior to use
--Check with VOClock for proper use of timers
local function set_updates_to_scroll_speed()
	cd.scrollspeed = true 
	cd.updatetimer:Kill()
	cd.updatetimer = Timer()
	cd.updatetimer:SetTimeout(250, function () 
						cd.UpdateTimers()
						cd.updatetimer:SetTimeout(150)
					end)
end

local function set_updates_to_normal_speed()
	cd.scrollspeed = false
	cd.updatetimer:Kill()
	cd.updatetimer = Timer()
	cd.updatetimer:SetTimeout(500, function () 
						cd.UpdateTimers()
						cd.updatetimer:SetTimeout(500)
					end)
end


function cd.UpdateTimers()
	local num_rets = #cd.turrets
	local timertext = {}
	local cur_time = gkmisc.GetGameTime()
	cd.timers.visible = "NO"
	for i = 1, num_rets do
		--15 minutes : 900 seconds
		--14:50 minutes : 890 seconds
		--We want to give a RESPAWNING... warning 10 seconds prior
		if(cd.turrets[i] ~= "none") then
			local diff = gkmisc.DiffTime(cd.turrets[i], cur_time)/1000
			if(not diff) then print (i) end
			--Colors get placed before spaces to prevent mismatching later on when numbers get involved. See the scrolly generation function
			if(diff <= (cd.respawn_time-10)) then
				table.insert(timertext, ("\127f6f634Ret %i:\127%s %.2u:%.2u"):format(i, time_color(diff), math.floor(diff%1000/60), math.floor(diff%60)))
			elseif(diff <= cd.respawn_time) then
				table.insert(timertext, ("\127f6f634Ret %i:\127%s Respawning"):format(i, flash_color(bitlib.band(diff, 1))))
			elseif(diff <= (cd.respawn_time+10)) then
				table.insert(timertext, ("\127f6f634Ret %i:\12740ccff Respawned"):format(i))
			else
				cd.turrets[i] = "none"
			end
			if(cd.turrets[i] ~= "none") then cd.timers.visible = "YES" end
		end
	end
	--Divide xsize by four to get average number of spaces for :words:
	if not cd.timers.size then return end --Stuff isn't mapped yet, die.
	local warp_speed_scrolling = false
	cd.timers.title, warp_speed_scrolling = cd.scrolling_text(table.concat(timertext," "), gkinterface.GetXResolution()*HUD_SCALE/7) --tonumber(cd.timers.size:gsub("x%d+", ""))/4)

	--Make sure our speeds are proper. Speeds may need tweaking.
	if(warp_speed_scrolling and not cd.scrollspeed) then set_updates_to_scroll_speed()
	elseif(cd.scrollspeed and not warp_speed_scrolling) then set_updates_to_normal_speed() end
end

function cd.OverwriteCB()
	cd.old_update_cb = GeneralChatPanel.update_cb
	local function new_update_cb (self)
		cd.old_update_cb(self)
		cd.HideCountDownMsgs()
	end
	GeneralChatPanel.update_cb = new_update_cb
	UnregisterEvent(cd.OverwriteCB, "CHAT_MSG_GROUP")
	
	cd.HideCountDownMsgs()
end

local gb = iup.GetBrother
local gc = iup.GetNextChild
function cd.init() 
	cd.timers = iup.label{title = "", expand = "HORIZONTAL", alignment = "ACENTER"}
	cd.ticker = iup.vbox { 
		iup.fill{}, 
		iup.hbox { 
			cd.timers,
			expand = "HORIZONTAL",
		}
	}
	

	iup.Append(HUD.pluginlayer, cd.ticker)
	
	if(cd.updatetimer) then 
		cd.updatetimer:Kill()
		cd.updatetimer = nil
	end
	cd.updatetimer = Timer()
	cd.updatetimer:SetTimeout(500, function() 
						cd.UpdateTimers()
						cd.updatetimer:SetTimeout(500)
					end)
	
	active = gkini.ReadInt("countdown", "active", 0)==1
	--Get our chatlogs. Hope updates don't break these locations
	cd.PDAChatLog = gb(gc(gc(gb(gc(PDAChatArea)))))
	cd.StationChatLog = gb(gc(gc(gb(gc(StationChatArea)))))
	cd.CapShipChatLog = gb(gc(gc(gb(gc(CapShipChatArea)))))
	
	--RegisterEvent(cd.OverwriteCB, "CHAT_MSG_GROUP")
	RegisterEvent(cd.init, "rHUDxscale")
end

function cd.exit()
	if(cd.updatetimer) then 
		cd.updatetimer:Kill()
		cd.updatetimer = nil
	end
	
	GeneralChatPanel.update_cb = cd.old_update_cb
	UnregisterEvent(cd.init, "rHUDxscale")
end

RegisterEvent(cd.init, "PLAYER_ENTERED_GAME")
RegisterEvent(cd.exit, "PLAYER_LOGGED_OUT")

if(GetCharacterID()) then
	cd.init()
end

--[[----------------------------CLI Crap----------------------------]]--

function cd.cli (_, input)
	if(not input) then
		active = not active
		print(("\127ffffffCountDown turned %s"):format((active and "on") or "off"))
		gkini.WriteInt("countdown", "active", (active and 1) or 0)
		return
	end
	input[1] = input[1]:lower()
	if(input[1] == "help") then
		print("\127ffffffUsage: /countdown [on|off|help]\n\t\tCalling with zero arguments toggles on/off status. Version " .. cd.VERSION)
	elseif(input[1] == "off") then
		print("\127ffffffCountDown turned off")
		gkini.WriteInt("countdown", "active", 0)
		active = false
	else
		print("\127ffffffCountDown turned on")
		gkini.WriteInt("countdown", "active", 1)
		active = true
	end
end

RegisterUserCommand("countdown", cd.cli)