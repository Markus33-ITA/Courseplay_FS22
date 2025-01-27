CourseEvent = {};
local CourseEvent_mt = Class(CourseEvent, Event);

InitEventClass(CourseEvent, "CourseEvent");

function CourseEvent:emptyNew()
	local self = Event:new(CourseEvent_mt);
	self.className = "CourseEvent";
	return self;
end

function CourseEvent:new(vehicle, courses)
	self.vehicle = vehicle;
	self.courses = courses
	return self;
end

function CourseEvent:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	CpUtil.debugVehicle(CpDebug.DBG_MULTIPLAYER,self.vehicle,"readStream course event")
	self.vehicle = NetworkUtil.getObject(streamReadInt32(streamId))
	local nCourses = streamReadInt32(streamId)
	self.courses = {}
	for _ = 1, nCourses do
		table.insert(self.courses, Course.createFromStream(self.vehicle,streamId, connection))
	end
	self:run(connection);
end

function CourseEvent:writeStream(streamId, connection)
	CpUtil.debugVehicle(CpDebug.DBG_MULTIPLAYER,self.vehicle,"writeStream course event")
	streamWriteInt32(streamId, NetworkUtil.getObjectId(self.vehicle))
	streamWriteInt32(streamId, #self.courses)
	for _, course in ipairs(self.courses) do
		course:writeStream(streamId, connection)
	end
end

-- Process the received event
function CourseEvent:run(connection)
	CpUtil.debugVehicle(CpDebug.DBG_MULTIPLAYER,self.vehicle,"run course event")
	if #self.courses > 0 then
		for _, course in ipairs(self.courses) do
			g_courseStorage:assignCourseToVehicle(self.vehicle, course)
		end
	else
		g_courseStorage:unloadAllCoursesFromVehicle(self.vehicle)
	end
	if not connection:getIsServer() then
		-- event was received from a client, so we, the server broadcast it to all other clients now
		CpUtil.debugVehicle(CpDebug.DBG_MULTIPLAYER,self.vehicle,"broadcast course event feedback")
		g_server:broadcastEvent(CourseEvent:new(self.vehicle, self.courses), nil, connection, self.vehicle);
	end;
end

function CourseEvent.sendEvent(vehicle, courses)
	if courses then
		if g_server ~= nil then
			CpUtil.debugVehicle(CpDebug.DBG_MULTIPLAYER, vehicle, "broadcast course event")
			g_server:broadcastEvent(CourseEvent:new(vehicle, courses), nil, nil, vehicle);
		else
			CpUtil.debugVehicle(CpDebug.DBG_MULTIPLAYER, vehicle, "send course event")
			g_client:getServerConnection():sendEvent(CourseEvent:new(vehicle, courses));
		end;
	else 
		CpUtil.infoVehicle(vehicle, 'CourseEvent Error: course = nil or #course<1!!!')
	end
end