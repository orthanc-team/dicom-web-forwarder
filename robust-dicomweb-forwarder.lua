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
    urlDestination = os.getenv("DESTINATION_URL")
    userDestination = os.getenv("DESTINATION_USER")
    passwordDestination = os.getenv("DESTINATION_PASSWORD")
    labelToApply = os.getenv("DESTINATION_LABEL")

    apiKey = os.getenv("DESTINATION_API_KEY")
    
    -- configure the dicomweb destination in Orthanc
    local payload = {}
    payload["Url"] = urlDestination

    if apiKey ~= nil then
        -- api key case
        local payload2 = {}
        payload2["api-key"] = apiKey
        payload["HttpHeaders"] = payload2
    else
        -- user/password case
        payload["Username"] = userDestination
        payload["Password"] = passwordDestination
    end
    RestApiPut("/dicom-web/servers/destination",  DumpJson(payload, true), false)

    -- prepare urlDestination for calls to api
    urlDestination = string.gsub(urlDestination, "/dicom%-web", "")

    -- try to forward everything that is already in Orthanc at startup
    print("-------------- starting forwarder script")
    local allInstancesIds = ParseJson(RestApiGet("/instances"))
  
    for i, instanceId in pairs(allInstancesIds) do
        ForwardInstance(instanceId)
    end
  
    index = 1
    print("-------------- forwarder script started")
  
end
  
urlDestination = ""
userDestination = ""
passwordDestination = ""
labelToApply = ""
apiKey = ""

labeledStudyInstanceUIDs = {}
index = 1
tableSize = 10

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
  
        if labelToApply ~= "" then
            -- get studyInstanceUID (we do it here because the script should work when it starts with an already filled Orthanc)
            local studyInstanceUID = GetStudyInstanceUID(instanceId)
            
            -- check if studyInstanceUID has already been processed
            if not StudyAlreadyLabeled(studyInstanceUID) then

                -- get the remote Orthanc ID
                local orthancId = GetRemoteStudyId(studyInstanceUID)

                -- apply the label
                ApplyLabel(orthancId, labelToApply)

                -- mark it as labeled
                MarkStudyInstanceUIDAsLabeled(studyInstanceUID)
            end
        end

        -- delete instance once it has been transmitted to target
        RestApiDelete("/instances/" .. instanceId)
    end
  
end

function GetStudyInstanceUID(instanceId)
    -- retrieve the Study instance UID based on the orthanc ID of a instance
    local seriesId = GetParentSeriesId(instanceId)
    local studyId = GetParentStudyId(seriesId)
    return ParseJson(RestApiGet("/studies/" .. studyId))["MainDicomTags"]["StudyInstanceUID"]
end

function GetParentSeriesId(instanceId)
   return ParseJson(RestApiGet("/instances/" .. instanceId))["ParentSeries"]
end

function GetParentStudyId(seriesId)
    return ParseJson(RestApiGet("/series/" .. seriesId))["ParentStudy"]
end

function StudyAlreadyLabeled(studyInstanceUID)
    -- returns true if the study has already been labeled
    -- (i.e the studyinstanceUID is in the table)
    for i,id in ipairs(labeledStudyInstanceUIDs) do
        if id == studyInstanceUID then
            -- already processed
            return true
        end
    end
    return false
end

function GetRemoteStudyId(studyInstanceUID)
    -- gets the orthanc study id from the destination Orthanc
    SetHttpCredentials(userDestination, passwordDestination)
    SetHttpTimeout(1)

    local headers = {}
    if apiKey ~= nil then
        -- api key case (api-key will take over the user/password if both are provided)
        headers = {["content-type"] = "application/json", ["api-key"] = apiKey}
    else
        headers = {["content-type"] = "application/json",}
    end
    local response = HttpPost(urlDestination .. "/tools/lookup", studyInstanceUID, headers)
    
    -- print(ParseJson(response)[1]["ID"])
    return ParseJson(response)[1]["ID"]
end

function ApplyLabel(orthancId, label)
    -- call the API route to apply the label to the study in the distant Orthanc
    SetHttpCredentials(userDestination, passwordDestination)
    SetHttpTimeout(1)

    local headers = {}
    if apiKey ~= nil then
        -- api key case (api-key will take over the user/password if both are provided)
        headers = {["api-key"] = apiKey,}
    else
        headers = nil
    end
    HttpPut(urlDestination .. "/studies/" .. orthancId .. "/labels/" .. label, "", headers)
end

function MarkStudyInstanceUIDAsLabeled(studyInstanceUID)
    -- insert the studyInstanceUID in the table,
    -- the table being a kind of circular buffer

    -- first filling of the table:
    if #labeledStudyInstanceUIDs ~= 10 then
        table.insert(labeledStudyInstanceUIDs, studyInstanceUID)
        index = #labeledStudyInstanceUIDs
    -- as soon as there are 10 elements, we have to recycle:
    else
        index = index + 1
        if index > 10 then
            index = 1
        end
        table.remove(labeledStudyInstanceUIDs, index)
        table.insert(labeledStudyInstanceUIDs, index, studyInstanceUID)
    end
end
