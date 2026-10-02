#!/bin/bash
S=/tmp/claude-0/-home-user-TVPV8/b0e88ede-8c7c-5ce2-8a3a-b3e3be977f38/scratchpad
pkill -x otclient; pkill -INT -x tvp; while pgrep -x tvp >/dev/null; do sleep 1; done
mysql tvp -e "DELETE FROM player_items WHERE player_id=1; DELETE FROM player_depotitems WHERE player_id=1; UPDATE players SET posx=0,posy=0,posz=0 WHERE id=1"
cd /home/user/tvp && (nohup ./tvp > $S/server.log 2>&1 &)
until grep -q "Server Online" $S/server.log; do sleep 2; done; echo server-online
