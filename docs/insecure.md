# Insecure limitation

Code-server is intended to work with a TLS encrypted connected. Notably, many of the extensions and anything that needs web UI features will usually break.

For `tech-interview`, this includes (but not limited to) the following known limitations:

|Limitation|Description|
|---|---|
|Draw.io/Whiteboard|Usually, the provided `whiteboard.drawio` file provides the ability to have candidated whiteboard up diagrams. This is lost without TLS. Currently researching alternatives [here](https://github.com/jtaylor-afs/tech-interview/issues/15).|
|Markdown preview|Preview functionality is broken so candidate scenarios are less pretty by default. They will still show up as syntax highlighted markdown, but still not quite as nice as rendered markdown.|
|Clipboard|This can be frustrating but it appears to only conflict with pasting using right-click on the mouse. Ctrl+v still pastes just fine.|