FROM osimis/orthanc:22.9.2

COPY robust-dicomweb-forwarder.lua /scripts/

ENV ORTHANC__LUA_SCRIPTS='["/scripts/robust-dicomweb-forwarder.lua"]'