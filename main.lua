--[[
CountDown plugin, written by Scuba Steve 9.0.

Copyright info: 
Copyright Tyler Gibbons(Scuba Steve 9.0), 2011. Feel free to use, distribute, and modify any and all sections of code as 
	long as I am attributed as the original author of any code used, modified, or distributed. If you make something cool
	using this code, I'd love to know. Send me a message on IRC @ slashnet.org as 'kavec' and say hi!

This file is the entire plugin, I guess. It adds some new elements to the HUD to give conquering players better situational
awareness about timers and the like.
--]]
declare("countdown", {})

local cd = countdown

cd.VERSION = "1.0.0"
--[#] = {time_of_death_notification|false}
cd.turrets = {}
--[[--------------------------Interp/Comm Functions-------------------------]]--
function cd.ReadGroupMsg(msg) 
	tNum = msg:match("Turret %d+")
	--We have at least tNum turrets. Let's make sure our table reflects that
	for i=1, tNum do
		if(not cd.turrets[i]) then
			cd.turrets[i] = false
		end
	end
	--And bam, let's start our countdown
	cd.turrets[tNum] = GetGameTime()
end

function cd.GenRequestIter(group_players)
	return cd.GenRequestMsg, group_players, nil
end

function cd.GenRequestMsg(group_players, position)
	name, position = next(group_players, position)

	if not name then return nil end

	local rqst_msg = "#countdown#Rqst: %s":format(name)
	return rqst_msg, position
end
	
		
--function cd.RequestMsgReply()
--	msg = "#countdown#Rply: %s":

--[[----------------------------Update Functions----------------------------]]--
--Length of respawn timer in seconds.
cd.respawn_time = 900

local function time_color(secs)
	secs = secs/cd.respawn_time
	local g = (1.25*secs);	
	local r = (8.0*(1.0 - secs));
	if g > 1 then g = 1 end
	if r > 1 then r = 1 end
	r = r*255 + 10
	g = g*255 + 10
	if r > 255 then r = 255 end
	if g > 255 then g = 255 end
	return string.format("%.2x%.2x10", r,g)
end

local function flash_color(tog)
	return (tog == 1 and "40ccff") or "20ff10"
end

cd.last_text_index = 1
function cd.scrolling_text(text, num_chars)
	--Reduce num_chars so we don't go overboard and overflow our area
	num_chars = math.floor(num_chars * .98)

	--Return if we fit in scroll area
	if(text:len() <= num_chars) then return text. false end
	
	--Scroll otherwise!
	local scrolly = string.format("%s // %s", text, text):sub(cd.last_test_index, cd.last_test_index-1 + num_chars)
	cd.last_text_index = (cd.last_text_index < (text:len()+4) and (cd.last_text_index + 1)) or 1
	return scrolly, true
end

--Make sure to debug prior to use
--Check with VOClock for proper use of timers
local function set_updates_to_scroll_speed()
	cd.scrollspeed = true 
	cd.updatetimer.Kill()
	cd.updatetimer = Timer()
	cd.updatetimer.SetTimeout(250, function () 
						cd.UpdateTimers
						cd.updatetimer.SetTimeout(250)
					end)
end

local function set_updates_to_normal_speed()
	cd.scrollspeed = false
	cd.updatetimer.Kill()
	cd.updatetimer = Timer()
	cd.updatetimer.SetTimeout(500, function () 
						cd.UpdateTimers
						cd.turrets.updatetimer.SetTimeout(500)
					end)
end

function cd.UpdateTimers()
	local num_rets = #cd.turrets
	local timertext = {}
	local cur_time = gkmisc.GetGameTime()
	cd.timers.visible = "NO"
	for t = 1, num_rets do
		--15 minutes : 900 seconds
		--14:50 minutes : 890 seconds
		--We want to give a RESPAWNING... warning 10 seconds prior
		local diff = gkmisc.DiffTime(cd.turrets[i], cur_time)/1000
		if(cd.turrets[i]) then
			if(diff <= (cd.respawn_time-10)) then
				table.insert(timertext, string.format("\127f6f634Ret %d: \127%s%d:%d", i, time_color(diff), math.floor(diff/60), math.floor(diff%60)))
			elseif(diff <= cd.respawn_time) then
				table.insert(timertext, string.format("\127f6f634Ret %d: \127%sRespawning", i, flash_color(bitlib.band(diff, 1))))
			elseif(diff <= (cd.respawn_time+10)) then
				table.insert(timertext, string.format("\127f6f634Ret %d: \12740ccffRespawned", i))
			else
				cd.turrets[i] = false
			end
			if(cd.turrets[i]) then cd.timers.visible = "YES" end
		end
	end
	--Divide xsize by four to get average number of spaces for :words:
	cd.timers.title, warp_speed_scrolling = cd.scrolling_text(table.concat(timertext, " "), cd.timers.title:gsub("x%d+", "")/4)

	--Make sure our speeds are proper. Speeds may need tweaking.
	if(warp_speed_scrolling and not cd.scrollspeed) then set_updates_to_scroll_speed()
	elseif(cd.scrollspeed and not warp_speed_scrolling) then set_updates_to_normal_speed() end
end

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
		cd.updatetimer.Kill()
		cd.updatetimer = nil
	end
	cd.updatetimer = Timer()
	cd.updatetimer.SetTimeout(500, function() 
						cd.UpdateTimers
						cd.turrets.updatetimer.SetTimeout(500)
					end)
	RegisterUserEvent(init, "rHUDxscale")
end

function cd.exit()
	if(cd.updatetimer) then 
		cd.updatetimer.Kill()
		cd.updatetimer = nil
	end
	--Is it UnRegisterEvent?
	UnRegisterEvent(init, "rHUDxscale")
end

RegisterUserEvent(cd.init, "PLAYER_ENTERED_GAME")
RegisterUserEvent(cd.exit, "PLAYER_LOGGED_OUT")

