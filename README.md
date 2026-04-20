# electron-detect
Detect and surface versioning of MacOS apps built on Electron

---

### Description 

Electron Detect searches through common MacOS application directories (/Applications, ~/Applications), uses `mdfind` to locate all `.app `files on the system, then checks each one for the presence of an Electron framework. 
     
For each detected Electron app, it extracts and displays: 
- The app's own version (from the app's Info.plist file)
- The Electron framework version (using multiple methods to ensure reliability)

### Use

```
chmod +x electron_detect.sh
./electron_detect.sh
```

### Example 

```
-> % ./electron_detect.sh

==============================================
Latest available Electron version: v41.2.1
==============================================

==============================================
App: /Applications/Slack.app
App Version: v4.49.81
Electron: v41.1.0
Chromium: 146.0.7680.166
Node.js: 24.14.0
==============================================

```
         
---

### License 

MIT Licence
