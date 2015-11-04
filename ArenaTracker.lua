local strfind = string.find

ArenaTracker = { }
ArenaTracker.eventHandler = CreateFrame("Frame")
ArenaTracker.eventHandler.events = { }

ArenaTracker.eventHandler:RegisterEvent("ADDON_LOADED")
ArenaTracker.eventHandler:RegisterEvent("PLAYER_LOGIN")
ArenaTracker.eventHandler:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
ArenaTracker.eventHandler:RegisterEvent("PLAYER_LOGOUT")
arenaTrackerNotes = ""
arenaTrackerIsArena = false

 StaticPopupDialogs["ArenaTracker_SetVariable"] = {
    text = "Match Notes?",
    button1 = "Save",    
    button2 = "Cancel",    
	hasEditBox = 1,
	hasWideEditBox = 1,
	editBoxWidth = 450,
	maxLetters = 250,
    whileDead = 1,
    hideOnEscape = 1,	
    timeout = 0,
    
    OnShow = function(self)
      --nothing for now
    end,
	OnHide = function(self)
      -- Regardless of whether a note was collected, save off the data 
	  -- when the message box goes away.
	  --[[  naw, not working.
	  print("Writing match log - run script to update server")
	  arenaTrackerDebug = arenaTrackerDebug.."|Final write after notes"		
	  tinsert(arenaTrackerFight, arenaTrackerCurrentFight)				
	  ArenaTracker:ResetBattleVariables()  			  
	  ]]--
    end,
    OnAccept = function(self)
	  local editBox = _G[self:GetName().."WideEditBox"] or _G[self:GetName().."EditBox"]
      arenaTrackerNotes = editBox:GetText()	
	  -- If they entered text, save it off.  
	  if arenaTrackerNotes ~= "" then
		-- if the fight hasn't been cleared, append.
		if (arenaTrackerCurrentFight ~= "") then
			print("appending notes to current fight")
			arenaTrackerCurrentFight = arenaTrackerCurrentFight.."NOTES:"..arenaTrackerNotes.." ENOTES"
		else
			-- If it *has* been cleared, append it to the last element in the fight array.
			print("appending notes to saved fight")
			arenaTrackerFight[#arenaTrackerFight] = arenaTrackerFight[#arenaTrackerFight].."NOTES:"..arenaTrackerNotes.." ENOTES"
		end		
		print ("Wrote Notes from Save: "..arenaTrackerNotes)			
	  end	  	  

	  self:Hide()
    end,     
	EditBoxOnEnterPressed = function(self)
	  print("Pressed enter")
      arenaTrackerNotes = self:GetText()	
--[[      
	  if arenaTrackerNotes ~= "" then
		  arenaTrackerCurrentFight = arenaTrackerCurrentFight.."NOTES:"..arenaTrackerNotes.." ENOTES"
		  print ("Wrote Notes from Enter: "..arenaTrackerNotes)			
	  end	  
]]--	 

	  -- If they entered text, save it off.  
	  if arenaTrackerNotes ~= "" then
		-- if the fight hasn't been cleared, append.
		if (arenaTrackerCurrentFight ~= "") then
			print("appending notes to current fight")
			arenaTrackerCurrentFight = arenaTrackerCurrentFight.."NOTES:"..arenaTrackerNotes.." ENOTES"
		else
			-- If it *has* been cleared, append it to the last element in the fight array.
			print("appending notes to saved fight")
			arenaTrackerFight[#arenaTrackerFight] = arenaTrackerFight[#arenaTrackerFight].."NOTES:"..arenaTrackerNotes.." ENOTES"
		end		
		print ("Wrote Notes from Save: "..arenaTrackerNotes)			
	  end	  	  

 
	  self:GetParent():Hide() 
    end, 
	EditBoxOnEscapePressed = function(self)
	  print("Pressed escape")      	 
	  self:GetParent():Hide() 	  
    end,
	OnCancel = function(self)
      print("Pressed cancel")
	  self:Hide()	 
    end
  };

ArenaTracker.eventHandler:SetScript("OnEvent", function(self, event, ...)
	if event == "PLAYER_LOGIN" then
		ArenaTracker:OnInitialize()
		ArenaTracker:OnEnable()
		ArenaTracker.eventHandler:UnregisterEvent("PLAYER_LOGIN")
		arenaTrackerDebug = "UI LOADED"
	elseif event == "PLAYER_LOGOUT" and (arenaTrackerCurrentScores ~= "") then
		-- If we log out directly from arena and there is info in our
		-- holding variables, write it out.
		self:WriteLog()
	else
		local func = self.events[event]
		if type(ArenaTracker[func]) == "function" then	
			ArenaTracker[func](ArenaTracker, event, ...)  
		end
	end
end)

function ArenaTracker:ZONE_CHANGED_NEW_AREA()
	local _, instanceType = IsInInstance()
	-- check if we are entering or leaving an arena 
	print ("Changed Area")
	--arenaTrackerDebug = arenaTrackerDebug.."|Changed area2"
	-- StaticPopup_Show("ArenaTracker_SetVariable", txt);	
	
	if instanceType == "arena" then				
		self:JoinedArena()
		arenaTrackerIsArena = true
	elseif instanceType ~= "arena" and self.instanceType == "arena" then		
		self:LeftArena()
		arenaTrackerIsArena = false
		print("NOT IN ARENA")
	else -- TESTING
		arenaTrackerIsArena = false
		print("NOT ARENA")
	end
	self.instanceType = instanceType
	
	-- If we change zone and there is information in our holding variables,
	-- add it to the table and flush out the variables
	if (arenaTrackerCurrentScores ~= "") then
		self:WriteLog()
	end
end


function ArenaTracker:OnInitialize()	
--print("OnInitialize")
	-- jnr - initialize fight count variable and fight array here
	self:ResetAllVariables()
	-- If the saved variable arenaTrackerFights isn't set up right, set it up as an empty table.
	if (arenaTrackerDebug == nil) then		
		arenaTrackerDebug = ""				
	end 
	
	if (type(arenaTrackerFight) ~= nil) then
		if (type(arenaTrackerFight) ~= "table") then
			arenaTrackerDebug = arenaTrackerDebug.."|INITIALIZING arenaTrackerFight!!!!"
			arenaTrackerFight = { }
		end	
	end 	
	
	arenaTrackerDebug = arenaTrackerDebug.."###|Init"	
		
end


function ArenaTracker:OnEnable()
--print("OnEnable")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA") -- always on
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA")
	self:RegisterEvent("ARENA_PREP_OPPONENT_SPECIALIZATIONS")
	-- For logging things properly!
	self:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
	self:RegisterEvent("PLAYER_LOGOUT"); -- Fired when about to log out
	
	if IsLoggedIn() then
		ArenaTracker:ZONE_CHANGED_NEW_AREA()
	end
end -- end


function ArenaTracker:ResetAllVariables()
--print("ResetAllVariables")
	arenaTrackerFightCount = 0
	self:ResetBattleVariables()  
end -- end ResetAllVariables


function ArenaTracker:ResetBattleVariables()
--print("ResetBattleVariables")
	arenaTrackerJoined = ""
	arenaTrackerLeft = ""
	arenaTrackerDeaths = ""
	arenaTrackerCurrentFight = ""		
	arenaTrackerCurrentScores = ""	
	arenaTrackerTalentsGlyphs = ""
	arenaTrackerNotes = ""
end -- end ResetBattleVariables

function ArenaTracker:WriteLog()
--print("Check Write Log.")
arenaTrackerDebug = arenaTrackerDebug.."|preWRITELOG"
	if arenaTrackerWinner and (arenaTrackerWinner == 1 or arenaTrackerWinner == 0) then

		-- This should only happen once per fight, and it should always happen, so increment the fight count here.
		arenaTrackerFightCount = arenaTrackerFightCount + 1
		arenaTrackerDebug = arenaTrackerDebug.."|Writing out, fight count"..arenaTrackerFightCount	
		arenaTrackerDebug = arenaTrackerDebug.."|Joined"..arenaTrackerJoined
		arenaTrackerDebug = arenaTrackerDebug.."|Left"..arenaTrackerLeft
		arenaTrackerDebug = arenaTrackerDebug.."|Joined"..arenaTrackerDeaths
		arenaTrackerCurrentFight = "Fight:"..arenaTrackerFightCount..","..arenaTrackerCurrentFight..",JOINED:"..arenaTrackerJoined..",LEFT:"..arenaTrackerLeft..","..arenaTrackerDeaths
		
		-- Add a timestamp			
		local thedate = date("%Y-%m-%d").."T"..date("!%H:%M:%S")
		arenaTrackerCurrentFight = thedate..","..arenaTrackerCurrentFight..arenaTrackerCurrentScores..arenaTrackerTalentsGlyphs
		
		local txt = ""
		StaticPopup_Show("ArenaTracker_SetVariable", txt);		
	
		-- This probably happens before note are entered, so handling 
		-- notes up in the messagebox.
		arenaTrackerDebug = arenaTrackerDebug.."| Inserting for final write"			
		tinsert(arenaTrackerFight, arenaTrackerCurrentFight)				
		self.ResetBattleVariables()  			  
		print("Wrote log")		


	end -- don't bother writing log if there's no real winner.
end -- end WriteLog




function ArenaTracker:RegisterEvent(event, func)
--print("RegisterEvent")
	self.eventHandler.events[event] = func or event
	self.eventHandler:RegisterEvent(event)
end

function ArenaTracker:UnregisterEvent(event)
--print("UnregisterEvent")
	self.eventHandler.events[event] = nil
	self.eventHandler:UnregisterEvent(event)
end

function ArenaTracker:UnregisterAllEvents()
--print("UnregisterAllEvents")
	self.eventHandler:UnregisterAllEvents()
end

function ArenaTracker:JoinedArena()
	-- IF we are here and we have information in our holding variables,
	-- it means that we've joined an arena match without leaving the other 
	-- one, and we were put in the same arena.
	if (arenaTrackerCurrentScores ~= "") then
		self:WriteLog()
	end

	-- special arena event	
	self:RegisterEvent("ARENA_OPPONENT_UPDATE") 
	self:RegisterEvent("ARENA_PREP_OPPONENT_SPECIALIZATIONS")
	self:RegisterEvent("UNIT_HEALTH") 
	self:RegisterEvent("UNIT_MAXHEALTH", "UNIT_HEALTH")
	self:RegisterEvent("UNIT_AURA")
	self:RegisterEvent("UNIT_SPELLCAST_START")		
	-- jnr	
	local thedate = date("%Y-%m-%d").."T"..date("!%H:%M:%S") 
	arenaTrackerDebug = arenaTrackerDebug.."|JOINED ARENA: "..thedate
	arenaTrackerJoined = thedate
	
	self:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")		
	self:RegisterEvent("PLAYER_LOGOUT"); -- Fired when about to log out		
	
	local jnrFaction = GetBattlefieldArenaFaction()
	arenaTrackerCurrentFight = "ZONE:"..GetZoneText()..",PLAYER:"..UnitName("player")
	local realm = GetRealmName()
	arenaTrackerCurrentFight = arenaTrackerCurrentFight..",REALM:"..realm	
		
	arenaTrackerTalentsGlyphs = ""
	arenaTrackerCurrentScores = ""	
	
end

function ArenaTracker:UNIT_HEALTH(event, unit)	
	if arenaTrackerIsArena then
		if not unit then
			arenaTrackerDebug = arenaTrackerDebug.."@"		
			return
		end	
		
		if not self:IsValidUnit(unit) then
			--arenaTrackerDebug = arenaTrackerDebug.."BAD:"..unit			
			return
		end	
		
		if UnitIsDeadOrGhost(unit) then
			-- Log death time.
			local name = "unknownname"
			local realm = "unknownrealm"
			local thedate = date("%Y-%m-%d").."T"..date("!%H:%M:%S")	
			local fullname = "unknownname"
			name, realm = UnitName(unit)
			if realm then
				fullname = name.."-"..realm
			else
				fullname = name
			end
			--print(fullname.."|"..thedate)		
			arenaTrackerDeaths = arenaTrackerDeaths.."BDEATH:"..fullname.."|"..thedate.." EDEATH"
		end
	end -- make sure we're in arena in the first place =)
end

function ArenaTracker:IsValidUnit(unit)
	return (strfind(unit, "arena") or strfind(unit, "party") or strfind(unit, "player"))
			and not strfind(unit, "pet")
end

function ArenaTracker:LeftArena()	
	arenaTrackerDebug = arenaTrackerDebug.."|LEFT ARENA "
	
	-- unregister combat events
	arenaTrackerDebug = arenaTrackerDebug.."|UnregisteringEvents"
	self:UnregisterAllEvents()	
	arenaTrackerDebug = arenaTrackerDebug.."|RegingEvents"
	self:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")	
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA")
	self:RegisterEvent("PLAYER_LOGOUT"); 
end

function ArenaTracker:UPDATE_BATTLEFIELD_SCORE(event)
--print "Got battlefield score update"	
	local isArenaMatch = false;
	
	local numScores = GetNumBattlefieldScores()  
	arenaTrackerWinner = GetBattlefieldWinner()
	if arenaTrackerWinner ~= nil then
		if (arenaTrackerWinner == 1 or arenaTrackerWinner == 0) and -- valid match
           numScores < 11 then -- not a battleground
			-- Time arena match lasted in ms.
			jnrMatchSeconds = GetBattlefieldInstanceRunTime() / 1000 
			local thedate = date("%Y-%m-%d").."T"..date("!%H:%M:%S")	
			arenaTrackerLeft = thedate

			--print("seconds: "..jnrMatchSeconds)
		
			-- Grab the glyphs used.
			if (arenaTrackerTalentsGlyphs == "") then		
				arenaTrackerDebug = arenaTrackerDebug.."|Getting gly"
				self:GetActiveTalentsGlyphs()
			end
						
			
			arenaTrackerDebug = arenaTrackerDebug.."|GotScoreUpdate "..numScores
			
			-- Clear out the variable and start over.			
			arenaTrackerCurrentScores = ",WINNING TEAM: "..arenaTrackerWinner		
				for i=1,numScores do		
					name, killingBlows, honorableKills, deaths, 
					honorGained, faction, race, class, classToken, 
					damageDone, healingDone, bgRating, ratingChange, 
					preMatchMMR, mmrChange, talentSpec = GetBattlefieldScore(i)					
					-- Update string with information
					arenaTrackerCurrentScores = arenaTrackerCurrentScores..",{{SCORE:"..name..","..killingBlows..","..honorableKills..","..
									deaths..","..honorGained..","..faction..","..race..","..class..","..
									classToken..","..damageDone..","..healingDone..","..bgRating..","..
									ratingChange..","..preMatchMMR..","..mmrChange..","..talentSpec.."}}"
					arenaTrackerDebug = arenaTrackerDebug.."|Score for: "..name
					
					if ratingChange ~= 0 then
						isArenaMatch = true;
					end
				end	
				
				-- If it's an arena match, get arena MMRs
				if isArenaMatch then
					arenaTrackerDebug = arenaTrackerDebug.."|IN ARENA" 
					arenaTrackerCurrentScores = arenaTrackerCurrentScores..",RATINGS:"
					for i=1,numScores do
						-- Indexed at zero for some reason.
						teamName,oldScore,newScore,teamMMR=GetBattlefieldTeamInfo(i-1) 
						if teamMMR ~= nil then
							arenaTrackerCurrentScores = arenaTrackerCurrentScores.."("..teamName..","..oldScore..","..newScore..","..teamMMR..")"
						end
					end
				else
					arenaTrackerDebug = arenaTrackerDebug.."|IN SKIRMISH" 
				end -- if it's an arena match
				
				-- This appears to not be firing if it's arena?  But ok in skirmish?
				arenaTrackerCurrentScores = arenaTrackerCurrentScores.."MATCHSECONDS:"..jnrMatchSeconds..","
			end -- End if the score is either 1 or zero.
		end -- End if the score isn't nil.
end


function ArenaTracker:GetActiveTalentsGlyphs()
	arenaTrackerDebug = arenaTrackerDebug.."|GetTalGly"	
	
	-- We only want to do this once, per fight.
	if arenaTrackerTalentsGlyphs == "" then		
		arenaTrackerTalentsGlyphs = "TALENTS:"		
		-- XXX BEGIN WoD compat
		local wod = select(4, GetBuildInfo()) >= 60000
		local GetTalentInfo = GetTalentInfo
		local MAX_NUM_TALENTS = MAX_NUM_TALENTS
		local MAX_NUM_TALENT_TIERS = MAX_NUM_TALENT_TIERS
		if wod then
			GetTalentInfo = function(index)
				local tier = ceil(index / 3)
				local column = (index - 1) % 3 + 1
				local id, name, iconTexture, selected, available = _G.GetTalentInfo(tier, column, GetActiveSpecGroup())
				return name, iconTexture, tier, column, selected, available, id
			end
			MAX_NUM_TALENTS = 21
			MAX_NUM_TALENT_TIERS = 7
		end
		-- XXX END WoD compat
		

		for i=1, MAX_NUM_TALENTS do
			local name, _, tier, _, selected = GetTalentInfo(i)
			if selected then						
				arenaTrackerTalentsGlyphs = arenaTrackerTalentsGlyphs..","..name
			end
		end

		arenaTrackerTalentsGlyphs = arenaTrackerTalentsGlyphs.." ETAL,GLYPHS:"
		for i = 1, NUM_GLYPH_SLOTS do
			local enabled, glyphType, glyphTooltipIndex, glyphSpellID, icon = GetGlyphSocketInfo(i)
			if ( enabled ) then
				local link = GetGlyphLink(i);-- Retrieves the Glyph's link ("" if no glyph in Socket)
				if ( link ~= "") then
				
					local glyphname3 = link:match("^.*%[(.*)%].*")										
					arenaTrackerTalentsGlyphs = arenaTrackerTalentsGlyphs..","..glyphname3
				else					
					arenaTrackerTalentsGlyphs = arenaTrackerTalentsGlyphs..",Empty Socket"
				end
			else				
				arenaTrackerTalentsGlyphs = arenaTrackerTalentsGlyphs..",Unavailable Socket"
			end
		end		
		arenaTrackerTalentsGlyphs = arenaTrackerTalentsGlyphs.." EGLY"
	end -- only want to grab talents/glyphs if we don't have them already.		
	return
end