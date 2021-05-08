# Printer Copy
This powershell script copies over print settings from a remote print server onto the local machine. 

## How to use the script

Script Args:

**CopyFrom**: Print server to copy printer settings from 

You can run the script like this:

```
$results = ./printer_copy.ps1 -CopyFrom MyPrintServerName
```

The script will return an object that contains results from the copy operation. It has the following properties:

**Name**: Printer Name 