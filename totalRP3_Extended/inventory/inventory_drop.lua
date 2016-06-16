----------------------------------------------------------------------------------
-- Total RP 3: Exchange system
--	---------------------------------------------------------------------------
--	Copyright 2016 Sylvain Cossement (telkostrasz@totalrp3.info)
--
--	Licensed under the Apache License, Version 2.0 (the "License");
--	you may not use this file except in compliance with the License.
--	You may obtain a copy of the License at
--
--		http://www.apache.org/licenses/LICENSE-2.0
--
--	Unless required by applicable law or agreed to in writing, software
--	distributed under the License is distributed on an "AS IS" BASIS,
--	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--	See the License for the specific language governing permissions and
--	limitations under the License.
----------------------------------------------------------------------------------
local Globals, Events, Utils = TRP3_API.globals, TRP3_API.events, TRP3_API.utils;
local Comm = TRP3_API.communication;
local tinsert, assert, strsplit, tostring, wipe, pairs, sqrt = tinsert, assert, strsplit, tostring, wipe, pairs, sqrt;
local getClass, isContainerByClassID, isUsableByClass = TRP3_API.extended.getClass, TRP3_API.inventory.isContainerByClassID, TRP3_API.inventory.isUsableByClass;
local UnitPosition, SetMapToCurrentZone, GetCurrentMapAreaID, GetPlayerMapPosition = UnitPosition, SetMapToCurrentZone, GetCurrentMapAreaID, GetPlayerMapPosition;
local loc = TRP3_API.locale.getText;

local dropFrame = TRP3_DropSearchFrame;
local dropData;

--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-- Drop
--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

function TRP3_API.inventory.dropItem(container, slotID, initialSlotInfo)
	if slotID and container and isContainerByClassID(container.id) and container.content[slotID] then
		local slotInfo = container.content[slotID];
		-- Check that nothing has changed
		if slotInfo == initialSlotInfo then

			-- Proper coordinates
			local posY, posX, posZ, instanceID = UnitPosition("player");

			-- We still need map position for potential marker placement
			SetMapToCurrentZone();
			local mapID = GetCurrentMapAreaID();
			local mapX, mapY = GetPlayerMapPosition("player");

			-- Pack the data
			local groundData = {
				posY = posY,
				posX = posX,
				posZ = posZ,
				instanceID = instanceID,
				mapID = mapID,
				mapX = mapX,
				mapY = mapY,
				item = {}
			};
			Utils.table.copy(groundData.item, slotInfo);
			tinsert(dropData, groundData);

			-- Remove from inv
			TRP3_API.inventory.removeSlotContent(container, slotID, initialSlotInfo);
		end
	end
end

--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-- Scan
--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

local function initScans()
	TRP3_API.map.registerScan({
		id = "inv_scan_self",
		buttonText = "Scan for my items",
		scanTitle = "Item(s)",
		scan = function(saveStructure)
			local mapID = GetCurrentMapAreaID();
			for index, drop in pairs(dropData) do
				if drop.mapID == mapID then
					saveStructure[index] = { x = drop.mapX or 0, y = drop.mapY or 0};
				end
			end
		end,
		canScan = function()
			return true;
		end,
		scanMarkerDecorator = function(index, entry, marker)
			local drop = dropData[index];
			local item = getClass(drop.item.id);
			marker.scanLine = TRP3_API.inventory.getItemLink(item) .. " x" .. (drop.item.count or 1);
		end,
	});
end

--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-- Loot
--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

local MAX_SEARCH_DISTANCE = 15;
local searchForItems;

local function isInRadius(maxDistance, posY, posX, myPosY, myPosX)
	local distance = sqrt((posY - myPosY) ^ 2 + (posX - myPosX) ^ 2);
	return distance <= maxDistance, distance;
end

local function onLooted(itemData, count)
	for index, drop in pairs(dropData) do
		if drop.item == itemData then
			drop.item.count = (drop.item.count or 1) - count;
			if drop.item.count <= 0 then
				wipe(dropData[index]);
				dropData[index] = nil;
			end
		end
	end
end

function searchForItems()
	-- Proper coordinates
	local posY, posX, _, instanceID = UnitPosition("player");

	local searchResults = {};
	for _, drop in pairs(dropData) do
		if instanceID == drop.instanceID then
			local isInRadius, distance = isInRadius(MAX_SEARCH_DISTANCE, posY, posX, drop.posY or 0, drop.posX or 0);
			if isInRadius then
				-- Show loot
				tinsert(searchResults, drop);
			end
		end
	end

	if #searchResults > 0 then
		local loot = {
			IT = {},
			BA = {
				IC = "icon_treasuremap",
				NA = loc("DR_SEARCH_BUTTON")
			}
		}
		for index, result in pairs(searchResults) do
			loot.IT[tostring(index)] = result.item;
		end
		TRP3_API.inventory.presentLoot(loot, onLooted);
	else
		Utils.message.displayMessage(loc("DR_NOTHING"));
	end
end

--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-- INIT
--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

function dropFrame.init()
	-- Init data
	if not TRP3_Drop then
		TRP3_Drop = {};
	end
	dropData = TRP3_Drop;

	initScans();

	-- UI
	-- Button on toolbar
	TRP3_API.events.listenToEvent(TRP3_API.events.WORKFLOW_ON_LOADED, function()
		if TRP3_API.toolbar then
			local toolbarButton = {
				id = "bb_extended_drop",
				icon = "icon_treasuremap",
				configText = loc("DR_SEARCH_BUTTON"),
				tooltip = loc("DR_SEARCH_BUTTON"),
				tooltipSub = loc("DR_SEARCH_BUTTON_TT"),
				onClick = function()
					searchForItems();
				end,
				visible = 1
			};
			TRP3_API.toolbar.toolbarAddButton(toolbarButton);
		end
	end);

end