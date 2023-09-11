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
	local state
    local logging
    local fueling

    --[[ Bearing Constants ]]--
    eturtle.SOUTH   = 0.0 * math.pi
    eturtle.WEST    = 0.5 * math.pi
    eturtle.NORTH   = 1.0 * math.pi
    eturtle.EAST    = 1.5 * math.pi

    --[[ Default Variables and Functions ]]--
    local defaultStateAutomatic = false
    local defaultStatePosition = nil
    local defaultStateBearing = nil
    local defaultStateEquipment = nil
    state = {
        automatic = defaultStateAutomatic,
        position = defaultStatePosition,
        bearing = defaultStateBearing,
        equipment = defaultStateEquipment,
    }

    fueling = {
        registry = {
            items = {
                ["minecraft:lava_bucket"] = 1000,
                ["minecraft:coal_block"] = 800,
                ["minecraft:dried_kelp_block"] = 200,
                ["minecraft:blaze_rod"] = 120,
                ["minecraft:bamboo_mosaic"] = 15,
                ["minecraft:bamboo_mosaic_stairs"] = 15,
                ["minecraft:chiseled_bookshelf"] = 15,
                ["minecraft:bee_nest"] = 15,
                ["minecraft:beehive"] = 15,
                ["minecraft:ladder"] = 15,
                ["minecraft:crafting_table"] = 15,
                ["minecraft:cartography_table"] = 15,
                ["minecraft:fletching_table"] = 15,
                ["minecraft:smithing_table"] = 15,
                ["minecraft:loom"] = 15,
                ["minecraft:bookshelf"] = 15,
                ["minecraft:lectern"] = 15,
                ["minecraft:composter"] = 15,
                ["minecraft:chest"] = 15,
                ["minecraft:trapped_chest"] = 15,
                ["minecraft:barrel"] = 15,
                ["minecraft:daylight_detector"] = 15,
                ["minecraft:jukebox"] = 15,
                ["minecraft:note_block"] = 15,
                ["minecraft:crossbow"] = 15,
                ["minecraft:bow"] = 15,
                ["minecraft:fishing_rod"] = 15,
                ["minecraft:hanging_sign"] = 10,
                ["minecraft:wooden_pickaxe"] = 10,
                ["minecraft:wooden_hoe"] = 10,
                ["minecraft:wooden_axe"] = 10,
                ["minecraft:wooden_sword"] = 10,
                ["minecraft:bowl"] = 5,
                ["minecraft:bamboo_mosaic_slab"] = 7,
                ["minecraft:stick"] = 5,
                ["minecraft:dead_bush"] = 5,
                ["minecraft:azalea"] = 5,
                ["minecraft:bamboo"] = 2,
                ["minecraft:scaffolding"] = 2,
            },
            tags = {
                ["minecraft:coals"] = 80,
                ["minecraft:boats"] = 60,
                ["minecraft:chest_boats"] = 60,
                ["minecraft:bamboo_blocks"] = 15,
                ["minecraft:logs"] = 15,
                ["minecraft:planks"] = 15,
                ["minecraft:wooden_pressure_plates"] = 15,
                ["minecraft:wooden_trapdoors"] = 15,
                ["forge:fence_gates/wooden"] = 15,
                ["minecraft:wooden_fences"] = 15,
                ["minecraft:banners"] = 15,
                ["minecraft:wooden_doors"] = 10,
                ["minecraft:wooden_slabs"] = 7,
                ["minecraft:wooden_buttons"] = 5,
                ["minecraft:signs"] = 10,
                ["minecraft:saplings"] = 10,
                ["minecraft:wool"] = 5,
            }
        }
    }
    
    local defaultLoggingEnabled = false
	local function defaultPrintHook(message)
		print(message)
	end
	local function defaultErrorHook(message)
		printError(message)
	end
    logging = {
        enabled = defaultLoggingEnabled,
        hooks = {
            print = defaultPrintHook,
            error = defaultErrorHook
        }
    }
	function logging.print(format, ...)
		if logging.enabled then
			local message = string.format(format, ...)
			logging.hooks.print(message)
		end
	end
	function logging.error(format, ...)
		if logging.enabled then
			local message = string.format(format, ...)
			logging.hooks.error(message)
		end
	end

    --[[ Calibration and Configuration Methods ]]--
	local function equipWirelessModem()
		logging.print("searching for wireless modem...")

		local modemInEquipment, modemInInventory = nil, nil
		for slot = 1, 16 do
			local itemCount = turtle.getItemCount(slot)
			if modemInEquipment == nil and itemCount == 0 then
				turtle.select(slot)
				logging.print("found empty slot (#%d) to search equipment", slot)

				if turtle.equipLeft() then
					local item = turtle.getItemDetail()
					if item and item.name:match("^computercraft:[%a_]*wireless_modem$") then
						modemInEquipment = true
						turtle.equipLeft()
						logging.print("found wireless modem (%s) in left equipment", item.name)
						return true, "equipment.left"
					end
					turtle.equipLeft()
				end

				if turtle.equipRight() then
					local item = turtle.getItemDetail()
					if item and item.name:match("^computercraft:[%a_]*wireless_modem$") then
						modemInEquipment = true
						turtle.equipRight()
						logging.print("found wireless modem (%s) in right equipment", item.name)
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
					logging.print("found wireless modem (%s) in slot #%d", item.name, slot)
					return true, string.format("inventory[%d]", slot)
				end
			end
		end

		logging.error("no wireless modem found")
		return false
	end

    function eturtle.calibrateEquipment(manualLeft, manualRight)
		do
			expect(1, manualLeft, "nil", "string")
		end
		do
			expect(2, manualRight, "nil", "string")
		end
		
		logging.print("calibrating equipment...")

        
		-- Check for empty slot.
		-- Unequip, analyze, then equip each side.
		local currentSlot = eturtle.getSelectedSlot()
		logging.print("finding empty slot to analyze equipment...")
		for slot = 1, 16 do
			if turtle.getItemCount(slot) == 0 then
				turtle.select(slot)
				logging.print("found empty slot (#%d)", slot)

				state.equipment = {}
				
				if turtle.equipLeft() then
					local item = turtle.getItemDetail()
					state.equipment.left = item and item.name
					turtle.equipLeft()
				end
				logging.print("got left equipment (%s)", state.equipment.left or "<nothing>")

				if turtle.equipRight() then
					local item = turtle.getItemDetail()
					state.equipment.right = item and item.name
					turtle.equipRight()
				end
				logging.print("got right equipment (%s)", state.equipment.right or "<nothing>")

				turtle.select(currentSlot)
				return true
			end
		end
		logging.error("no empty slot")

		state.equipment = {left = manualLeft, right = manualRight}
		logging.error("set equipment defaults (left %s and right %s)", manualLeft or "<nothing>", manualRight or "<nothing>")
		return false
    end

    function eturtle.calibratePosition(manualX, manualY, manualZ)
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
		
		logging.print("calibrating position...")
        
		-- Get the position using GPS if available.
		local currentSlot = eturtle.getSelectedSlot()
		local modemAvailable, modemSource = equipWirelessModem()
		if modemAvailable then
			logging.print("using GPS to get position...")
			local x, y, z = gps.locate(nil, logging.enabled)

			if x then
				logging.print("got position (<%d,%d,%d>)", x, y, z)
				state.position = vector.new(x, y, z)

				---@diagnostic disable-next-line: need-check-nil
				if modemSource:match("^inventory%[%d+%]$") then
					turtle.equipLeft()
					turtle.select(currentSlot)
					logging.print("unequipped wireless modem")
				end

				return true
			else logging.error("GPS is unavailable") end
		end

		state.position = vector.new(manualX, manualY, manualZ)
		logging.error("set position default (<%d,%d,%d>)", manualX, manualY, manualZ)
		return false
    end

    function eturtle.calibrateBearing(manualBearing)
		do
			if manualBearing == nil then manualBearing = eturtle.SOUTH end
			expect(1, manualBearing, "number")
			expect.range(manualBearing, 0.0 * math.pi, 2.0 * math.pi)
			manualBearing = roundNearestInterval(manualBearing, 0.5 * math.pi)
		end

		logging.print("calibrating bearing...")
		
        -- Calibrate bearing by using GPS, then moving to induce a displacment.
        local currentSlot = eturtle.getSelectedSlot()
		logging.print("checking fuel level...")
		local currentFuelLevel = turtle.getFuelLimit() == "unlimited" and math.huge or turtle.getFuelLevel()
		if currentFuelLevel >= 2 then
			local modemAvailable, modemSource = equipWirelessModem()
			if modemAvailable then
				logging.print("using GPS to get starting position...")
				local x0, y0, z0 = gps.locate(nil, logging.enabled)
				if x0 then
					logging.print("got starting position (<%d,%d,%d>)", x0, y0, z0)

					logging.print("moving to induce a displacement...")
					local movement = nil
					if turtle.forward() then
						logging.print("moved forward parallel to current bearing")
						movement = "parallel-forward"
					elseif turtle.back() then
						logging.print("moved backward parallel to current bearing")
						movement = "parallel-backward"
					else
						turtle.turnLeft()
						if turtle.forward() then
							logging.print("moved forward perpendicular to current bearing")
							movement = "perpendicular-forward"
						elseif turtle.back() then
							logging.print("moved forward perpendicular to current bearing")
							movement = "perpendicular-backward"
						else
							turtle.turnRight()
						end
					end

					if movement then
						logging.print("using GPS to get ending position...")
						local x1, y1, z1 = gps.locate(nil, logging.enabled)
						if x1 then
							logging.print("got ending position (<%d,%d,%d>)", x1, y1, z1)
							if movement == "parallel-forward" then
								state.bearing = math.atan2(x0 - x1, z1 - z0) % (2.0 * math.pi)
								logging.print("got bearing (%01.2frad)", state.bearing)
							elseif movement == "parallel-backward" then
								state.bearing = math.atan2(x1 - x0, z0 - z1) % (2.0 * math.pi)
								logging.print("got bearing (%01.2frad)", state.bearing)
							elseif movement == "perpendicular-forward" then
								state.bearing = math.atan2(z0 - z1, x1 - x0) % (2.0 * math.pi)
								logging.print("got bearing (%01.2frad)", state.bearing)
							elseif movement == "perpendicular-backward" then
								state.bearing = math.atan2(z1 - z0, x0 - x1) % (2.0 * math.pi)
								logging.print("got bearing (%01.2frad)", state.bearing)
							end
						else logging.error("gps not available") end
					else logging.error("completely surrounded") end

					---@diagnostic disable-next-line: need-check-nil
					if modemSource:match("^inventory%[%d+%]$") then
						turtle.equipLeft()
						turtle.select(currentSlot)
						logging.print("unequipping wireless modem")
					end

					if movement then
						logging.print("moving to original position...")
						if movement == "parallel-forward" then
							if not turtle.back() then error("obstruction during displacement", 0) end
							logging.print("moved backward parallel to current bearing")
						elseif movement == "parallel-backward" then
							if not turtle.forward() then error("obstruction during displacement", 0) end
							logging.print("moved forward parallel to current bearing")
						elseif movement == "perpendicular-forward" then
							if not turtle.back() then error("obstruction during displacement", 0) end
							turtle.turnRight()
							logging.print("moved backward perpendicular to current bearing")
						elseif movement == "perpendicular-backward" then
							if not turtle.forward() then error("obstruction during displacement", 0) end
							turtle.turnRight()
							logging.print("moved forward perpendicular to current bearing")
						end
					end
				else
                    logging.error("gps not available")
                end
			end
		else
            logging.error("insufficient fuel")
        end
		
		state.bearing = manualBearing
		logging.error("set bearing default (%01.2frad)", manualBearing)
		return false
    end

	function eturtle.calibrate(manualPosition, manualBearing, manualEquipment)
		-- Coalesce default argument values.
		if manualPosition == nil then manualPosition = vector.new(0, 0, 0) end
		if manualBearing == nil then manualBearing = eturtle.SOUTH end
		if manualEquipment == nil then manualEquipment = {} end

		logging.print("calibrating turtle...")

		local positionCalibrationSuccess = eturtle.calibratePosition(manualPosition.x, manualPosition.y, manualPosition.z)
		local bearingCalibrationSuccess = eturtle.calibrateBearing(manualBearing)
		local equipmentCalibrationSuccess = eturtle.calibrateEquipment(manualEquipment.left, manualEquipment.right)

		return positionCalibrationSuccess and bearingCalibrationSuccess and equipmentCalibrationSuccess, positionCalibrationSuccess, bearingCalibrationSuccess, equipmentCalibrationSuccess
	end

	function eturtle.enableLogging(printHook, errorHook)
		do
			if printHook == nil then printHook = defaultPrintHook end
			expect(1, printHook, "function")
		end
		do
			if errorHook == nil then errorHook = defaultErrorHook end
			expect(2, errorHook, "function")
		end

		logging.enabled = true
		logging.hooks.print = printHook
		logging.hooks.error = errorHook
	end

	function eturtle.disableLogging()
		logging.enabled = false
	end

    --[[ Introspection Methods ]]--
    function eturtle.getPosition()
        if state.position == nil then
            logging.error("position is not calibrated")
            return nil
        end
        return vector.new(state.position.x, state.position.y, state.position.z)
    end

    function eturtle.getBearing()
        if state.bearing == nil then
            logging.error("bearing is not calibrated")
            return nil
        end
        return state.bearing
    end

    function eturtle.getEquipment()
        if state.equipment == nil then
            logging.error("equipment is not calibrated")
            return nil
        end
        return {left = state.equipment.left, right = state.equipment.right}
    end

    function eturtle.getSelectedSlot()
        return eturtle.getSelectedSlot()
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

		logging.print("saving turtle state to \"%s\"...", path)

		if state.position == nil then
			logging.error("position has not been calibrated")
			return false
		end

		if state.bearing == nil then
			logging.error("bearing has not been calibrated")
			return false
		end

		if state.equipment == nil then
			logging.error("equipment has not been calibrated")
			return false
		end

		logging.print("opening state file \"%s\" for writing...", path)
		local file, fileError = fs.open(path, "wb")
		if file then
			local signatureBytes = "ETS"
			file.write(signatureBytes)
			logging.print("wrote file signature (%s)", signatureBytes)
			
			local positionBytes = string.pack("lll", state.position.x, state.position.y, state.position.z)
			file.write(positionBytes)
			logging.print("wrote position bytes (<%d,%d,%d> -> %s)", state.position.x, state.position.y, state.position.z, pretty.pretty(positionBytes))

			local bearingBytes = string.pack("d", state.bearing)
			file.write(bearingBytes)
			logging.print("wrote bearing bytes (%f -> %s)", state.bearing, pretty.pretty(bearingBytes))

			local equipmentBytes = string.pack("s1s1", state.equipment.left or "", state.equipment.right or "")
			file.write(equipmentBytes)
			logging.print("wrote equipment bytes (%s,%s -> %s)", state.equipment.left or "<nothing>", state.equipment.right or "<nothing>", pretty.pretty(equipmentBytes))

			file.flush()
			file.close()
			logging.print("wrote to disk")
			return true
		end

		logging.error("could not open state file \"%s\" for writing (%s)", path, fileError)
		return false
	end

	function eturtle.loadState(path)
		do
			expect(1, path, "string")
		end

		logging.print("loading turtle state...")

		logging.print("opening state file for reading...")
		local file, fileError = fs.open(path, "rb")
		if file then
			local signatureBytes = file.read(3)
			if signatureBytes == "ETS" then
				logging.print("file signature matched")

				local positionBytes = file.read(string.packsize("lll"))
				state.position = vector.new(string.unpack("lll", positionBytes))
				logging.print("read position bytes (%s -> <%d,%d,%d>)", pretty.pretty(positionBytes), state.position.x, state.position.y, state.position.z)
				
				local bearingBytes = file.read(string.packsize("d"))
				state.bearing = string.unpack("d", bearingBytes)
				logging.print("read bearing bytes (%s -> %f)", pretty.pretty(bearingBytes), state.bearing)

				local equipmentBytes = "" do
					state.equipment = {}
					
					local leftEquipmentBytesCount = file.read()
					if leftEquipmentBytesCount > 0 then
						local leftEquipment = file.read(leftEquipmentBytesCount)
						state.equipment.left = leftEquipment
						equipmentBytes = equipmentBytes .. string.pack("s1", leftEquipment)
					else
						equipmentBytes = equipmentBytes .. "\000"
					end

					local rightEquipmentBytesCount = file.read()
					if rightEquipmentBytesCount > 0 then
						local rightEquipment = file.read(rightEquipmentBytesCount)
						state.equipment.right = rightEquipment
						equipmentBytes = equipmentBytes .. string.pack("s1", rightEquipment)
					else
						equipmentBytes = equipmentBytes .. "\000"
					end
				end
				logging.print("read equipment bytes (%s -> %s,%s)", pretty.pretty(equipmentBytes), state.equipment.left or "<nothing>", state.equipment.right or "nothing")

				return true
			end

			logging.error("state file did not match signature (%s ~= ETS)", pretty.pretty(signatureBytes))
			return false
		end

		logging.error("could not open state file for reading (%s)", fileError)
		return false
	end

    --[[ Traversal Methods ]]--
    local function calculateBearingVector(bearing)
        return vector.new(-math.sin(bearing), 0, math.cos(bearing))
    end

    function eturtle.forward(blocks)
        do
            if blocks == nil then blocks = 1 end
            blocks = expect.expect(1, blocks, "number")
            blocks = expect.range(blocks, 1, math.huge)
        end

        logging.print("attempting to move forward %d block(s)", blocks)

        logging.print("checking position...")
        if state.position == nil then
            logging.error("position not calibrated")
            return false, 0
        end
        
        logging.print("checking bearing...")
        if state.bearing == nil then
            logging.error("bearing not calibrated")
            return false, 0
        end

        logging.print("checking fuel...")
        local currentFuelLevel = eturtle.getFuelLevel()
        if currentFuelLevel < blocks then
            logging.error("insufficient fuel")
            return false, 0
        end

        local bearingVector = calculateBearingVector(state.bearing)
        for block = 1, blocks do
            local success, reason = turtle.forward()
            if not success then
                logging.error("cannot move forward (%s)", reason)
                return false, block
            end
            state.position = state.position + bearingVector
        end

        return true, blocks
    end

    function eturtle.back(blocks)
        do
            if blocks == nil then blocks = 1 end
            blocks = expect.expect(1, blocks, "number")
            blocks = expect.range(blocks, 1, math.huge)
        end

        logging.print("attempting to move backward %d block(s)", blocks)

        logging.print("checking position...")
        if state.position == nil then
            logging.error("position not calibrated")
            return false, 0
        end

        logging.print("checking bearing...")
        if state.bearing == nil then
            logging.error("bearing not calibrated")
            return false, 0
        end

        logging.print("checking fuel...")
        local currentFuelLevel = eturtle.getFuelLevel()
        if currentFuelLevel < blocks then
            logging.error("insufficient fuel")
            return false, 0
        end

        local bearingVector = calculateBearingVector(state.bearing)
        for block = 1, blocks do
            local success, reason = turtle.back()
            if not success then
                logging.error("cannot move backward (%s)", reason)
                return false, block
            end
            state.position = state.position - bearingVector
        end

        return true, blocks
    end

    function eturtle.left(blocks)
        eturtle.turnLeft()
        eturtle.forward(blocks)
    end

    function eturtle.right(blocks)
        eturtle.turnRight()
        eturtle.forward(blocks)
    end

    function eturtle.strafeLeft(blocks)
        do
            if blocks == nil then blocks = 1 end
            blocks = expect.expect(1, blocks, "number")
            blocks = expect.range(blocks, 1, math.huge)
        end

        logging.print("attempting to move backward %d block(s)", blocks)

        logging.print("checking position...")
        if state.position == nil then
            logging.error("position not calibrated")
            return false, 0
        end

        logging.print("checking bearing...")
        if state.bearing == nil then
            logging.error("bearing not calibrated")
            return false, 0
        end

        logging.print("checking fuel...")
        local currentFuelLevel = eturtle.getFuelLevel()
        if currentFuelLevel < blocks then
            logging.error("insufficient fuel")
            return false, 0
        end

        local bearingVector = calculateBearingVector((state.bearing - 0.5 * math.pi) % (2.0 * math.pi))
        turtle.turnLeft()
        for block = 1, blocks do
            local success, reason = turtle.back()
            if not success then
                logging.error("cannot move backward (%s)", reason)
                turtle.turnRight()
                return false, block
            end
            state.position = state.position + bearingVector
        end
        turtle.turnRight()
        
        return true, blocks
    end

    function eturtle.strafeRight(blocks)
        do
            if blocks == nil then blocks = 1 end
            blocks = expect.expect(1, blocks, "number")
            blocks = expect.range(blocks, 1, math.huge)
        end

        logging.print("attempting to move backward %d block(s)", blocks)

        logging.print("checking position...")
        if state.position == nil then
            logging.error("position not calibrated")
            return false, 0
        end

        logging.print("checking bearing...")
        if state.bearing == nil then
            logging.error("bearing not calibrated")
            return false, 0
        end

        logging.print("checking fuel...")
        local currentFuelLevel = eturtle.getFuelLevel()
        if currentFuelLevel < blocks then
            logging.error("insufficient fuel")
            return false, 0
        end

        local bearingVector = calculateBearingVector((state.bearing + 0.5 * math.pi) % (2.0 * math.pi))
        turtle.turnRight()
        for block = 1, blocks do
            local success, reason = turtle.back()
            if not success then
                logging.error("cannot move backward (%s)", reason)
                turtle.turnLeft()
                return false, block
            end
            state.position = state.position + bearingVector
        end
        turtle.turnLeft()

        return true, blocks
    end

    function eturtle.up(blocks)
        do
            if blocks == nil then blocks = 1 end
            blocks = expect.expect(1, blocks, "number")
            blocks = expect.range(blocks, 1, math.huge)
        end

        logging.print("attempting to move upward %d block(s)", blocks)

        logging.print("checking position...")
        if state.position == nil then
            logging.error("position not calibrated")
            return false, 0
        end

        logging.print("checking bearing...")
        if state.bearing == nil then
            logging.error("bearing not calibrated")
            return false, 0
        end

        logging.print("checking fuel...")
        local currentFuelLevel = eturtle.getFuelLevel()
        if currentFuelLevel < blocks then
            logging.error("insufficient fuel")
            return false, 0
        end

        local upVector = vector(0, 1, 0)
        for block = 1, blocks do
            local success, reason = turtle.up()
            if not success then
                logging.error("cannot move upward (%s)", reason)
                return false, block
            end
            state.position = state.position + upVector
        end

        return true, blocks
    end

    function eturtle.down(blocks)
        do
            if blocks == nil then blocks = 1 end
            blocks = expect.expect(1, blocks, "number")
            blocks = expect.range(blocks, 1, math.huge)
        end

        logging.print("attempting to move downward %d block(s)", blocks)

        logging.print("checking position...")
        if state.position == nil then
            logging.error("position not calibrated")
            return false, 0
        end

        logging.print("checking bearing...")
        if state.bearing == nil then
            logging.error("bearing not calibrated")
            return false, 0
        end

        logging.print("checking fuel...")
        local currentFuelLevel = eturtle.getFuelLevel()
        if currentFuelLevel < blocks then
            logging.error("insufficient fuel")
            return false, 0
        end

        local downVector = vector(0, -1, 0)
        for block = 1, blocks do
            local success, reason = turtle.down()
            if not success then
                logging.error("cannot move downward (%s)", reason)
                return false, block
            end
            state.position = state.position + downVector
        end

        return true, blocks
    end

    function eturtle.turnLeft()
        if state.bearing == nil then
            logging.error("bearing not calibrated")
            return false
        end

        turtle.turnLeft()
        state.bearing = (state.bearing - 0.5 * math.pi) % (2.0 * math.pi)
        return true
    end

    function eturtle.turnRight()
        if state.bearing == nil then
            logging.error("bearing not calibrated")
            return false
        end

        turtle.turnRight()
        state.bearing = (state.bearing + 0.5 * math.pi) % (2.0 * math.pi)
        return true
    end

    function eturtle.turnAround()
        if state.bearing == nil then
            logging.error("bearing not calibrated")
            return false
        end

        turtle.turnRight()
        turtle.turnRight()
        state.bearing = (state.bearing + 1.0 * math.pi) % (2.0 * math.pi)
        return true
    end
end return eturtle
