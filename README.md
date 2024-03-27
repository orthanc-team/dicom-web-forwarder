# Dicom Web Forwarder

A regular Orthanc embedding a lua script which will forward every incoming instance and delete it afterwards.
It is also able to apply a label on the remote study if the destination is also Orthanc.

## How it works?

Deeply inspired from this [lua script](https://github.com/orthanc-server/orthanc-setup-samples/blob/master/lua-samples/robust-forwarder.lua)

The lua script will forward each incoming instance (through DicomWeb) and delete it afterwards.
If it is interrupted, at startup, it will try to resend every instance currently stored in Orthanc.
When a job fails because of a network issue when forwarding, it will retry the job immediately.

Just before the deletion of an instance, the script will try to apply a label to the remote study (if configured).

## How to use it ?

- configure Orthanc as usually (through env var or via json)
- add these mandatory env var:
  ```
  DESTINATION_URL: "http://orthanc.team:8042/dicom-web"
  DESTINATION_USER: "demo"
  DESTINATION_PASSWORD: "demo"
  ```
- add this env var to apply a label to the forwarder studies (on the destination Orthanc)
  ```
  DESTINATION_LABEL: "MY-HOSPITAL"
  ```
- if you want to apply labels on forwarded studies, make sure that the receiving Orthanc is reachable on the dicom-web route (of course) but also on these 2 ones:
  - `/studies/{orthancId}/labels/{label}`
  - `/tools/lookup`
