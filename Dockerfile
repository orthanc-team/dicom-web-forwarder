FROM orthancteam/orthanc:24.3.4

COPY robust-dicomweb-forwarder.lua /scripts/

ENV ORTHANC__LUA_SCRIPTS='["/scripts/robust-dicomweb-forwarder.lua"]'
ENV DICOM_WEB_PLUGIN_ENABLED="true"