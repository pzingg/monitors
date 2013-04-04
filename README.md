monitors
========

Scripts to help monitor servers.

top_analyzer.rb
---------------
Reads one or more top logs and summarizes highest load factors
for a list of processes to watch.

First, create a cron job or just execute top to collect, say, 5000
log entries at one second intervals.  Use -b for batch mode:

/usr/bin/top -b -n 5000 -d 1 > top.log

Then run top_analyzer.rb:

./top_analyzer.rb top.log sshd imapd mysqld ...

Summary results are printed to stdout.