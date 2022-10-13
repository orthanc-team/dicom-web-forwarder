# Dicom Web Forwarder

A regular Orthanc embedding a lua script which will forward every incoming instance and delete it afterwards.

## How it works?

Deeply inspired from: [https://bitbucket.org/osimis/orthanc-setup-samples/src/master/lua-samples/robust-forwarder.lua](https://bitbucket.org/osimis/orthanc-setup-samples/src/master/lua-samples/robust-forwarder.lua)

The lua script will forward each incoming instance (through DicomWeb) and delete it afterwards.
If it is interrupted, at startup, it will try to resend every instance currently stored in Orthanc.
When a job fails because of a network issue when forwarding, it will retry the job immediately.

## How to use it ?

- configure Orthanc as usually (through env var or via json)
- add these env var:
  ```
  DESTINATION_URL: "http://orthanc.team:8042/dicom-web"
  DESTINATION_USER: "demo"
  DESTINATION_PASSWORD: "demo"
  ```
