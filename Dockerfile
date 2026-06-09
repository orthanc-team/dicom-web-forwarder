#FROM orthancteam/orthanc:26.4.0
FROM orthancteam/orthanc-pre-release:2026.06.03
# because we need the key-values store (WO-578)

COPY robust-dicomweb-forwarder.lua /scripts/

ENV ORTHANC__LUA_SCRIPTS='["/scripts/robust-dicomweb-forwarder.lua"]'
ENV DICOM_WEB_PLUGIN_ENABLED="true"