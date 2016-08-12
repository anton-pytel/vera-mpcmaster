module("L_MpcMaster", package.seeall)

MPCMULTCTRL_SERVICE = "urn:demo-micasaverde-com:serviceId:MpcMultipleControl1"
local DEVICE_ID
local PARENT_DEVICE
local DEVICE_TYPE = "urn:demo-micasaverde-com:device:MpcMaster:1"
local MSG_CLASS = "MpcMaster"

local DEVICE_CLIENT = "urn:demo-micasaverde-com:device:MpcClient:1"
local CLIENT_SERVICE = "urn:demo-micasaverde-com:serviceId:MpcControl1"

local DEBUG_MODE = true
local taskHandle = -1

local TASK_ERROR = 2
local TASK_ERROR_PERM = -2
local TASK_SUCCESS = 4
local TASK_BUSY = 1

local function log(text, level)
	luup.log(string.format("%s: %s", MSG_CLASS, text), (level or 50))
end

local function debug(text)
	if (DEBUG_MODE) then
		log("debug: " .. text)
	end
end

local function task(text, mode)
	luup.log("task " .. text)
	if (mode == TASK_ERROR_PERM) then
		taskHandle = luup.task(text, TASK_ERROR, MSG_CLASS, taskHandle)
	else
		taskHandle = luup.task(text, mode, MSG_CLASS, taskHandle)

		-- Clear the previous error, since they're all transient
		if (mode ~= TASK_SUCCESS) then
			luup.call_delay("clearTask", 30, "", false)
		end
	end
end

--
-- Has to be "non-local" in order for MiOS to call it
--
function clearTask()
	task("Clearing...", TASK_SUCCESS)
end


-- function is called after startup to check input data
function startupDeferred()
    -- check sampleperiod
	local empty = luup.variable_get(MPCMULTCTRL_SERVICE, "samplePeriod", PARENT_DEVICE)
	if (empty == nil or empty == "" ) then
		--
		-- Set the variable so that it appears in the Device/Advanced list
		--
		local msg = "Sample period must be set"
		task(msg, TASK_ERROR_PERM)
		return
	end
    -- check setpoint
	local empty = luup.variable_get(MPCMULTCTRL_SERVICE, "setpoint", PARENT_DEVICE)
	if (empty == nil or empty == "" ) then
		--
		-- Set the variable so that it appears in the Device/Advanced list
		--
		local msg = "Setpoint must be set"
		task(msg, TASK_ERROR_PERM)
		return
	end	
	-- check mpcid1
	empty = luup.variable_get(MPCMULTCTRL_SERVICE, "mpcid1", PARENT_DEVICE)
	if (empty == nil or empty == "" ) then
		--
		-- Set the variable so that it appears in the Device/Advanced list
		--
		luup.variable_set(MPCMULTCTRL_SERVICE, "mpcid1", "", PARENT_DEVICE)
		local msg = "Set the mpcid1 "
		task(msg, TASK_ERROR_PERM)
		return
	end	
	-- check controlled device
	empty = luup.variable_get(MPCMULTCTRL_SERVICE, "mpcid2", PARENT_DEVICE)
	if (empty == nil or empty == "" ) then
		--
		-- Set the variable so that it appears in the Device/Advanced list
		--
		luup.variable_set(MPCMULTCTRL_SERVICE, "mpcid2", "", PARENT_DEVICE)
		local msg = "Set the mpcid2 "
		task(msg, TASK_ERROR_PERM)
		return
	end		
     -- check measuring device
	empty = luup.variable_get(MPCMULTCTRL_SERVICE, "boundary", PARENT_DEVICE)
	if (empty == nil or empty == "" ) then
		--
		-- Set the variable so that it appears in the Device/Advanced list
		--		
		luup.variable_set(MPCMULTCTRL_SERVICE, "boundary", "", PARENT_DEVICE)
		local msg = "Boundary has to be set"
		task(msg, TASK_ERROR_PERM)
		return
	end		
end

