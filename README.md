To run this, you need:
* [websocat](https://github.com/vi/websocat) to connect to chat;
* [luvit](https://luvit.io/) as the programming environment;
* [ncat](https://nmap.org/ncat/), netcat may work too, can skip this if you
  don't want to send messages;
* something that behaves like `tee` to both write raw logs to disk and
  show in a console window, although that's of very little use other than
  to see if a weird looking chat message is from a glitch or not.

* `wss` logs Owncast chat to disk
* `status` logs Owncast stream status to disk every minute, not used yet;
  the most important data there is the viewer count and stream start/end time
* `main` displays chat from the above logs
* `setup.lua` contains chat display configuration, currently just user renames
* `setup.bat` contains data needed to connect (which instance, chatter key)
* `chat` downloads some chat scrollback, it isn't used for anything
  at the moment, but is relevant because the deeper point of this tool was
  to log the chatroom.
* `config` dumps chat config, the emoji list and custom javascript into
  a folder for archival purposes

First, populate `setup.bat`
HOST is the hostname of the site with the Owncast instance, e.g. `example.com`
TOKEN is the chat access token. Open the page with developer tools (Network tab),
look for `https://(host)/ws?accessToken=...`, copy the URL and paste just
the token from the end. Replace the `%3D` at the end with `=` if there's one.

Run `wss`, it will start logging chat to `data/wss-(current date).jsonl`

Run `status`, it will start logging stream status to `data/status-(current date).jsonl`

Run `main.lua`, it will load some scrollback from the latest log and display
new messages as they roll in.

You can write chat messages. If you prefix the message with /, it will be
interpreted as Lua code instead. Write `/say "/foo"` to say something that
begins with a slash.

With links in chat, emotes and stickers, you're sadly on your own.

It's in a terminal because it's what was easy to make, ideally it'd be in
an ugly win32 gui, anything's better than React.

Goes well with streamlink, open `https://(host)/hls/0/stream.m3u8` with it
to watch the stream, you will need to set up streamlink on your own.

You may have seen a screenshot with my font customized, here's how I recommend
doing it on Windows.  
Right-click in this folder and create a new shortcut. Point it to just `cmd.exe`.  
Click the address bar in Explorer, copy the current folder path.  
Right click the new shortcut, Properties, paste the path into `Start in:`.  
Now customizations to conhost shouldn't be global to the entire system.  
Press alt-space or the cmd icon at the top left of the window, Properties.  
There, you can customize the column count and font. Use a TrueType font
to see Unicode characters, otherwise you might just see question marks
when somebody dumps Chinese or Japanese into chat.
