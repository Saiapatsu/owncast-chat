`bouncer` logs Owncast chat to disk, `chat` presents it.

To run this, you need:
* [websocat](https://github.com/vi/websocat) to get chat
* [luvit](luvit.io) as the programming environment
* [ncat](https://nmap.org/ncat/), netcat may work too
* something that behaves like `tee` (output to both file and output),
  mine's from MinGW, although you could just edit bouncer to output to disk
  because there's not much point in reading the raw output anyway

Open the stream's webpage with developer tools (Network tab) open and look for
`https://(host)/ws?accessToken=...`

Replace `https` with `wss`.

Open cmd in this folder, write `set WS=(the above wss URL)`  
Alternatively, add that line to the top of bouncer, but double the % if
there's one near the end of the URL

Run bouncer, it will start logging to `wss-(current date).jsonl`

Run chat, it will load some scrollback from the latest log and display
new messages as they roll in.

You can write into chat. It's actually the Luvit REPL modified, you can prefix
your message with / to run Lua code instead. Write `/say "/foo"` to say
something that begins with a slash.

Other people's messages will appear in the middle of the message you're typing,
I will have to mess with the readline to fix this

Copying links is annoying due to the left padding, I gotta add something to
copy the n-th link/emote from the bottom

Doesn't display emotes (would libcaca help? he he he)

Doesn't do word substitution, stickers and other goodies from the instance
this was meant for

It's in a terminal because it's what was easy to make, ideally it'd be in a
super light HTML viewer, anything's better than React

Goes well with streamlink, open `https://(host)/hls/0/stream.m3u8` with it
