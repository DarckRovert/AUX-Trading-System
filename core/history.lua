module 'aux.core.history'


--not using acecomm anymore
--[[AuxAddon = AceLibrary("AceAddon-2.0"):new("AceComm-2.0")   --im unsure this is done correctly but seems to work lol

local commPrefix = "AuxAddon";
AuxAddon:SetCommPrefix(commPrefix)

function AuxAddon:OnEnable()
	--self:RegisterComm(commPrefix, "GROUP", "OnCommReceive"); --for testing purposes, not really useful in real world I think
	self:RegisterComm(commPrefix, "GUILD", "OnCommReceive");
	--self:RegisterComm(commPrefix, "ZONE", "OnCommReceive");
end ]]--

local T = require 'T'
local aux = require 'aux'

local persistence = require 'aux.util.persistence'

local history_schema = {'tuple', '#', {next_push='number'}, {daily_min_buyout='number'}, {data_points={'list', ';', {'tuple', '@', {value='number'}, {time='number'}}}}}

local value_cache = {}

function aux.handle.LOAD2()
	data = aux.faction_data.history
	local _, name = GetChannelName("LFT")
	if aux.account_data and aux.account_data.sharing and not name then
		aux.thread(aux.when, aux.later(5), function()
			local shouldJoin = true
			for i, channel in ipairs({GetChannelList()}) do
				if channel == "LFT" then
					shouldJoin = false
					break
				end
			end
			if shouldJoin then
				JoinChannelByName("LFT")
			end
		end)
	end
end

do
	local next_push = 0
	function get_next_push()
		if time() > next_push then
			local date = date('*t')
			date.hour, date.min, date.sec = 24, 0, 0
			next_push = time(date)
		end
		return next_push
	end
end

function new_record()
	return T.temp-T.map('next_push', get_next_push(), 'data_points', T.acquire())
end

function read_record(item_key)
	local record = data[item_key] and persistence.read(history_schema, data[item_key]) or new_record()
	if record.next_push <= time() then
		push_record(record)
		write_record(item_key, record)
	end
	return record
end

function write_record(item_key, record)
	data[item_key] = persistence.write(history_schema, record)
	if value_cache[item_key] then
		T.release(value_cache[item_key])
		value_cache[item_key] = nil
	end
end

local data_sharer = CreateFrame("Frame", "aux_data_sharer")
data_sharer:RegisterEvent("CHAT_MSG_CHANNEL")

data_sharer:SetScript("OnEvent", function()
	if not aux.account_data or not aux.account_data.sharing then return end
	if arg2 == UnitName("player") then return end
	if strupper(arg9) ~= "LFT" then return end

	local _, _, item_key, munit_buyout_price = strfind(arg1 or "", "^AuxData,(.*),(.*)$") -- using , as a seperator because item_key contains a :

	if not item_key then return end

	local unit_buyout_price = tonumber(munit_buyout_price) or 0
	local item_record = read_record(item_key)

	if unit_buyout_price > 0 and unit_buyout_price < (item_record.daily_min_buyout or aux.huge) then
		item_record.daily_min_buyout = unit_buyout_price
		write_record(item_key, item_record)
	end
	-- print(arg1)
end)

function M.process_auction(auction_record, pages)
	local item_record = read_record(auction_record.item_key)
	local unit_buyout_price = ceil(auction_record.buyout_price / auction_record.aux_quantity)
	local item_key = auction_record.item_key
	if unit_buyout_price > 0 and unit_buyout_price < (item_record.daily_min_buyout or aux.huge) then
		item_record.daily_min_buyout = unit_buyout_price
		write_record(auction_record.item_key, item_record)
		--AuxAddon:SendCommMessage("GUILD", item_key, unit_buyout_price) relies on acecomm
		if aux.account_data.sharing == true then
			if (tonumber(pages) or 0) < 15 then --to avoid sharing data when people do searches without a keyword "full scans"
				if GetChannelName("LFT") ~= 0 then
					ChatThrottleLib:SendChatMessage("BULK", nil, "AuxData," .. item_key .."," .. unit_buyout_price , "CHANNEL", nil, GetChannelName("LFT")) --ChatThrottleLib fixed for turtle by Candor https://github.com/trumpetx/ChatLootBidder/blob/master/ChatThrottleLib.lua
				  	--print("sent")
				end
		 	end
		end
	end
end

--[[ function AuxAddon:OnCommReceive(prefix, sender, distribution, item_key, unit_buyout_price) --copied code from process_auction. <- code for when using acecomm
	print("received data"); --for testing (print comes from PFUI)
	local item_record = read_record(item_key)
	if unit_buyout_price > 0 and unit_buyout_price < (item_record.daily_min_buyout or aux.huge) then
		item_record.daily_min_buyout = unit_buyout_price
		write_record(item_key, item_record)
		--print("wrote data"); --for testing (print comes from PFUI)
	end
end ]]--

function M.data_points(item_key)
	return read_record(item_key).data_points
end

function M.value(item_key)
	if not value_cache[item_key] or value_cache[item_key].next_push <= time() then
		local item_record, value
		item_record = read_record(item_key)
		if getn(item_record.data_points) > 0 then
			local total_weight, weighted_values = 0, T.temp-T.acquire()
			for _, data_point in item_record.data_points do
				local weight = .99 ^ aux.round((item_record.data_points[1].time - data_point.time) / (60 * 60 * 24))
				total_weight = total_weight + weight
				tinsert(weighted_values, T.map('value', data_point.value, 'weight', weight))
			end
			for _, weighted_value in weighted_values do
				weighted_value.weight = weighted_value.weight / total_weight
			end
			value = weighted_median(weighted_values)
		else
			value = item_record.daily_min_buyout
		end
		value_cache[item_key] = T.map('value', value, 'next_push', item_record.next_push)
	end
	return value_cache[item_key].value
end

function M.market_value(item_key)
	return read_record(item_key).daily_min_buyout
end

function weighted_median(list)
	sort(list, function(a,b) return a.value < b.value end)
	local weight = 0
	for _, v in ipairs(list) do
		weight = weight + v.weight
		if weight >= .5 then
			return v.value
		end
	end
end

function push_record(item_record)
	if item_record.daily_min_buyout then
		tinsert(item_record.data_points, 1, T.map('value', item_record.daily_min_buyout, 'time', item_record.next_push))
		while getn(item_record.data_points) > 11 do
			T.release(item_record.data_points[getn(item_record.data_points)])
			tremove(item_record.data_points)
		end
	end
	item_record.next_push, item_record.daily_min_buyout = get_next_push(), nil
end