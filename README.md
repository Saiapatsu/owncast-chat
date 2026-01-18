`bouncer` logs Owncast chat to disk, `chat` presents it.

To run this, you need:
* [websocat](https://github.com/vi/websocat) to connect to chat
* [luvit](https://luvit.io/) as the programming environment
* [ncat](https://nmap.org/ncat/), netcat may work too, can skip this if you
  don't want to send messages
* something that behaves like `tee` to both write raw logs to disk and
  show in a console window, although that's of very little use other than
  to see if a weird looking message is from a `chat` glitch or not

Open the stream's webpage with developer tools (Network tab) and look for
`https://(host)/ws?accessToken=...`, copy this URL

Replace `https` with `wss`

Open cmd in this folder, enter `set WS=(the above wss URL)`  
Alternatively, add that line to the top of bouncer, but double the %
near the end of the URL so it won't get mangled by batch

Run bouncer, it will start logging to `wss-(current date).jsonl`

Run chat, it will load some scrollback from the latest log and display
new messages as they roll in

You can write into chat. It's actually the Luvit REPL modified, you can prefix
your message with / to run Lua code instead. Write `/say "/foo"` to say
something that begins with a slash.

Other people's messages will appear in the middle of the message you're typing,
I will have to mess with the readline to fix this

Copying links is annoying due to the left padding, I gotta add something to
copy the n-th link/emote from the bottom

Doesn't display emotes (would libcaca help? he he he)

Doesn't do word substitution, stickers and other goodies from the instance
this was meant for, but I hope to highlight affected words

It's in a terminal because it's what was easy to make, ideally it'd be in
an ugly win32 gui, anything's better than React

Goes well with streamlink, open `https://(host)/hls/0/stream.m3u8` with it

You can get a little bit of scrollback from the server from:  
`https://(host)/api/chat?accessToken=...`  
It's not in a format `chat` can ingest (one event on each line)
