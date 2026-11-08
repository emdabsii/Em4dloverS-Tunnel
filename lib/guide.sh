# Em4dloverS Tunnel Manager - setup guide: install the tools one tunnel type needs
# Sourced by emad.sh. Do not run directly.
# ---------- temporary guide site (30 min, random 5-digit port, auto-removed) ----------
guide_make(){ local n=$1 TTL=${EMAD_GUIDE_TTL:-1800} port dir html ip; load "$n"; [ -n "$TYPE" ] || { echo "ERR no such tunnel"; return 1; }
  myip; ip=${MYIP:-127.0.0.1}; port=$(rand_port); dir=/tmp/emad-guide-$port; mkdir -p "$dir"
  local role_title role_steps type_label=$(type_name "$TYPE")
  if [ "$ROLE" = foreign ]; then role_title="Foreign server (exit)"
    role_steps="<li>Open the menu with <code>emad</code>, then choose <b>2 Create tunnel</b>.</li><li>Role: <b>Foreign</b>. No ports are needed on this side.</li><li>Type: <b>$type_label</b>.</li><li>Tunnel ID: <b>$IDX</b>, control port: <b>${CPORT:-not needed}</b>, token: <b>${TOKEN:-not needed}</b>.</li><li>Other server IP: <b>$LOCAL</b> (the Iran server).</li>"
  else role_title="Iran server (entry)"
    role_steps="<li>Open the menu with <code>emad</code>, then choose <b>2 Create tunnel</b>.</li><li>Role: <b>Iran</b>.</li><li>Type: <b>$type_label</b>.</li><li>Tunnel ID: <b>$IDX</b>, control port: <b>${CPORT:-not needed}</b>, token: <b>${TOKEN:-not needed}</b>.</li><li>Ports to forward: <b>$PORTS</b>.</li><li>Other server IP: <b>$REMOTE</b> (the foreign server).</li>"
  fi
  cat >"$dir/index.html" <<HTML
<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Em4dloverS guide: $NAME</title>
<style>
:root{--w:#fff;--k:#000;--r:#e1131f;--g:#f4f4f2}
*{box-sizing:border-box}body{margin:0;font:16px/1.6 system-ui,-apple-system,Segoe UI,Roboto,sans-serif;background:var(--k);color:var(--w)}
header{padding:38px 24px 26px;border-bottom:2px solid var(--r);background:linear-gradient(120deg,#000 60%,#1a0000)}
header h1{margin:0;font:600 34px/1.1 Georgia,"Times New Roman",serif}header h1 em{color:var(--r);font-style:normal}
header p{margin:8px 0 0;color:#bdbdb8}.warn{display:inline-block;margin-top:14px;padding:6px 12px;border:1px solid var(--r);border-radius:99px;color:#ff8a90;font-size:14px}
main{max-width:820px;margin:0 auto;padding:26px 22px 60px}
.card{background:var(--w);color:var(--k);border-radius:16px;padding:22px 24px;margin:0 0 18px;box-shadow:0 14px 40px #0008}
.card h2{margin:0 0 10px;font-size:20px}.card ol{padding-left:22px;margin:0}.card li{margin:6px 0}
code{background:var(--g);padding:2px 7px;border-radius:6px;font-size:14px}.red{color:var(--r)}
.kv{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:10px;margin:12px 0 0}
.kv div{border-left:3px solid var(--r);padding:4px 10px;background:var(--g);border-radius:0 8px 8px 0;color:var(--k)}.kv small{display:block;color:#666}
.step{display:flex;gap:14px;align-items:flex-start}.num{flex:none;width:34px;height:34px;border-radius:50%;background:var(--r);color:#fff;display:flex;align-items:center;justify-content:center;font-weight:700}
footer{text-align:center;color:#8f8f8b;font-size:14px;padding:20px}footer a{color:#fff}
</style></head><body>
<header><h1 class="serif">Em4d<em>loverS</em> Tunnel</h1><p>Setup guide for tunnel <b>$NAME</b> ($type_label)</p>
<span class="warn">This page closes automatically in 30 minutes and is then deleted.</span></header>
<main>
<div class="card"><h2>Your tunnel</h2><div class="kv">
<div><small>Name</small><b>$NAME</b></div><div><small>Type</small><b>$type_label</b></div><div><small>This server</small><b>$role_title</b></div>
<div><small>Tunnel ID</small><b>$IDX</b></div><div><small>Other server</small><b>${REMOTE:-$LOCAL}</b></div><div><small>Ports</small><b>${PORTS:-1}</b></div></div></div>
<div class="card"><h2>Step 1: Install the menu on both servers</h2><ol><li>Log in as <code>root</code>.</li><li>Run: <code>bash &lt;(curl -Ls https://raw.githubusercontent.com/emdabsii/Em4dloverS-Tunnel/main/install.sh)</code></li><li>Wait until the menu opens.</li></ol></div>
<div class="card"><h2>Step 2: Create the tunnel on $role_title</h2><ol>$role_steps</ol></div>
<div class="card"><h2>Step 3: Use the same values on the other server</h2><p>Tunnel ID, control port and token must match exactly on both servers. The type must be the same too.</p></div>
<div class="card"><h2>Step 4: Check it works</h2><ol><li>Open the web panel and select the tunnel.</li><li>Press <b>Check now</b>. A green state means the two servers are connected.</li><li>If it stays red, check that the control port and ports are open in your provider firewall.</li></ol></div>
<div class="card"><h2>Need help?</h2><p>Channel: <a class="red" href="https://t.me/Em4dloverS">t.me/Em4dloverS</a><br>Support: <a class="red" href="https://t.me/KaMr4ng">t.me/KaMr4ng</a></p></div>
</main><footer>Em4dloverS Tunnel  |  t.me/Em4dloverS</footer></body></html>
HTML
  ( setsid timeout "$TTL" python3 -m http.server "$port" --bind 0.0.0.0 --directory "$dir" >/dev/null 2>&1; rm -rf "$dir" ) </dev/null >/dev/null 2>&1 &
  command -v ufw >/dev/null && ufw allow "$port/tcp" >/dev/null 2>&1
  sleep 1; echo "http://$ip:$port/"; }

full_delete(){ local n=$1 f ip i
  load "$n" 2>/dev/null || true
  sysd disable --now "emad-$n" >/dev/null 2>&1; sysd stop "emad-$n" >/dev/null 2>&1
  [ -f "$RUN/$n.sh" ] && bash "$RUN/$n.sh" stop >/dev/null 2>&1          # removes firewall rules and the interface
  if command -v ufw >/dev/null && [ -n "${CPORT:-}" ] && [ "${CPORT:-0}" != 0 ]; then ufw delete allow "$CPORT" >/dev/null 2>&1; fi
  i="emad${IDX:-x}"; ip link del "$i" 2>/dev/null
  rm -f "$UNITDIR/emad-$n.service" "$TUN/$n.conf" "$RUN/$n.sh" "$CFG/$n".* "$CONF/keys/$n".*
  rm -rf /tmp/emad-guide-* 2>/dev/null
  sysd daemon-reload >/dev/null 2>&1; return 0; }

