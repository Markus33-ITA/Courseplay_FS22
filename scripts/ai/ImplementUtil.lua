--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2021 Peter Vaiko

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

---
--- Implement utilities for the Courseplay AI

---@class ImplementUtil
ImplementUtil = {}

function ImplementUtil.isPartOfNode(node, parentNode)
    -- Check if Node is part of partOfNode and not in a different component
    while node ~= 0 and node ~= nil do
        if node == parentNode then
            return true
        else
            node = getParent(node)
        end
    end
    return false
end

--- ImplementUtil.findJointNodeConnectingToNode(workTool, fromNode, toNode, doReverse)
--	Returns: (node, backtrack, rotLimits)
--		node will return either:		1. The jointNode that connects to the toNode,
--										2. The toNode if no jointNode is found but the fromNode is inside the same component as the toNode
--										3. nil in case none of the above fails.
--		backTrack will return either:	1. A table of all the jointNodes found from fromNode to toNode, if the jointNode that connects to the toNode is found.
--										2: nil if no jointNode is found.
--		rotLimits will return either:	1. A table of all the rotLimits of the componentJoint, found from fromNode to toNode, if the jointNode that connects to the toNode is found.
--										2: nil if no jointNode is found.
function ImplementUtil.findJointNodeConnectingToNode(workTool, fromNode, toNode, doReverse)
    if fromNode == toNode then return toNode end

    -- Attempt to find the jointNode by backtracking the compomentJoints.
    for index, component in ipairs(workTool.components) do
        if ImplementUtil.isPartOfNode(fromNode, component.node) then
            if not doReverse then
                for _, joint in ipairs(workTool.componentJoints) do
                    if joint.componentIndices[2] == index then
                        if workTool.components[joint.componentIndices[1]].node == toNode then
                            --          node            backtrack         rotLimits
                            return joint.jointNode, {joint.jointNode}, {joint.rotLimit}
                        else
                            local node, backTrack, rotLimits = ImplementUtil.findJointNodeConnectingToNode(workTool, workTool.components[joint.componentIndices[1]].node, toNode)
                            if backTrack then table.insert(backTrack, 1, joint.jointNode) end
                            if rotLimits then table.insert(rotLimits, 1, joint.rotLimit) end
                            return node, backTrack, rotLimits
                        end
                    end
                end
            end

            -- Do Reverse in case not found
            for _, joint in ipairs(workTool.componentJoints) do
                if joint.componentIndices[1] == index then
                    if workTool.components[joint.componentIndices[2]].node == toNode then
                        --          node            backtrack         rotLimits
                        return joint.jointNode, {joint.jointNode}, {joint.rotLimit}
                    else
                        local node, backTrack, rotLimits = ImplementUtil.findJointNodeConnectingToNode(workTool, workTool.components[joint.componentIndices[2]].node, toNode, true)
                        if backTrack then table.insert(backTrack, 1, joint.jointNode) end
                        if rotLimits then table.insert(rotLimits, 1, joint.rotLimit) end
                        return node, backTrack, rotLimits
                    end
                end
            end
        end
    end

    -- Last attempt to find the jointNode by getting parent of parent untill hit or the there is no more parents.
    if ImplementUtil.isPartOfNode(fromNode, toNode) then
        return toNode, nil
    end

    -- If anything else fails, return nil
    return nil, nil
end



local allowedJointTypes = {}
---@param implement table implement object
function ImplementUtil.isWheeledImplement(implement)
    if #allowedJointTypes == 0 then
        local jointTypeList = {"implement", "trailer", "trailerLow", "semitrailer"}
        for _,jointType in ipairs(jointTypeList) do
            local index = AttacherJoints.jointTypeNameToInt[jointType]
            if index then
                table.insert(allowedJointTypes, index, true)
            end
        end
    end

    local activeInputAttacherJoint = implement:getActiveInputAttacherJoint()

    if activeInputAttacherJoint and allowedJointTypes[activeInputAttacherJoint.jointType] and
            implement.spec_wheels and implement.spec_wheels.wheels and #implement.spec_wheels.wheels > 0 then
        -- Attempt to find the pivot node.
        local node, _ = ImplementUtil.findJointNodeConnectingToNode(implement, activeInputAttacherJoint.rootNode, implement.rootNode)
        if node then
            -- Trailers
            if (activeInputAttacherJoint.jointType ~= AttacherJoints.JOINTTYPE_IMPLEMENT)
                    -- Implements with pivot and wheels that do not lift the wheels from the ground.
                    or (node ~= implement.rootNode and activeInputAttacherJoint.jointType == AttacherJoints.JOINTTYPE_IMPLEMENT and
                    (not activeInputAttacherJoint.topReferenceNode or true or
                    -- TODO_22
                            g_vehicleConfigurations:get(implement, 'implementWheelAlwaysOnGround')))
            then
                return true
            end
        end
    end
    return false
end