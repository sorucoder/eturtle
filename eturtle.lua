local expect = require("cc.expect")

local eturtle = {} do
    local position, bearing, equipment

    -- Constants
    eturtle.SOUTH   = 0.0
    eturtle.WEST    = 0.5
    eturtle.NORTH   = 1.0
    eturtle.EAST    = 1.5

    -- Settings
    settings.define("eturtle.statefile", {description = "The path in which to store the turtle's state.", default = ".turtle", type = "string"})

    -- Calibration Methods
    function eturtle.calibrateEquipment(automatically, defaultLeft, defaultRight)
        expect(1, automatically, "nil", "boolean")
        if type(automatically) == "boolean" then
            if automatically then
                expect(2, defaultLeft, "nil", "boolean", "string")
                if type(defaultLeft) == "boolean" or type(defaultLeft) == "string" then
                    expect(3, defaultRight, "boolean", "string")
                else
                    expect(3, defaultRight, "nil")
                end
            else
                expect(2, defaultLeft, "boolean", "string")
                expect(3, defaultRight, "boolean", "string")
            end
        else
            automatically = true
            defaultLeft = nil
            defaultRight = nil
        end

        if automatically then
            local oldSlot = turtle.getSelectedSlot()
            for slot = 1, 16 do
                if not turtle.getItemDetail(slot) then
                    turtle.select(slot)

                    equipment = {left = false, right = false}

                    if turtle.equipLeft() then
                        local item = turtle.getItemDetail()
                        equipment.left = item.name
                        turtle.equipLeft()
                    end

                    if turtle.equipRight() then
                        local item = turtle.getItemDetail()
                        equipment.right = item.name
                        turtle.equipRight()
                    end

                    turtle.select(oldSlot)
                    return true, "automatic calibration succeeded"
                end
            end

            if defaultLeft ~= nil then
                equipment = {left = defaultLeft, right = defaultRight}
                return true, "automatic calibration failed: could not find an empty slot; manual calibration used"
            else
                return false, "automatic calibration failed: could not find an empty slot"
            end
        else
            equipment = {left = defaultLeft, right = defaultRight}
            return true, "manual calibration used"
        end
    end

    function eturtle.calibratePosition(automatically, defaultX, defaultY, defaultZ)
        expect(1, automatically, "nil", "boolean")
        if type(automatically) == "boolean" then
            if automatically then
                expect(2, defaultX, "nil", "number")
                if type(defaultX) == "number" then
                    expect(3, defaultY, "number")
                    expect(4, defaultZ, "number")
                else
                    expect(3, defaultY, "nil")
                    expect(4, defaultZ, "nil")
                end
            else
                expect(2, defaultX, "number")
                expect(3, defaultY, "number")
                expect(4, defaultZ, "number")
            end
        else
            automatically = true
            defaultX = nil
            defaultY = nil
            defaultZ = nil
        end

        if automatically then
            if equipment then
                if
                    equipment.left == "computercraft:wireless_modem" or equipment.left == "computercraft:advanced_wireless_modem" or
                    equipment.right == "computercraft:wireless_modem" or equipment.right == "computercraft:advanced_wireless_modem"
                then
                    local x, y, z = gps.locate()
                    if x then
                        position = vector.new(x, y, z)
                        return true, "automatic calibration succeeded"
                    elseif defaultX then
                        position = vector.new(defaultX, defaultY, defaultZ)
                        return true, "automatic calibration failed: gps unavailable; manual calibration used"
                    else
                        return false, "automatic calibration failed: gps unavailable"
                    end
                end
            end

            local oldSlot = turtle.getSelectedSlot()
            for slot = 1, 16 do
                local item = turtle.getItemDetail(slot)
                if item.name == "computercraft:wireless_modem" or item.name == "computercraft:advanced_wireless_modem" then
                    turtle.select(slot)
                    turtle.equipRight()
                    local x, y, z = gps.locate()
                    turtle.equipRight()
                    turtle.select(oldSlot)

                    if x then
                        position = vector.new(x, y, z)
                        return true, "automatic calibration succeeded"
                    elseif defaultX then
                        position = vector.new(defaultX, defaultY, defaultZ)
                        return true, "automatic calibration failed: gps unavailable; manual calibration used"
                    else
                        return false, "automatic calibration failed: gps unavailable"
                    end
                end
            end

            if defaultX then
                position = vector.new(defaultX, defaultY, defaultZ)
                return true, "automatic calibration failed: no wireless modem found; manual calibration used"
            else
                return false, "automatic calibration failed: no wireless modem found"
            end
        else
            position = vector.new(defaultX, defaultY, defaultZ)
            return true, "manual calibration used"
        end
    end

    function eturtle.calibrateBearing(automatically, defaultBearing)
        expect(1, automatically, "nil", "boolean")
        if type(automatically) == "boolean" then
            if automatically then
                expect(2, defaultBearing, "nil", "number")
            else
                expect(2, defaultBearing, "number")
            end
        else
            automatically = true
        end

        if automatically then
            local fuelLevel = turtle.getFuelLevel()
            if fuelLevel == "unlimited" or fuelLevel >= 3 then
                if equipment then
                    if
                        equipment.left == "computercraft:wireless_modem" or equipment.left == "computercraft:advanced_wireless_modem" or
                        equipment.right == "computercraft:wireless_modem" or equipment.right == "computercraft:advanced_wireless_modem"
                    then
                        local x0, y0, z0 = gps.locate()
                        if x0 then
                            if turtle.forward() then
                                local x1, y1, z1 = gps.locate()
                                if not turtle.back() then error("obstruction during bearing calibration") end

                                if x1 then
                                    local displacement = vector.new(x1, y1, z1) - vector.new(x0, y0, z0)
                                    if displacement.z == 1 then
                                        bearing = eturtle.SOUTH
                                    elseif displacement.x == -1 then
                                        bearing = eturtle.WEST
                                    elseif displacement.z == -1 then
                                        bearing = eturtle.NORTH
                                    elseif displacement.x == 1 then
                                        bearing = eturtle.EAST
                                    else
                                        error("no horizontal displacement when moving")
                                    end
                                    return true, "automatic calibration succeeded"
                                elseif defaultBearing then
                                    bearing = defaultBearing
                                    return true, "automatic calibration failed: gps unavailable; manual calibration used"
                                else
                                    return false, "automatic calibration failed: gps unavailable"
                                end
                            end

                            if turtle.back() then
                                local x1, y1, z1 = gps.locate()
                                if not turtle.forward() then error("obstruction during bearing calibration") end

                                if x1 then
                                    local displacement = vector.new(x1, y1, z1) - vector.new(x0, y0, z0)
                                    if displacement.z == -1 then
                                        bearing = eturtle.SOUTH
                                    elseif displacement.x == 1 then
                                        bearing = eturtle.WEST
                                    elseif displacement.z == 1 then
                                        bearing = eturtle.NORTH
                                    elseif displacement.x == -1 then
                                        bearing = eturtle.EAST
                                    else
                                        error("no horizontal displacement when moving")
                                    end
                                    return true, "automatic calibration succeeded"
                                elseif defaultBearing then
                                    bearing = defaultBearing
                                    return true, "automatic calibration failed: gps unavailable; manual calibration used"
                                else
                                    return false, "automatic calibration failed: gps unavailable"
                                end
                            end

                            if defaultBearing then
                                bearing = defaultBearing
                                return true, "automatic calibration failed: obstructed in both directions; manual calibration used"
                            else
                                return false, "automatic calibration failed: obstructed in both directions"
                            end
                        elseif defaultBearing then
                            bearing = defaultBearing
                            return true, "automatic calibration failed: gps unavailable; manual calibration used"
                        else
                            return false, "automatic calibration failed: gps unavailable"
                        end
                    end
                end

                local oldSlot = turtle.getSelectedSlot()
                for slot = 1, 16 do
                    local item = turtle.getItemDetail(slot)
                    if item.name == "computercraft:wireless_modem" or item.name == "computercraft:advanced_wireless_modem" then
                        turtle.select(slot)
                        turtle.equipRight()
                        local x0, y0, z0 = gps.locate()
                        turtle.equipRight()
                        turtle.select(oldSlot)

                        if x0 then
                            if turtle.forward() then
                                local x1, y1, z1 = gps.locate()
                                if not turtle.back() then error("obstruction during bearing calibration") end

                                if x1 then
                                    local displacement = vector.new(x1, y1, z1) - vector.new(x0, y0, z0)
                                    if displacement.z == 1 then
                                        bearing = eturtle.SOUTH
                                    elseif displacement.x == -1 then
                                        bearing = eturtle.WEST
                                    elseif displacement.z == -1 then
                                        bearing = eturtle.NORTH
                                    elseif displacement.x == 1 then
                                        bearing = eturtle.EAST
                                    else
                                        error("no horizontal displacement when moving")
                                    end
                                    return true, "automatic calibration succeeded"
                                elseif defaultBearing then
                                    bearing = defaultBearing
                                    return true, "automatic calibration failed: gps unavailable; manual calibration used"
                                else
                                    return false, "automatic calibration failed: gps unavailable"
                                end
                            end

                            if turtle.back() then
                                local x1, y1, z1 = gps.locate()
                                if not turtle.forward() then error("obstruction during bearing calibration") end

                                if x1 then
                                    local displacement = vector.new(x1, y1, z1) - vector.new(x0, y0, z0)
                                    if displacement.z == -1 then
                                        bearing = eturtle.SOUTH
                                    elseif displacement.x == 1 then
                                        bearing = eturtle.WEST
                                    elseif displacement.z == 1 then
                                        bearing = eturtle.NORTH
                                    elseif displacement.x == -1 then
                                        bearing = eturtle.EAST
                                    else
                                        error("no horizontal displacement when moving")
                                    end
                                    return true, "automatic calibration succeeded"
                                elseif defaultBearing then
                                    bearing = defaultBearing
                                    return true, "automatic calibration failed: gps unavailable; manual calibration used"
                                else
                                    return false, "automatic calibration failed: gps unavailable"
                                end
                            end

                            if defaultBearing then
                                bearing = defaultBearing
                                return true, "automatic calibration failed: obstructed in both directions; manual calibration used"
                            else
                                return false, "automatic calibration failed: obstructed in both directions"
                            end
                        elseif defaultBearing then
                            bearing = defaultBearing
                            return true, "automatic calibration failed: gps unavailable; manual calibration used"
                        else
                            return false, "automatic calibration failed: gps unavailable"
                        end
                    end
                end

                if defaultBearing then
                    bearing = defaultBearing
                    return true, "automatic calibration failed: no wireless modem found; manual calibration used"
                else
                    return false, "automatic calibration failed: no wireless modem found"
                end
            else
                if defaultBearing ~= nil then
                    bearing = defaultBearing
                    return true, "automatic calibration failed: insufficient fuel; manual calibration used"
                else
                    return false, "automatic calibration failed: insufficient fuel"
                end
            end
        else
            bearing = defaultBearing
            return true, "manual calibration used"
        end
    end

    function eturtle.calibrate(automatically, defaultPosition, defaultBearing, defaultEquipment)
        expect(1, automatically, "nil", "boolean")
        if type(automatically) == "boolean" then
            if automatically then
                expect(2, defaultPosition, "nil", "table")
                if type(defaultPosition) == "table" then
                    expect.field(defaultPosition, "x", "number")
                    expect.field(defaultPosition, "y", "number")
                    expect.field(defaultPosition, "z", "number")
                end

                expect(3, defaultBearing, "nil", "number")

                expect(4, defaultEquipment, "nil", "table")
                if type(defaultEquipment) == "table" then
                    expect.field(defaultEquipment, "left", "boolean", "string")
                    expect.field(defaultEquipment, "right", "boolean", "string")
                end
            else
                expect(2, defaultPosition, "table")
                expect.field(defaultPosition, "x", "number")
                expect.field(defaultPosition, "y", "number")
                expect.field(defaultPosition, "z", "number")

                expect(3, defaultBearing, "number")

                expect(4, defaultEquipment, "table")
                expect.field(defaultEquipment, "left", "boolean", "string")
                expect.field(defaultEquipment, "right", "boolean", "string")
            end
        else
            automatically = true
        end

        local calibrateEquipmentSuccess, calibrateEquipmentMessage = eturtle.calibrateEquipment(automatically, defaultEquipment.left, defaultEquipment.right)
        local calibratePositionSuccess, calibratePositionMessage = eturtle.calibratePosition(automatically, defaultPosition.x, defaultPosition.y, defaultPosition.z)
        local calibrateBearingSuccess, calibrateBearingMessage = eturtle.calibrateBearing(automatically, defaultBearing)

        return
            calibratePositionSuccess and calibrateBearingSuccess and calibrateEquipmentSuccess,
            {
                position = {success = calibratePositionSuccess, message = calibratePositionMessage},
                bearing = {success = calibrateBearingSuccess, message = calibrateBearingMessage},
                equipment = {success = calibrateEquipmentSuccess, message = calibrateEquipmentMessage}
            }
    end
end return eturtle
