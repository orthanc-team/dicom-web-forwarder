# Dicom Web Forwarder

A regular Orthanc embedding a lua script which will forward every incoming instance and delete it afterwards.

## How it works?

Deeply inspired from: [https://bitbucket.org/osimis/orthanc-setup-samples/src/master/lua-samples/robust-forwarder.lua](https://bitbucket.org/osimis/orthanc-setup-samples/src/master/lua-samples/robust-forwarder.lua)

The lua script will forward each incoming instance (through DicomWeb) and delete it afterwards.
If it is interrupted, at startup, it will try to resend every instance currently stored in Orthanc.
When a job fails because of a network issue when forwarding, it will retry the job immediately.
It assumes that you have declared a 'destination' entry in the DicomWeb config.

## How to use it ?

- configure Orthanc as usually (through env var or via json)
- add the dicomweb part in the config, and chose `destination` as the name for the dicom web server you want Orthanc to forward to:

```
  "DicomWeb": {
    "Servers": {
      "destination": [
        "http://orthanc-b:8042/dicom-web/", "demo", "demo"
      ]
    }
  }
```