-- this runs when the first time device is created
function initialize(parentDevice)
    PARENT_DEVICE = parentDevice
    
	log("#" .. tostring(parentDevice) .. " starting up with id " .. luup.devices[parentDevice].id)

	--
	-- Set variables for  override, only "set" these if they aren't already set
	-- to force these Variables to appear in Vera's Device list.
	--
	if (luup.variable_get(MPCMULTCTRL_SERVICE, "bypass", parentDevice) == nil) then
		luup.variable_set(MPCMULTCTRL_SERVICE, "bypass", "1", parentDevice)
	end

	if (luup.variable_get(MPCMULTCTRL_SERVICE, "boundary", parentDevice) == nil) then
		luup.variable_set(MPCMULTCTRL_SERVICE, "boundary", 75, parentDevice)
	end	
	if (luup.variable_get(MPCMULTCTRL_SERVICE, "mpcid1", parentDevice) == nil) then
		luup.variable_set(MPCMULTCTRL_SERVICE, "mpcid1", 222, parentDevice)
	end	
	if (luup.variable_get(MPCMULTCTRL_SERVICE, "mpcid2", parentDevice) == nil) then
		luup.variable_set(MPCMULTCTRL_SERVICE, "mpcid2", 225, parentDevice)
	end		
	if (luup.variable_get(MPCMULTCTRL_SERVICE, "samplePeriod", parentDevice) == nil) then
		luup.variable_set(MPCMULTCTRL_SERVICE, "samplePeriod", 15, parentDevice)
	end	
	if (luup.variable_get(MPCMULTCTRL_SERVICE, "setpoint", parentDevice) == nil) then
		luup.variable_set(MPCMULTCTRL_SERVICE, "setpoint", "", parentDevice)
	end		
	
	--
	-- Do this deferred to avoid slowing down startup processes.
	--
	startupDeferred()
end


function doNextStep()
    
	local bypass = luup.variable_get(MPCMULTCTRL_SERVICE, "bypass", PARENT_DEVICE)
	local samplePeriod =luup.variable_get(MPCMULTCTRL_SERVICE, "samplePeriod", PARENT_DEVICE)
	
	-- if bypass is set to 1 then the process is switched off
	if bypass~="1" then
		local mpcid1 = luup.variable_get(MPCMULTCTRL_SERVICE, "mpcid1", PARENT_DEVICE)
		local mpcid2 = luup.variable_get(MPCMULTCTRL_SERVICE, "mpcid2", PARENT_DEVICE)
		local boundary = luup.variable_get(MPCMULTCTRL_SERVICE, "boundary", PARENT_DEVICE)
		local setpoint = luup.variable_get(MPCMULTCTRL_SERVICE, "setpoint", PARENT_DEVICE)

		local lcDV = 0
		local lcACT = "getStep"

		if setpoint < boundary then
		    lcDV = mpcid1
		else
		    lcDV = mpcid2
		end
		debug ("device id: " .. lcDV)
		lcDV= tonumber(lcDV)
		-- disable bypass (so controller can run)
		luup.variable_set(CLIENT_SERVICE, "bypass", "0", lcDV)
		-- call next step with specific MPC
		local resultCode, resultString, job, returnArguments = luup.call_action(CLIENT_SERVICE, lcACT, { }, lcDV)
		debug ("resultCode" .. resultCode)
		debug ("resultString" .. resultString)
		debug ("job" .. job)
		if (returnArguments~=nil) then
			debug ("returnArguments" .. table.concat(returnArguments))
		end
		-- after call enable bypass - master is responsible for new run
		luup.variable_set(CLIENT_SERVICE, "bypass", "1", lcDV)
		debug("MpcClient's timer stopped now")
		
		-- Resubmit the refreshCache job, unless the period==0 (disabled/manual)
	    debug("timer for nextMultiStep set in " .. tostring(samplePeriod) .. " sec.")
		luup.call_timer("nextMultiStep", 1, tostring(samplePeriod), "")			
    end
end

function test()
	local lcDV = 222
	local lcACT = "getStep"
	local CLIENT_SERVICE1 = "urn:demo-micasaverde-com:serviceId:MpcControl1"
	luup.variable_set(CLIENT_SERVICE1, "bypass", "1", lcDV)
	local resultCode, resultString, job, returnArguments = luup.call_action(CLIENT_SERVICE1, lcACT, { }, lcDV)
	luup.log("resultCode" .. resultCode)
	luup.log("resultString" .. resultString)
	luup.log("job" .. job)
	
end

--test()


