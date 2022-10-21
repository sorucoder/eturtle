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
    local position, bearing, equipment
	
    --[[ Constants ]]--
    eturtle.SOUTH   = 0.0
    eturtle.WEST    = 0.5
    eturtle.NORTH   = 1.0
    eturtle.EAST    = 1.5

    --[[ Settings ]]--
    settings.define("eturtle.statefile", {description = "The path in which to store the turtle's state.", default = ".turtle", type = "string"})

    --[[ Calibration and Configuration Methods ]]--
    function eturtle.calibrateEquipment(manualLeft, manualRight)
		-- Check argument types.
		expect(1, manualLeft, "nil", "string")
		expect(2, manualRight, "nil", "string")
		
		-- Check for empty slot.
		-- Unequip, analyze, then equip each side.
		local currentSlot = turtle.getSelectedSlot()
		for slot = 1, 16 do
			if turtle.getItemCount(slot) == 0 then
				equipment = {}
				turtle.select(slot)
				if turtle.equipLeft() then
					local item = turtle.getItemDetail()
					if item then equipment.left = item.name end
					turtle.equipLeft()
				end
				if turtle.equipRight() then
					local item = turtle.getItemDetail()
					if item then equipment.right = item.name end
					turtle.equipRight()
				end
				turtle.select(currentSlot)
				return true
			end
		end

		equipment = {left = manualLeft, right = manualRight}
		return false
    end

    function eturtle.calibratePosition(manualX, manualY, manualZ)
        -- Coalesce default argument values.
		if manualX == nil then manualX = 0 end
		if manualY == nil then manualY = 0 end
		if manualZ == nil then manualZ = 0 end

		-- Check argument types.
		expect(1, manualX, "number")
		expect(2, manualY, "number")
		expect(3, manualZ, "number")

		-- Check argument values.
		expect.range(manualX, -3e7, 3e7)
		expect.range(manualY, -3e7, 3e7)
		expect.range(manualZ, -3e7, 3e7)
		
		-- Attempt to determine if a modem is available in equipment or inventory,
		-- and equip one if one is not already equipped.
		local currentSlot, modemInEquipment, modemInInventory = turtle.getSelectedSlot(), nil, false
		do
			for slot = 1, 16 do
				if modemInEquipment == nil and turtle.getItemCount(slot) == 0 then
					turtle.select(slot)
					if turtle.equipLeft() then
						local item = turtle.getItemDetail()
						if item and item.name:match("^computercraft:[%a_]*wireless_modem$") then
							modemInEquipment = true
							turtle.equipLeft()
							break
						end
						turtle.equipLeft()
					end
					if turtle.equipRight() then
						local item = turtle.getItemDetail()
						if item and item.name:match("^computercraft:[%a_]*wireless_modem$") then
							modemInEquipment = true
							turtle.equipRight()
							break
						end
						turtle.equipRight()
					end
					turtle.select(currentSlot)
					modemInEquipment = false
				elseif turtle.getItemCount(slot) ~= 0 then
					local item = turtle.getItemDetail()
					if item and item.name:match("^computercraft:[%a_]*wireless_modem$") then
						modemInInventory = true
						turtle.select(slot)
						turtle.equipLeft()
						break
					end
				end
			end
		end

		-- Get the position using GPS if available.
		if modemInEquipment or modemInInventory then
			local x, y, z = gps.locate()
			if x then
				position = vector.new(x, y, z)
				if modemInInventory then
					turtle.equipLeft()
					turtle.select(currentSlot)
				end
				return true
			end
		end

		position = vector.new(manualX, manualY, manualZ)
		return false
    end

    function eturtle.calibrateBearing(manualBearing)
        -- Coalesce default argument value.
		if manualBearing == nil then manualBearing = eturtle.SOUTH end
		
		-- Check argument type.
		expect(1, manualBearing, "number")

		-- Check argument value.
		expect.range(manualBearing, 0.0, 2.0)
		manualBearing = roundToNearestInterval(manualBearing, 0.5)

		-- Check the current fuel level to verify if the calibration is possible.
		if turtle.getFuelLimit() == "unlimited" or turtle.getFuelLevel() >= 2 then
			-- Attempt to determine if a modem is available in equipment or inventory,
			-- and equip one if one is not already equipped.
			local currentSlot, modemInEquipment, modemInInventory = turtle.getSelectedSlot(), nil, false
			do
				for slot = 1, 16 do
					if modemInEquipment == nil and turtle.getItemCount(slot) == 0 then
						turtle.select(slot)
						if turtle.equipLeft() then
							local item = turtle.getItemDetail()
							if item and item.name:match("^computercraft:[%a_]*wireless_modem$") then
								modemInEquipment = true
								turtle.equipLeft()
								break
							end
							turtle.equipLeft()
						end
						if turtle.equipRight() then
							local item = turtle.getItemDetail()
							if item and item.name:match("^computercraft:[%a_]*wireless_modem$") then
								modemInEquipment = true
								turtle.equipRight()
								break
							end
							turtle.equipRight()
						end
						turtle.select(currentSlot)
						modemInEquipment = false
					elseif turtle.getItemCount(slot) ~= 0 then
						local item = turtle.getItemDetail()
						if item and item.name:match("^computercraft:[%a_]*wireless_modem$") then
							modemInInventory = true
							turtle.select(slot)
							turtle.equipLeft()
							break
						end
					end
				end
			end

			-- Calculate bearing by calculating a displacement moving forward.
			if modemInEquipment or modemInInventory then
				local deltaX, deltaZ = nil, nil
				do
					local x0, _, z0 = gps.locate()
					if x0 then
						if turtle.forward() then
							local x1, _, z1 = gps.locate()
							if x1 then
								deltaX, deltaZ = x1 - x0, z1 - z0
							end

							if not turtle.back() then
								if modemInInventory then
									turtle.equipLeft()
									turtle.select(currentSlot)
								end
								error("obstruction during bearing calibration")
							end
						elseif turtle.back() then
							local x1, _, z1 = gps.locate()
							if x1 then
								deltaX, deltaZ = x0 - x1, z0 - z1
							end

							if not turtle.forward() then
								if modemInInventory then
									turtle.equipLeft()
									turtle.select(currentSlot)
								end
								error("obstruction during bearing calibration")
							end
						else
							turtle.turnRight()
							if turtle.forward() then
								local x1, _, z1 = gps.locate()
								if x1 then
									deltaX, deltaZ = z1 - z0, x1 - x0
								end

								if not turtle.back() then
									turtle.turnLeft()
									if modemInInventory then
										turtle.equipLeft()
										turtle.select(currentSlot)
									end
									error("obstruction during bearing calibration")
								end
							elseif turtle.back() then
								local x1, _, z1 = gps.locate()
								if x1 then
									deltaX, deltaZ = z0 - z1, x0 - x1
								end

								if not turtle.forward() then
									turtle.turnLeft()
									if modemInInventory then
										turtle.equipLeft()
										turtle.select(currentSlot)
										error("obstruction during bearing calibration")
									end
								end
							end
							turtle.turnLeft()
						end
					end
				end

				if deltaX and deltaZ then
					if deltaZ < 0 then
						bearing = eturtle.NORTH
						if modemInInventory then
							turtle.equipLeft()
							turtle.select(currentSlot)
						end
						return true
					elseif deltaX > 0 then
						bearing = eturtle.EAST
						if modemInInventory then
							turtle.equipLeft()
							turtle.select(currentSlot)
						end
						return true
					elseif deltaZ > 0 then
						bearing = eturtle.SOUTH
						if modemInInventory then
							turtle.equipLeft()
							turtle.select(currentSlot)
						end
						return true
					elseif deltaX < 0 then
						bearing = eturtle.WEST
						if modemInInventory then
							turtle.equipLeft()
							turtle.select(currentSlot)
						end
						return true
					else
						if modemInInventory then
							turtle.equipLeft()
							turtle.select(currentSlot)
						end
						error("no displacement in bearing calibration")
					end
				end
			end
		end

		bearing = manualBearing
		return false
    end

	function eturtle.calibrate(manualPosition, manualBearing, manualEquipment)
		-- Coalesce default argument values.
		if manualPosition == nil then manualPosition = vector.new(0, 0, 0) end
		if manualBearing == nil then manualBearing = eturtle.SOUTH end
		if manualEquipment == nil then manualEquipment = {} end

		return eturtle.calibratePosition(manualPosition.x, manualPosition.y, manualPosition.z), eturtle.calibrateBearing(manualBearing), eturtle.calibrateEquipment(equipment.left, equipment.right)
	end

    --[[ Introspection Methods ]]--
    function eturtle.getPosition()
        return vector.new(position.x, position.y, position.z)
    end

    function eturtle.getBearing()
        return bearing * math.pi
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
end return eturtle
