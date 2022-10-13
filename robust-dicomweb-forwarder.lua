-- This script implements a robust (but slow) forwarder in lua.
-- It aims is to forward each instance and delete it afterwards.
-- If it is interrupted, at startup, it will try to resend every instance currently stored in Orthanc.
-- When a job fails because of a network issue when forwarding, it will retry the job immediately.
-- it assumes that you have declared a 'destination' entry in the DicomWeb config.

function ForwardInstance(instanceId)
    local payload = {}
    payload["Resources"] = {}
    table.insert(payload["Resources"], instanceId)
    payload["Synchronous"] = false
    local job = ParseJson(RestApiPost("/dicom-web/servers/destination/stow", DumpJson(payload, true)))
    print("created job " .. job["ID"] .. " to transfer instance " .. instanceId)
  
end
  
  -- method called by Orthanc at startup
function Initialize()

    -- get the dicomweb destination params from the env var
    local url = os.getenv("DESTINATION_URL")
    local user = os.getenv("DESTINATION_USER")
    local password = os.getenv("DESTINATION_PASSWORD")
    
    -- configure the dicomweb destination in Orthanc
    local body = '{"Url":"' .. url .. '","Username":"' .. user .. '","Password":"' .. password .. '"}'
    RestApiPut("/dicom-web/servers/destination", body, false)

    -- try to forward everything that is already in Orthanc at startup
    print("-------------- starting forwarder script")
    local allInstancesIds = ParseJson(RestApiGet("/instances"))
  
    for i, instanceId in pairs(allInstancesIds) do
        ForwardInstance(instanceId)
    end
  
    print("-------------- forwarder script started")
  
end
  
  
function OnStoredInstance(instanceId, tags, metadata)
    -- everytime a new instance is received in Orthanc, forward it
  
    ForwardInstance(instanceId)
  
end
  
  
function OnJobFailure(jobId)
    print("job " .. jobId .. " failed")
  
    local job = ParseJson(RestApiGet("/jobs/" .. jobId))
    -- PrintRecursive(job)
  
    if job["Type"] == "DicomWebStowClient" then
  
        if job["Content"]["FunctionErrorCode"] == 9 then  -- 9 = Error in the network protocol
            -- retry
            RestApiPost("/jobs/" .. jobId .. "/resubmit", "")
  
        elseif job["Content"]["FunctionErrorCode"] == 7 then -- 7 = Accessing an inexistent item (bad dicom web server configuration)
            print("bad dicomweb configuration, no retry")

        elseif job["ErrorCode"] == -1 then -- internal error (e.g. if the instance has been deleted while the job was trying to execute)
            print("internal job error, no retry")
       
        else
            print("unhandled error code")
            PrintRecursive(job)
  
       end
    end
  
end
  
function OnJobSuccess(jobId)
  
    print("job " .. jobId .. " succeeded")
  
    local job = ParseJson(RestApiGet("/jobs/" .. jobId))
    -- PrintRecursive(job)
  
    if job["Type"] == "DicomWebStowClient" then
        
        local instanceId = job["Content"]["Resources"]["Instances"][1]
  
        -- delete instance once it has been transmitted to target
        RestApiDelete("/instances/" .. instanceId)
    end
  
end