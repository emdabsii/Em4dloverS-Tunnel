# Em4dloverS Tunnel Manager - setup link: install the tools one tunnel type needs
# Sourced by emad.sh. Do not run directly.
# ---------- setup link (em4d://) ----------
# The Iran side makes a link; the foreign side pastes it. The link carries
# only what the other side needs: name, type, both IPs, tunnel ID, control port and token.
make_link(){ load "$1"; [ -n "$TYPE" ] && [ "$ROLE" = iran ] || { echo "ERR only Iran-side tunnels can make a link"; return 1; }
  local j; j=$(python3 -c 'import json,sys;print(json.dumps({"n":sys.argv[1],"t":sys.argv[2],"l":sys.argv[3],"r":sys.argv[4],"i":int(sys.argv[5]),"c":int(sys.argv[6] or 0),"k":sys.argv[7]}))' "$NAME" "$TYPE" "$REMOTE" "$LOCAL" "$IDX" "${CPORT:-0}" "${TOKEN:-}")
  echo "em4d://$(printf %s "$j" | base64 -w0)"; }
apply_link(){ local raw=$1 j; raw=${raw#em4d://}; raw=${raw//[[:space:]]/}
  j=$(printf %s "$raw" | base64 -d 2>/dev/null) || { echo "ERR bad link"; return 1; }
  eval "$(printf %s "$j" | python3 -c 'import json,sys,shlex
d=json.load(sys.stdin)
for k,v in {"NAME":d["n"],"TYPE":d["t"],"LOCAL":d["l"],"REMOTE":d["r"],"IDX":d["i"],"CPORT":d["c"],"TOKEN":d["k"]}.items(): print(k+"="+shlex.quote(str(v)))' 2>/dev/null)" || { echo "ERR bad link"; return 1; }
  ROLE=foreign; PORTS=1; PEER=""; create_tunnel; }

