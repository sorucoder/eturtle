local expect = require("cc.expect")
local pretty = require("cc.pretty")

local function roundNearestInterval(value, interval)
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
	local function defaultPrintHook(message)
		print(message)
	end
	local function defaultErrorHook(message)
		printError(message)
	end
	local debug, debugPrintHook, debugErrorHook = false, defaultPrintHook, defaultErrorHook
	local function debugPrint(format, ...)
		if debug then
			local message = string.format(format, ...)
			debugPrintHook(message)
		end
	end
	local function debugError(format, ...)
		if debug then
			local message = string.format(format, ...)
			debugErrorHook(message)
		end
	end

    --[[ Bearing Constants ]]--
    eturtle.SOUTH   = 0.0 * math.pi
    eturtle.WEST    = 0.5 * math.pi
    eturtle.NORTH   = 1.0 * math.pi
    eturtle.EAST    = 1.5 * math.pi

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
			manualBearing = roundNearestInterval(manualBearing, 0.5 * math.pi)
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

		local positionCalibrationSuccess = eturtle.calibratePosition(manualPosition.x, manualPosition.y, manualPosition.z)
		local bearingCalibrationSuccess = eturtle.calibrateBearing(manualBearing)
		local equipmentCalibrationSuccess = eturtle.calibrateEquipment()

		return positionCalibrationSuccess and bearingCalibrationSuccess and equipmentCalibrationSuccess, positionCalibrationSuccess, bearingCalibrationSuccess, equipmentCalibrationSuccess
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

	--[[ Persistence Methods ]]--
	function eturtle.saveState(path)
		do
			expect(1, path, "string")
		end

		debugPrint("saving turtle state...")

		if position == nil then
			debugError("position has not been calibrated")
			return false
		end

		if bearing == nil then
			debugError("bearing has not been calibrated")
			return false
		end

		if equipment == nil then
			debugError("equipment has not been calibrated")
			return false
		end

		debugPrint("opening state file for writing...")
		local file, fileError = fs.open(path, "wb")
		if file then
			local signatureBytes = "ETS"
			file.write(signatureBytes)
			debugPrint("wrote file signature (%s)", signatureBytes)
			
			local positionBytes = string.pack("lll", position.x, position.y, position.z)
			file.write(positionBytes)
			debugPrint("wrote position bytes (<%d,%d,%d> -> %s)", position.x, position.y, position.z, pretty.pretty(positionBytes))

			local bearingBytes = string.pack("d", bearing)
			file.write(bearingBytes)
			debugPrint("wrote bearing bytes (%f -> %s)", bearing, pretty.pretty(bearingBytes))

			local equipmentBytes = string.pack("s1s1", equipment.left or "", equipment.right or "")
			file.write(equipmentBytes)
			debugPrint("wrote equipment bytes (%s,%s -> %s)", equipment.left or "<nothing>", equipment.right or "<nothing>", pretty.pretty(equipmentBytes))

			file.flush()
			file.close()
			debugPrint("wrote to disk")
			return true
		end

		debugError("could not open state file for writing (%s)", fileError)
		return false
	end

	function eturtle.loadState(path)
		do
			expect(1, path, "string")
		end

		debugPrint("loading turtle state...")

		debugPrint("opening state file for reading...")
		local file, fileError = fs.open(path, "rb")
		if file then
			local signatureBytes = file.read(3)
			if signatureBytes == "ETS" then
				debugPrint("file signature matched")

				local positionBytes = file.read(string.packsize("lll"))
				position = vector.new(string.unpack("lll", positionBytes))
				debugPrint("read position bytes (%s -> <%d,%d,%d>)", pretty.pretty(positionBytes), position.x, position.y, position.z)
				
				local bearingBytes = file.read(string.packsize("d"))
				bearing = string.unpack("d", bearingBytes)
				debugPrint("read bearing bytes (%s -> %f)", pretty.pretty(bearingBytes), bearing)

				local equipmentBytes = "" do
					equipment = {}
					
					local leftEquipmentBytesCount = file.read()
					if leftEquipmentBytesCount > 0 then
						local leftEquipment = file.read(leftEquipmentBytesCount)
						equipment.left = leftEquipment
						equipmentBytes = equipmentBytes .. string.pack("s1", leftEquipment)
					else
						equipmentBytes = equipmentBytes .. "\000"
					end

					local rightEquipmentBytesCount = file.read()
					if rightEquipmentBytesCount > 0 then
						local rightEquipment = file.read(rightEquipmentBytesCount)
						equipment.right = rightEquipment
						equipmentBytes = equipmentBytes .. string.pack("s1", rightEquipment)
					else
						equipmentBytes = equipmentBytes .. "\000"
					end
				end
				debugPrint("read equipment bytes (%s -> %s,%s)", pretty.pretty(equipmentBytes), equipment.left or "<nothing>", equipment.right or "nothing")

				return true
			end

			debugError("state file did not match signature (%s ~= ETS)", pretty.pretty(signatureBytes), )
			return false
		end

		debugError("could not open state file for reading (%s)", fileError)
		return false
	end
end return eturtle
