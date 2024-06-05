FROM orthancteam/orthanc:24.5.1

COPY robust-dicomweb-forwarder.lua /scripts/

ENV ORTHANC__LUA_SCRIPTS='["/scripts/robust-dicomweb-forwarder.lua"]'
ENV DICOM_WEB_PLUGIN_ENABLED="true"