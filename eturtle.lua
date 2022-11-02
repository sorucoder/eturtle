local expect = require("cc.expect")

local function roundToNearestInterval(value, interval)
	local valueDown, valueUp = math.floor(value / interval) * interval, math.ceil(value / interval) * interval
	local differenceDown, differenceUp = value - valueDown, valueUp - value
	if differenceDown < differenceUp then
		return valueDown
	else
		return valueUp
	end
end

local eturtle = {} do
    --[[ Turtle State Variables ]]--
	local position, bearing, equipment = nil, nil, nil
	
	--[[ Debugging Variables and Functions ]]--
	local function defaultPrintHook(format, ...)
		print(string.format(format, ...))
	end
	local function defaultErrorHook(format, ...)
		printError(string.format(format, ...))
	end
	local debug, debugPrintHook, debugErrorHook = false, defaultPrintHook, defaultErrorHook
	local function debugPrint(format, ...)
		if debug then
			debugPrintHook(format, ...)
		end
	end
	local function debugError(format, ...)
		if debug then
			debugErrorHook(format, ...)
		end
	end

    --[[ Bearing Constants ]]--
    eturtle.SOUTH   = 0.0 * math.pi
    eturtle.WEST    = 0.5 * math.pi
    eturtle.NORTH   = 1.0 * math.pi
    eturtle.EAST    = 1.5 * math.pi

    --[[ Settings ]]--
    settings.define("eturtle.statefile", {description = "The path in which to store the turtle's state.", default = ".turtle", type = "string"})

    --[[ Calibration and Configuration Methods ]]--
	local function equipWirelessModem()
		debugPrint("searching for wireless modem...")
		local modemInEquipment, modemInInventory = nil, nil
		for slot = 1, 16 do
			local itemCount = turtle.getItemCount(slot)
			if modemInEquipment == nil and itemCount == 0 then
				turtle.select(slot)
				debugPrint("found empty slot (#%d) to search equipment", slot)

				if turtle.equipLeft() then
					local item = turtle.getItemDetail()
					if item and item.name:match("^computercraft:[%a_]*wireless_modem$") then
						modemInEquipment = true
						turtle.equipLeft()
						debugPrint("found wireless modem (%s) in left equipment", item.name)
						return true, "equipment.left"
					end
					turtle.equipLeft()
				end

				if turtle.equipRight() then
					local item = turtle.getItemDetail()
					if item and item.name:match("^computercraft:[%a_]*wireless_modem$") then
						modemInEquipment = true
						turtle.equipRight()
						debugPrint("found wireless modem (%s) in right equipment", item.name)
						return true, "equipment.right"
					end
					turtle.equipRight()
				end
			elseif itemCount ~= 0 then
				local item = turtle.getItemDetail()
				if item and item.name:match("^computercraft:[%a_]*wireless_modem$") then
					modemInInventory = true
					turtle.select(slot)
					turtle.equipLeft()
					debugPrint("found wireless modem (%s) in slot #%d", item.name, slot)
					return true, string.format("inventory[%d]", slot)
				end
			end
		end

		debugError("no wireless modem found")
		return false
	end

    function eturtle.calibrateEquipment(manualLeft, manualRight)
		-- Check arguments.
		do
			expect(1, manualLeft, "nil", "string")
		end
		do
			expect(2, manualRight, "nil", "string")
		end
		
		local currentSlot = turtle.getSelectedSlot()
		debugPrint("calibrating equipment...")

		-- Check for empty slot.
		-- Unequip, analyze, then equip each side.
		debugPrint("finding empty slot to analyze equipment...")
		for slot = 1, 16 do
			if turtle.getItemCount(slot) == 0 then
				turtle.select(slot)
				debugPrint("found empty slot (#%d)", slot)

				equipment = {}
				
				if turtle.equipLeft() then
					local item = turtle.getItemDetail()
					equipment.left = item and item.name
					turtle.equipLeft()
				end
				debugPrint("got left equipment (%s)", equipment.left or "<nothing>")

				if turtle.equipRight() then
					local item = turtle.getItemDetail()
					equipment.right = item and item.name
					turtle.equipRight()
				end
				debugPrint("got right equipment (%s)", equipment.right or "<nothing>")

				turtle.select(currentSlot)
				return true
			end
		end
		debugError("no empty slot")

		equipment = {left = manualLeft, right = manualRight}
		debugError("set equipment defaults (%s and %s)", manualLeft or "<nothing>", manualRight or "<nothing>")
		return false
    end

    function eturtle.calibratePosition(manualX, manualY, manualZ)
		-- Check arguments.
        do
			if manualX == nil then manualX = 0 end
			expect(1, manualX, "number")
			expect.range(manualX, -3e7, 3e7)
		end
		do
			if manualY == nil then manualY = 0 end
			expect(2, manualY, "number")
			expect.range(manualY, -3e7, 3e7)
		end
		do
			if manualZ == nil then manualZ = 0 end
			expect(3, manualZ, "number")
			expect.range(manualZ, -3e7, 3e7)
		end
		
		local currentSlot = turtle.getSelectedSlot()
		debugPrint("calibrating position...")

		-- Get the position using GPS if available.
		local modemAvailable, modemSource = equipWirelessModem()
		if modemAvailable then
			debugPrint("using GPS to get position...")
			local x, y, z = gps.locate(nil, debug)

			if x then
				debugPrint("got position (<%d,%d,%d>)", x, y, z)
				position = vector.new(x, y, z)

				---@diagnostic disable-next-line: need-check-nil
				if modemSource:match("^inventory%[%d+%]$") then
					turtle.equipLeft()
					turtle.select(currentSlot)
					debugPrint("unequipped wireless modem")
				end

				return true
			else debugError("GPS is unavailable") end
		end

		position = vector.new(manualX, manualY, manualZ)
		debugError("set position default (<%d,%d,%d>)", manualX, manualY, manualZ)
		return false
    end

    function eturtle.calibrateBearing(manualBearing)
		do
			if manualBearing == nil then manualBearing = eturtle.SOUTH end
			expect(1, manualBearing, "number")
			expect.range(manualBearing, 0.0 * math.pi, 2.0 * math.pi)
			manualBearing = roundToNearestInterval(manualBearing, 0.5 * math.pi)
		end

		local currentSlot = turtle.getSelectedSlot()
		debugPrint("calibrating bearing...")
		
		debugPrint("checking fuel level...")
		local currentFuelLevel = turtle.getFuelLimit() == "unlimited" and math.huge or turtle.getFuelLevel()

		if currentFuelLevel >= 2 then
			debugPrint("fuel level is sufficient (%s)", currentFuelLevel < math.huge and tostring(currentFuelLevel) or "+infinity")

			local modemAvailable, modemSource = equipWirelessModem()
			if modemAvailable then
				debugPrint("using GPS to get starting position...")
				local x0, y0, z0 = gps.locate(nil, debug)
				if x0 then
					debugPrint("got starting position (<%d,%d,%d>)", x0, y0, z0)

					debugPrint("moving to induce a displacement...")
					local movement = nil
					if turtle.forward() then
						debugPrint("moved forward parallel to current bearing")
						movement = "parallel-forward"
					elseif turtle.back() then
						debugPrint("moved backward parallel to current bearing")
						movement = "parallel-backward"
					else
						turtle.turnLeft()
						if turtle.forward() then
							debugPrint("moved forward perpendicular to current bearing")
							movement = "perpendicular-forward"
						elseif turtle.back() then
							debugPrint("moved forward perpendicular to current bearing")
							movement = "perpendicular-backward"
						else
							turtle.turnRight()
						end
					end

					if movement then
						debugPrint("using GPS to get ending position...")
						local x1, y1, z1 = gps.locate(nil, debug)
						if x1 then
							debugPrint("got ending position (<%d,%d,%d>)", x1, y1, z1)
							if movement == "parallel-forward" then
								bearing = math.atan2(x0 - x1, z1 - z0) % (2.0 * math.pi)
								debugPrint("got bearing (%01.1fpi)", bearing / math.pi)
							elseif movement == "parallel-backward" then
								bearing = math.atan2(x1 - x0, z0 - z1) % (2.0 * math.pi)
								debugPrint("got bearing (%01.1fpi)", bearing / math.pi)
							elseif movement == "perpendicular-forward" then
								bearing = math.atan2(z0 - z1, x1 - x0) % (2.0 * math.pi)
								debugPrint("got bearing (%01.1fpi)", bearing / math.pi)
							elseif movement == "perpendicular-backward" then
								bearing = math.atan2(z1 - z0, x0 - x1) % (2.0 * math.pi)
								debugPrint("got bearing (%01.1fpi)", bearing / math.pi)
							end
						else debugError("GPS not available") end
					else debugError("completely surrounded") end

					---@diagnostic disable-next-line: need-check-nil
					if modemSource:match("^inventory%[%d+%]$") then
						turtle.equipLeft()
						turtle.select(currentSlot)
						debugPrint("unequipping wireless modem")
					end

					if movement then
						debugPrint("moving to original position...")
						if movement == "parallel-forward" then
							if not turtle.back() then error("obstruction during displacement", 0) end
							debugPrint("moved backward parallel to current bearing")
						elseif movement == "parallel-backward" then
							if not turtle.forward() then error("obstruction during displacement", 0) end
							debugPrint("moved forward parallel to current bearing")
						elseif movement == "perpendicular-forward" then
							if not turtle.back() then error("obstruction during displacement", 0) end
							turtle.turnRight()
							debugPrint("moved backward perpendicular to current bearing")
						elseif movement == "perpendicular-backward" then
							if not turtle.forward() then error("obstruction during displacement", 0) end
							turtle.turnRight()
							debugPrint("moved forward perpendicular to current bearing")
						end
					end
				else debugError("GPS not available") end
			end
		else debugError("not enough fuel") end
		
		bearing = manualBearing
		debugError("set bearing default (%1.1f)", manualBearing)
		return false
    end

	function eturtle.calibrate(manualPosition, manualBearing, manualEquipment)
		-- Coalesce default argument values.
		if manualPosition == nil then manualPosition = vector.new(0, 0, 0) end
		if manualBearing == nil then manualBearing = eturtle.SOUTH end
		if manualEquipment == nil then manualEquipment = {} end

		debugPrint("calibrating turtle...")
		return eturtle.calibratePosition(manualPosition.x, manualPosition.y, manualPosition.z), eturtle.calibrateBearing(manualBearing), eturtle.calibrateEquipment(equipment.left, equipment.right)
	end

	function eturtle.enableDebugging(printHook, errorHook)
		do
			if printHook == nil then printHook = defaultPrintHook end
			expect(1, printHook, "function")
		end
		do
			if errorHook == nil then errorHook = defaultErrorHook end
			expect(2, errorHook, "function")
		end

		debug = true
		debugPrintHook = printHook
		debugErrorHook = errorHook
	end

	function eturtle.disableDebugging()
		debug = false
	end

    --[[ Introspection Methods ]]--
    function eturtle.getPosition()
        return vector.new(position.x, position.y, position.z)
    end

    function eturtle.getBearing()
        return bearing
    end

    function eturtle.getEquipment()
        return {left = equipment.left, right = equipment.right}
    end

    function eturtle.getSelectedSlot()
        return turtle.getSelectedSlot()
    end

    function eturtle.getFuelLevel()
        if turtle.getFuelLimit() == "unlimited" then
			return math.huge
		end
		return turtle.getFuelLevel()
    end

	function eturtle.getFuelLimit()
		if turtle.getFuelLimit() == "unlimited" then
			return math.huge
		end
		return turtle.getFuelLimit()
	end
end return eturtle
