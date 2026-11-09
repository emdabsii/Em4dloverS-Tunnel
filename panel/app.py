#!/usr/bin/env python3
# Em4dloverS Tunnel Panel  |  t.me/Em4dloverS
import os, sys, json, hashlib, hmac, secrets, subprocess, time, re, string
CONF = os.environ.get("EMAD_CONF", "/etc/emadlovers")
CFGF = os.path.join(CONF, "panel.json")
EMAD = os.environ.get("EMAD_BIN", "/usr/local/bin/emad")

def load():
    try: return json.load(open(CFGF))
    except Exception: return {}
def save(c):
    os.makedirs(CONF, exist_ok=True); json.dump(c, open(CFGF, "w")); os.chmod(CFGF, 0o600)
def phash(p, salt=None):
    salt = salt or secrets.token_hex(8)
    return salt + "$" + hashlib.pbkdf2_hmac("sha256", p.encode(), salt.encode(), 200000).hex()
def pcheck(p, h):
    try: return hmac.compare_digest(phash(p, h.split("$")[0]), h)
    except Exception: return False
def url(ip):
    c = load(); ssl = bool(c.get("cert"))
    return "%s://%s:%s" % ("https" if ssl else "http", c.get("domain") or ip, c.get("port"))

if __name__ == "__main__" and len(sys.argv) > 1 and sys.argv[1] in ("set", "url", "get"):
    if sys.argv[1] == "get": print(load().get(sys.argv[2], "")); sys.exit(0)
    if sys.argv[1] == "url": print(url(sys.argv[2] if len(sys.argv) > 2 else "127.0.0.1")); sys.exit(0)
    c = load()
    for kv in sys.argv[2:]:
        k, v = kv.split("=", 1)
        if k == "pass": c["pass"] = phash(v)
        elif k in ("port", "user", "domain", "cert", "key"): c[k] = int(v) if k == "port" else v
    c.setdefault("secret", secrets.token_hex(32)); save(c); sys.exit(0)

import glob, shutil, socket, threading
from collections import deque
from concurrent.futures import ThreadPoolExecutor
from flask import Flask, request, session, redirect, render_template_string, abort, jsonify

app = Flask(__name__)
_c = load()
app.secret_key = _c.get("secret", secrets.token_hex(32))
app.config.update(SESSION_COOKIE_HTTPONLY=True, SESSION_COOKIE_SAMESITE="Lax", SESSION_COOKIE_SECURE=bool(_c.get("cert")))
FAILS = {}
TUN = os.path.join(CONF, "tunnels.d")
KERNEL = {"gre", "gretap", "ipip", "vxlan", "gre6", "ipip6", "wg"}
UDPISH = {"backhaul-udp", "frp-kcp", "frp-quic", "gost-quic", "gost-kcp", "socat-udp"}

def emad(*a, t=300):
    try: return subprocess.run([EMAD, "api", *map(str, a)], capture_output=True, text=True, timeout=t).stdout.strip()
    except Exception as e: return "ERR " + str(e)
def sh(*a, t=6):
    try: return subprocess.run(list(a), capture_output=True, text=True, timeout=t).stdout
    except Exception: return ""
def uptime():
    try: s = int(float(open("/proc/uptime").read().split()[0])); return "%dd %dh %dm" % (s // 86400, s % 86400 // 3600, s % 3600 // 60)
    except Exception: return "-"
def osname():
    try: return dict(l.strip().split("=", 1) for l in open("/etc/os-release") if "=" in l)["PRETTY_NAME"].strip('"')
    except Exception: return "-"
def csrf():
    if "t" not in session: session["t"] = secrets.token_hex(16)
    return session["t"]

# ---------- tunnel data ----------
def tconf(name):
    d = {}
    try:
        for l in open(os.path.join(TUN, name + ".conf")):
            if "=" in l: k, v = l.rstrip("\n").split("=", 1); d[k] = v
    except Exception: return None
    return d
def tlist(): return [c for c in (tconf(os.path.basename(f)[:-5]) for f in sorted(glob.glob(TUN + "/*.conf"))) if c]
def svc(n): return sh("systemctl", "is-active", "emad-" + n).strip() or "unknown"
def default_nic():
    m = sh("ip", "route", "show", "default").split(); return m[m.index("dev") + 1] if "dev" in m else "eth0"
def src_iface(c):
    i = "emad" + c.get("IDX", "0")
    return (i, "tunnel interface") if c["TYPE"] in KERNEL and os.path.exists("/sys/class/net/" + i) else (default_nic(), "server NIC")
def counters(i):
    try: return int(open("/sys/class/net/%s/statistics/rx_bytes" % i).read()), int(open("/sys/class/net/%s/statistics/tx_bytes" % i).read())
    except Exception: return 0, 0
def peer_ip(c): return ("10.%s.0.%s" % (c["IDX"], 2 if c["ROLE"] == "iran" else 1)) if c["TYPE"] in KERNEL else c["REMOTE"]
def ping(ip, n=1):
    o = sh("ping", "-c", str(n), "-W", "1", "-n", "-q" if n > 1 else "-n", ip, t=n * 2 + 3)
    import re
    m = re.search(r"= [\d.]+/([\d.]+)/", o) or re.search(r"time=([\d.]+)", o)
    l = re.search(r"([\d.]+)% packet loss", o)
    return (float(m.group(1)) if m else None), (float(l.group(1)) if l else (0.0 if m else 100.0))
def tcp_ok(ip, port):
    try:
        with socket.create_connection((ip, int(port)), 2): return True
    except Exception: return False
def conn_state(c, rtt):
    if svc(c["NAME"]) != "active": return "stopped", "Service is not running"
    t = c["TYPE"]
    if t in KERNEL: return ("connected", "Peer answers through the tunnel") if rtt is not None else ("disconnected", "Peer does not answer through the tunnel")
    cp = c.get("CPORT", "")
    if t in UDPISH or not cp or cp == "0": return ("connected", "Peer answers ping") if rtt is not None else ("disconnected", "Peer does not answer ping")
    if t == "rathole" or t.startswith(("backhaul", "frp")) or t == "chisel":
        side = "sport" if c["ROLE"] == "iran" else "dport"
        n = len([x for x in sh("ss", "-Htn", "state", "established", "( %s = :%s )" % (side, cp)).splitlines() if x.strip()])
        return ("connected", "%d live control connection(s)" % n) if n else ("disconnected", "No control connection yet. Is the other side running?")
    if c["ROLE"] == "iran": return ("connected", "Exit server accepts connections") if tcp_ok(c["REMOTE"], cp) else ("disconnected", "Cannot reach the exit server control port")
    return ("connected", "Listening for the entry server") if ":%s" % cp in sh("ss", "-Hltn") else ("disconnected", "Control port is not listening")
def active_secs(n):
    try:
        m = int(sh("systemctl", "show", "emad-" + n, "-p", "ActiveEnterTimestampMonotonic", "--value").strip() or 0)
        return max(0, int(float(open("/proc/uptime").read().split()[0]) - m / 1e6)) if m else 0
    except Exception: return 0

# ---------- background sampler ----------
HIST, LAST = {}, {}
def sampler():
    while True:
        t0 = time.time()
        try:
            tl = tlist()
            def probe(c): return ping(peer_ip(c))[0] if svc(c["NAME"]) == "active" else None
            with ThreadPoolExecutor(8) as ex: rtts = list(ex.map(probe, tl))
            for c, rtt in zip(tl, rtts):
                n = c["NAME"]; i, _ = src_iface(c); rx, tx = counters(i); now = time.time(); up = down = 0.0
                if n in LAST and now > LAST[n][0] and rx >= LAST[n][1]: dt = now - LAST[n][0]; down = (rx - LAST[n][1]) / dt; up = (tx - LAST[n][2]) / dt
                LAST[n] = (now, rx, tx)
                HIST.setdefault(n, deque(maxlen=150)).append(dict(t=now, rtt=rtt, up=up, down=down, on=svc(n) == "active"))
        except Exception: pass
        time.sleep(max(0.3, 2 - (time.time() - t0)))
threading.Thread(target=sampler, daemon=True).start()

def live(name):
    tl = tlist() if name == "all" else [c for c in [tconf(name)] if c]
    if not tl: return {"state": "none", "series": {k: [] for k in ("rtt", "loss", "up", "down")}}
    series = {k: [] for k in ("rtt", "loss", "up", "down")}; L = max([len(HIST.get(c["NAME"], [])) for c in tl] + [0])
    for k in range(L):
        rt, lo, up, dn = [], [], 0.0, 0.0
        for c in tl:
            h = list(HIST.get(c["NAME"], []))
            if len(h) - L + k < 0: continue
            p = h[len(h) - L + k]; up += p["up"]; dn += p["down"]
            if p["on"]:
                if p["rtt"] is not None: rt.append(p["rtt"])
                w = [x for x in h[max(0, len(h) - L + k - 9):len(h) - L + k + 1] if x["on"]]
                lo.append(100.0 * sum(1 for x in w if x["rtt"] is None) / max(1, len(w)))
        series["rtt"].append(round(sum(rt) / len(rt), 1) if rt else None); series["loss"].append(round(sum(lo) / len(lo), 1) if lo else 0)
        series["up"].append(up); series["down"].append(dn)
    states, seen, tu, td, ups, src, last = [], set(), 0, 0, 0, "", None
    for c in tl:
        h = HIST.get(c["NAME"]); rtt = h[-1]["rtt"] if h else None
        states.append(conn_state(c, rtt)[0]); i, s = src_iface(c); src = s
        if i not in seen: seen.add(i); rx, tx = counters(i); td += rx; tu += tx
        ups = max(ups, active_secs(c["NAME"]))
    st = "connected" if all(x == "connected" for x in states) else "stopped" if all(x == "stopped" for x in states) else "disconnected"
    return dict(state=st, rtt=next((v for v in reversed(series["rtt"]) if v is not None), None), loss=series["loss"][-1] if series["loss"] else 0,
                up=series["up"][-1] if series["up"] else 0, down=series["down"][-1] if series["down"] else 0, tot_up=tu, tot_down=td, uptime=ups, src=src, series=series)


def tscore(c):
    """0-100 score from live measurements: latency, packet loss and connection state."""
    h = list(HIST.get(c["NAME"], []))[-30:]
    if not h or svc(c["NAME"]) != "active": return 0, 0, 100.0, "stopped"
    rtts = [x["rtt"] for x in h if x["rtt"] is not None]
    loss = 100.0 * sum(1 for x in h if x["rtt"] is None) / len(h)
    avg = sum(rtts) / len(rtts) if rtts else None
    st, _ = conn_state(c, h[-1]["rtt"])
    if avg is None or st != "connected": return 0, 0, 100.0, st
    s = 100 - min(45, avg / 4) - min(40, loss * 4)
    return round(max(0, s)), avg, loss, st
def stars(s):
    return 5 if s >= 85 else 4 if s >= 70 else 3 if s >= 55 else 2 if s >= 40 else 1 if s > 0 else 0
def ranked():
    rows = []
    for c in tlist():
        s, avg, loss, st = tscore(c); rows.append({"c": c, "score": s, "avg": avg, "loss": loss, "st": st, "stars": stars(s)})
    rows.sort(key=lambda r: -r["score"])
    if rows and rows[0]["score"] > 0: rows[0]["gold"] = True
    return rows
STAR_SVG = '<svg class="star" viewBox="0 0 24 24"><path d="M12 2.5l2.9 6.1 6.6.8-4.9 4.6 1.3 6.6L12 17.3 6.1 20.6l1.3-6.6L2.5 9.4l6.6-.8z"/></svg>'
def star_html(n, gold=False):
    cls = "stars gold" if gold else "stars"
    return '<span class="%s" title="%d of 5">%s</span>' % (cls, n, "".join(STAR_SVG if i < n else '<svg class="star off" viewBox="0 0 24 24"><path d="M12 2.5l2.9 6.1 6.6.8-4.9 4.6 1.3 6.6L12 17.3 6.1 20.6l1.3-6.6L2.5 9.4l6.6-.8z"/></svg>' for i in range(5)))

@app.before_request
def guard():
    if request.endpoint in ("login", "static"): return
    if not session.get("u"): return redirect("/login")
    if request.method == "POST" and not hmac.compare_digest(request.form.get("t", ""), session.get("t", "x")): abort(400)
app.jinja_env.globals.update(csrf=csrf)
import markupsafe
ICON = {
 "dash": '<path d="M3 13a9 9 0 1 1 18 0M12 13l4-5"/><circle cx="12" cy="13" r="1.4"/>',
 "tun": '<path d="M3 12h4m10 0h4M7 12a5 5 0 0 1 10 0 5 5 0 0 1-10 0z"/>',
 "new": '<path d="M12 5v14M5 12h14"/>',
 "stat": '<path d="M4 20V10m6 10V4m6 16v-7m4 7H2"/>',
 "set": '<path d="M4 6h10m4 0h2M4 12h2m4 0h10M4 18h12"/><circle cx="16" cy="6" r="2"/><circle cx="8" cy="12" r="2"/><circle cx="18" cy="18" r="2"/>',
 "tg": '<path d="M21 4 3 11l5 2 2 6 3-4 5 4z"/>',
 "ref": '<path d="M20 11a8 8 0 1 0-2.3 5.7M20 4v7h-7"/>',
}
app.jinja_env.globals["ico"] = lambda n: markupsafe.Markup('<svg class="i" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">%s</svg>' % ICON[n])
app.jinja_env.globals["LOGO"] = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAGAAAABgCAIAAABt+uBvAAAG30lEQVR42u2bX0gUWxzHz5k5M7O7uv5po1ZuuSIrmG4uFayF9FDQQ5C3jCRIX8TIIK2Horeeg6zABzcKesoeWsJg0/sSRGhCFPmnG0W2wkIGaqbZctfdnTnzuw+H9u5VM2v/Np7Pg+y6M7N7vvM73/P7/TiDEIfD4XA4HA6Hw+FwOBwOh8PhcDiZAafv0oIgYIwxTtlX6Lqu6zq/Z4aOIIwxANhsNqfTWVlZ6a5xKyYlHA4LgsAOAIC8vDyTyQQAq1wEIRSLxRYXF2OxGHsry/L9+/cHBwcFQchkHJHUXo4Ne25u7uXLl4FAYHp6urOz0+VyJR4zNDT0+PFjQggbJwDEpyEAiKJotVpLSkoqKyurq6sTT5yfm8+8QGlHUZS3b9/GYrFIJBIOh1VVPdl6co3n2u32tra2QCAAANFo9PLlywghQkgmf7+QbnWi0WhPT48kSYIgEEIIIfnWfEKIyWQiq4IxnpqaunnzZm1t7YPeB7IsF1gLMn+D03s3NE3DGI+MjMTtCSFEKdU0jX36Q0cjhHz+/PlY47Hh4WFHmSM+iw0SQWw8X79+jVvvT40QAFRVZW517tw5NrmMJtDyIf1sZsTCcHBw8NmzZ4qiZNihMyFQSnJFALh7924K086c8KAUxiDG+P3795n/aiFnRVkSLInpksEFWovLxpe8nz1xXUQQU8fhcCiKkvUfI2QlZPB3YMkkAMiyfLbjbC6UFFkwaV3XWYKzopS6rhNCbt++XV1drapq1iuvLAhUUFBgs9kkSWIJTtx9FUXZuHGjx+NpbW31eDxPnjxZuz0ZRCBRFAHg9OnTR44cEYmI4L8Bi4Jos9lKHaXsSBY7K0oDAJkMq4wKRCmVJOmG94b3hleW5cRZJgiC2Wy22+11dXWnTp3avn07pfR/ZvlNlNLS0oWFhYWFBSP0OkRRRAjV1dUBgKZpsVgMAM6cObN6em2xWPr7+4eHh5ku8b9Wq3XXrl2bN282+DLPetWsobF8FZMkKRwONzc3j42NMX2Zr7tcrr17905MTExPT2cyY8xOqQHfWHEVEwRhfn6+u7vbYrGEQiGM8YkTJxYXF/1+f9zX13WiqOu6KIojIyOhUKi8vPz69euzs7O9vb2U0gyrk6PFqiiKzKGbmpra2to6OjrYdFti2+tRIGZDlNLi4uLOzs7m5uaamprx8XFCyA/bj8YXiMUIpbS+vv7atWsVFRXnz58fHx+XJGnFtHsdeRDGmKlTWFjo9Xr9fn9FRUUoFPL5fBjjrMysLNdiKwZOQ0PDlStXnE6nqqqiKAaDwY8fP6642BlNoO+lLXHH2bBhQ3d3t8fj2fLHFuY1giDMzMxkuKrIlSnG9GJtDUppU1PTixcvZmZmdu7cOTU9xf6PEIpEIihF/ezfbIqxHDoSiTgcDq/Xu3Xr1paWloGBAUVRsjubcsikAeDixYtDQ0Ov/369Y8eOgYEBURSXlO85IlYmIijeOcUYa5q2f//+w38ezsvPO3To0OjoKKvLNE3LwfBJewSxErSkpIT1OpgW+/bt6/+r3+PxjI6OSpLEnGjt1m60CAIAj8dDKZVlGSHk8/kuXLjw4cMHpl1iBpgjimQ6/VMUZXJyEgAmJiYaGxvjPr08WMxmczAYZDtdAKCvry/eUTKsOgihW7duAcDVq1eLi4vZgFfspS4X6OHDh7kgEEmTOsxZLl26VFNTU1tb+/z5cxY4q9ecOTjLSJrUKS8vP3r06KdPn3bv3s2kiW8L+r0gKVcHIeR0Op1O5507d1h7lK3ua7HzHFzp07KJMxgMBgKBeCGamwlONvMgTdNYZz6ZTkXyfrR8NcihPCj5EjzJK2CMU9IG+G32B/3CQlFVVSVJkmEFSrK+sdvt9fX1lNIkJ5oBBRJFUdf19vb2yclJXdeT9DJiPHU0TXO5XC0tLW63O3kvy6EIIoQkaRmsPyvLss/ne/fu3ezsLNtPYhCB8vPzrVbrL9sz22+OMe7p6dm2bdu9e/dS+7RalueFIAh79uxhFRzbBPLDYjVx1x4Twmaz9fX1AUAkEqmqqkpVKpT9op+1irq6ugAgFoupqgoAfr//p6r5hoYG9lwQpfTVq1eiKBqqwXTw4MFwOKxpGttGpOs6E2j1uCsqKnK73e3t7U+fPmWlXPifsK7rXV1dKEUPTmVzFSOEsAfnjh8/3tramjhyhNCBAwfevHkTt1gWDolvLRZLUVFRYWFh4jXNFjNC6NGjRyhFbf9sBqHZbC4rK9u0aZPJZPry5cuSnIU9U8Y62cvrYfaCUqqqKts0xOyGHTw2NhaNRhEnEy6ZC2VByt00u/sdOBwOh8PhcDgcDofD4XA4HA6Hw/kl/gWCDnKRwCSgFwAAAABJRU5ErkJggg=="

CSS = """
:root{--bk:#000;--wh:#fff;--rd:#e1131f;--g1:#f4f4f2;--g2:#e0e0dd;--g3:#85857f;--ok:#12a150;--wn:#e0a100}
*{box-sizing:border-box}html{color-scheme:light}body{margin:0;font:15px/1.5 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;background:var(--wh);color:var(--bk)}
a{color:inherit}.serif{font-family:"Bodoni Moda","Didot","Playfair Display",Georgia,serif}.mono{font-family:ui-monospace,Menlo,Consolas,monospace}
.shell{display:grid;grid-template-columns:250px 1fr;min-height:100vh}
.rail{background:var(--bk);color:#eee;padding:26px 18px;display:flex;flex-direction:column;gap:26px;position:sticky;top:0;height:100vh}
.brand{display:flex;align-items:center;gap:12px}.brand img{width:42px;height:42px;border-radius:10px}.brand b{font-size:22px}.brand b em{color:var(--rd);font-style:normal}
.rail nav{display:flex;flex-direction:column;gap:2px}.rail nav a{display:flex;gap:12px;align-items:center;padding:11px 12px;border-radius:10px;text-decoration:none;color:#b3b3af;transition:background .15s,color .15s}
.rail nav a:hover{background:#161616;color:#fff}.rail nav a.on{background:var(--wh);color:var(--bk)}.rail nav a.on .i{color:var(--rd)}.i{width:19px;height:19px;flex:none}.rail .sp{flex:1}
.tg{display:flex;align-items:center;gap:10px;padding:10px 12px;border:1px solid #2b2b2b;border-radius:10px;text-decoration:none;color:#e6e6e6;font-size:14px}.tg:hover{border-color:var(--rd)}.tg.dim{color:#8f8f8b}
main{padding:34px 44px 40px;max-width:1240px;width:100%}
h1{font-size:36px;margin:0;font-weight:600;line-height:1.1}h2{font-size:20px;margin:34px 0 12px;font-weight:600}.sub{color:var(--g3);margin:6px 0 26px}
.top{display:flex;justify-content:space-between;align-items:flex-end;gap:16px;flex-wrap:wrap;margin-bottom:26px}
.pill{display:inline-flex;align-items:center;gap:8px;padding:5px 12px;border:1px solid var(--g2);border-radius:99px;font-size:13px}
.dot{display:inline-block;width:9px;height:9px;border-radius:50%;background:var(--rd)}.dot.ok{background:var(--ok);box-shadow:0 0 0 4px #12a15022;animation:pu 2s infinite}.dot.wn{background:var(--wn)}.dot.off{background:var(--g3)}
@keyframes pu{50%{box-shadow:0 0 0 7px #12a15000}}
.rings{display:grid;grid-template-columns:repeat(4,1fr);border-top:2px solid var(--bk);border-bottom:1px solid var(--g2)}
.ringc{padding:22px 16px 20px;display:flex;flex-direction:column;align-items:center;text-align:center;border-right:1px solid var(--g2)}.ringc:last-child{border-right:0}
.ring{position:relative;width:150px;height:150px}.ring svg{width:150px;height:150px;transform:rotate(-90deg)}.ring circle{fill:none;stroke-width:9}
.ring .tr{stroke:var(--g2)}.ring .fg{stroke:var(--ok);stroke-linecap:round;stroke-dasharray:377;stroke-dashoffset:377;transition:stroke-dashoffset .9s cubic-bezier(.2,.8,.2,1),stroke .4s}
.ring .v{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center}.ring .v b{font-size:30px;font-weight:600;line-height:1}.ring .v small{color:var(--g3);font-size:12px;margin-top:4px}
.ringc .l{margin-top:12px;font-weight:600}.ringc .s{color:var(--g3);font-size:13px;min-height:20px}
.charts{display:grid;grid-template-columns:1.4fr 1fr;gap:16px}.chart{background:var(--bk);color:#fff;border-radius:16px;padding:18px 18px 12px}.chart.wide{grid-column:1/-1}
.chart header{display:flex;justify-content:space-between;align-items:baseline;margin-bottom:6px;font-size:14px;color:#cfcfcb}.chart header b{color:#fff;font-size:16px}.lg i{display:inline-block;width:9px;height:9px;border-radius:2px;margin:0 5px 0 12px}
canvas{width:100%;height:190px;display:block}
table{width:100%;border-collapse:collapse}th{text-align:left;font-weight:500;color:var(--g3);font-size:13px;padding:0 10px 10px 0;border-bottom:1px solid var(--bk)}td{padding:14px 10px 14px 0;border-bottom:1px solid var(--g2);vertical-align:middle}
.btn{font:inherit;cursor:pointer;border:1px solid var(--bk);background:var(--wh);color:var(--bk);padding:7px 13px;border-radius:9px;transition:transform .12s,background .15s,color .15s;text-decoration:none;display:inline-flex;gap:6px;align-items:center}
.btn:hover{background:var(--bk);color:#fff}.btn:active{transform:translateY(1px)}.btn.red{background:var(--rd);border-color:var(--rd);color:#fff}.btn.red:hover{background:#b80f19}.btn.sm{padding:4px 10px;font-size:13px}.btn.danger:hover{background:var(--rd);border-color:var(--rd)}
.row{display:flex;gap:6px;flex-wrap:wrap}form.inl{display:inline}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(230px,1fr));gap:18px 22px;max-width:900px}
label{display:block;font-size:13px;color:var(--g3);margin-bottom:5px}input,select{width:100%;font:inherit;padding:11px 12px;border:1px solid var(--g2);border-radius:10px;background:#fff;color:var(--bk)}
input:focus,select:focus,.btn:focus-visible,a:focus-visible{outline:2px solid var(--rd);outline-offset:2px}
.note{border-left:3px solid var(--rd);padding:8px 14px;background:var(--g1);margin:0 0 24px;max-width:900px}
.kv{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));border-top:1px solid var(--bk)}.kv div{padding:12px 14px 12px 0;border-bottom:1px solid var(--g2)}.kv small{display:block;color:var(--g3)}
.seg{display:inline-flex;gap:3px}.seg i{width:16px;height:8px;background:var(--g2);border-radius:2px}.seg i.f{background:var(--ok)}.seg.y i.f{background:var(--wn)}.seg.r i.f{background:var(--rd)}
footer{margin-top:50px;padding-top:18px;border-top:1px solid var(--g2);display:flex;gap:22px;flex-wrap:wrap;font-size:14px}footer a{text-decoration:none}footer .dim{color:var(--g3)}

.cgrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:14px}
.cc{border:1px solid var(--g2);border-radius:16px;padding:16px 18px;transition:transform .2s,box-shadow .2s}.cc:hover{transform:translateY(-2px);box-shadow:0 10px 26px #0000001a}
.cc.full{border-color:#12a15055}.cc.part{border-color:#e0a10055}.cc.no{border-color:#e1131f55;background:#fff7f7}
.ctop{display:flex;justify-content:space-between;align-items:center;margin-bottom:10px}
.tick{width:34px;height:34px;display:inline-block;animation:bob 1.6s ease-in-out infinite}.tick svg{width:34px;height:34px}.tick circle{fill:#12a150}
.tick path{fill:none;stroke:#fff;stroke-width:5;stroke-linecap:round;stroke-linejoin:round;stroke-dasharray:40;stroke-dashoffset:40;animation:draw .8s .2s forwards}
@keyframes draw{to{stroke-dashoffset:0}}@keyframes bob{50%{transform:translateY(-4px)}}
.cs{margin-top:10px;font-size:14px}.ok{color:#12a150;font-weight:600}.wn{color:#b98300;font-weight:600}.no-t{color:#e1131f;font-weight:600}
.blink{animation:bl 1.1s steps(2,start) infinite}@keyframes bl{to{opacity:.35}}
.logbox{background:#000;color:#d9d9d4;border-radius:14px;padding:14px 16px;font:12.5px/1.6 ui-monospace,Menlo,Consolas,monospace;height:240px;overflow:auto}
.logbox .r{color:#ff5a63}.logbox .g{color:#4fd69a}.logbox .y{color:#f2c230}.logbox .d{color:#6b6b68}
.stars{display:inline-flex;gap:2px;vertical-align:middle}.star{width:16px;height:16px;fill:#e1131f}.star.off{fill:#dcdcd9}
.stars.gold .star{fill:#d4a017}.gold-tag{display:inline-block;margin-left:8px;padding:2px 9px;border-radius:99px;background:linear-gradient(135deg,#f5d36b,#c99a1c);color:#000;font-size:12px;font-weight:700;vertical-align:middle}
.howto h3{margin:0 0 6px;font-size:18px}.howto .box{margin-bottom:14px}.fam{border-left:4px solid var(--rd);padding:4px 0 4px 14px;margin:0 0 22px}
@media(max-width:900px){.shell{grid-template-columns:1fr}.rail{position:static;height:auto;flex-direction:row;flex-wrap:wrap;align-items:center;padding:14px}.rail nav{flex-direction:row;flex-wrap:wrap}.rail .sp,.rail .tg{display:none}
 main{padding:22px 16px 30px}.rings{grid-template-columns:1fr 1fr}.ringc:nth-child(2){border-right:0}.ringc:nth-child(-n+2){border-bottom:1px solid var(--g2)}.charts{grid-template-columns:1fr}table{display:block;overflow-x:auto}}
@media(prefers-reduced-motion:reduce){*{transition:none!important;animation:none!important}}
"""
BASE = """<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Em4dloverS Tunnel</title><link rel="icon" href="{{LOGO}}"><style>""" + CSS + """</style></head><body><div class="shell">
<aside class="rail"><div class="brand"><img src="{{LOGO}}" alt=""><b class="serif">Em4d<em>loverS</em></b></div>
<nav>{% for k,l,i in [('dash','Overview','dash'),('tun','Tunnels','tun'),('new','New tunnel','new'),('stat','Compatibility','stat'),('how','How it works','stat'),('set','Settings','set')] %}
<a href="/{{'' if k=='dash' else k}}" class="{{'on' if page==k}}">{{ico(i)}}<span>{{l}}</span></a>{% endfor %}</nav><div class="sp"></div>
<a class="tg" href="https://t.me/Em4dloverS" target="_blank" rel="noopener">{{ico('tg')}}Channel  t.me/Em4dloverS</a>
<a class="tg dim" href="https://t.me/KaMr4ng" target="_blank" rel="noopener">{{ico('tg')}}Support  t.me/KaMr4ng</a>
<form method="post" action="/logout"><input type="hidden" name="t" value="{{csrf()}}"><button class="btn sm" style="width:100%;justify-content:center">Sign out</button></form></aside>
<main>{% if msg %}<div class="note">{{msg}}</div>{% endif %}{{body|safe}}
<footer><a href="https://t.me/Em4dloverS" target="_blank" rel="noopener">Channel  t.me/Em4dloverS</a><a class="dim" href="https://t.me/KaMr4ng" target="_blank" rel="noopener">Support  t.me/KaMr4ng</a></footer></main></div></body></html>"""
LOGIN = """<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Sign in</title><link rel="icon" href="{{LOGO}}">
<style>""" + CSS + """
body{background:#000;color:#fff;min-height:100vh;display:grid;grid-template-columns:1.1fr 1fr}
.hero{padding:56px;display:flex;flex-direction:column;justify-content:space-between;border-right:1px solid #1d1d1d;overflow:hidden;position:relative}
.hero h2{font-size:clamp(40px,6vw,84px);line-height:.95;margin:0;font-weight:500}.hero h2 em{color:var(--rd);font-style:normal}
.trace{position:absolute;left:0;right:0;bottom:40%;width:100%;height:120px}.trace path{fill:none;stroke:var(--rd);stroke-width:2;stroke-dasharray:1400;stroke-dashoffset:1400;animation:d 3.2s ease-out forwards}
@keyframes d{to{stroke-dashoffset:0}}
.box{display:flex;align-items:center;justify-content:center;padding:32px;flex-direction:column;gap:30px}.box form{width:100%;max-width:340px;display:flex;flex-direction:column;gap:16px}
.box input{background:#0c0c0c;border-color:#2a2a2a;color:#fff}.box label{color:#9a9a97}.err{color:#ff6b73}.lk{display:flex;gap:20px;font-size:14px}.lk a{text-decoration:none;color:#ddd}.lk a.dim{color:#8f8f8b}
@media(max-width:820px){body{grid-template-columns:1fr}.hero{min-height:230px;padding:28px}}</style></head><body>
<section class="hero"><div class="brand"><img src="{{LOGO}}" alt=""><span class="mono" style="color:#9a9a97">tunnel panel</span></div>
<svg class="trace" viewBox="0 0 800 120" preserveAspectRatio="none"><path d="M0 70H180L205 70 225 18 252 108 276 44 292 70H520L540 70 556 30 576 96 592 70H800"/></svg>
<h2 class="serif">Em4d<em>loverS</em><br>Tunnel</h2></section>
<section class="box"><form method="post"><div class="serif" style="font-size:30px">Sign in</div>{% if err %}<div class="err">{{err}}</div>{% endif %}
<div><label for="u">Username</label><input id="u" name="u" autocomplete="username" required autofocus></div>
<div><label for="p">Password</label><input id="p" name="p" type="password" autocomplete="current-password" required></div>
<button class="btn red" style="padding:12px;justify-content:center">Sign in</button></form>
<div class="lk"><a href="https://t.me/Em4dloverS" target="_blank" rel="noopener">t.me/Em4dloverS</a><a class="dim" href="https://t.me/KaMr4ng" target="_blank" rel="noopener">t.me/KaMr4ng</a></div></section></body></html>"""

LIVE = """
<div class="rings">
 <div class="ringc"><div class="ring"><svg viewBox="0 0 140 140"><circle class="tr" cx="70" cy="70" r="60"/><circle class="fg" id="r1" cx="70" cy="70" r="60"/></svg><div class="v"><b id="v1">-</b><small>ms</small></div></div><div class="l">Latency</div><div class="s" id="s1">between the two servers</div></div>
 <div class="ringc"><div class="ring"><svg viewBox="0 0 140 140"><circle class="tr" cx="70" cy="70" r="60"/><circle class="fg" id="r2" cx="70" cy="70" r="60"/></svg><div class="v"><b id="v2">-</b><small>quality</small></div></div><div class="l">Link quality</div><div class="s" id="s2">packet loss -</div></div>
 <div class="ringc"><div class="ring"><svg viewBox="0 0 140 140"><circle class="tr" cx="70" cy="70" r="60"/><circle class="fg" id="r3" cx="70" cy="70" r="60"/></svg><div class="v"><b id="v3">-</b><small id="u3">MB/s</small></div></div><div class="l">Traffic now</div><div class="s" id="s3">-</div></div>
 <div class="ringc"><div class="ring"><svg viewBox="0 0 140 140"><circle class="tr" cx="70" cy="70" r="60"/><circle class="fg" id="r4" cx="70" cy="70" r="60"/></svg><div class="v"><b id="v4">-</b><small id="u4">uptime</small></div></div><div class="l">Tunnel uptime</div><div class="s" id="s4">-</div></div>
</div>
<h2 class="serif">Live charts</h2>
<div class="charts">
 <div class="chart"><header><span><b>Throughput</b> (MB/s) <span class="lg"><i style="background:#e1131f"></i>Upload<i style="background:#fff"></i>Download</span></span><span id="ct1">-</span></header><canvas id="c1"></canvas></div>
 <div class="chart"><header><span><b>Latency</b> (ms)</span><span id="ct2">-</span></header><canvas id="c2"></canvas></div>
 <div class="chart wide"><header><span><b>Packet loss</b> (%)</span><span id="ct3">-</span></header><canvas id="c3" style="height:130px"></canvas></div>
</div>
<script>
const NAME=%NAME%;const $=s=>document.getElementById(s);
const fb=b=>b<1024?b.toFixed(0)+' B':b<1048576?(b/1024).toFixed(1)+' KB':b<1073741824?(b/1048576).toFixed(1)+' MB':b<1099511627776?(b/1073741824).toFixed(2)+' GB':(b/1099511627776).toFixed(2)+' TB';
const fm=b=>(b/1048576).toFixed(b/1048576<10?2:1);
function ring(id,f,c){const e=$(id);e.style.strokeDashoffset=377*(1-Math.max(0,Math.min(1,f)));e.style.stroke=c}
function chart(cv,sets,o){const dpr=devicePixelRatio||1,w=cv.clientWidth,h=cv.clientHeight;cv.width=w*dpr;cv.height=h*dpr;const x=cv.getContext('2d');x.scale(dpr,dpr);
 let n=Math.max(...sets.map(s=>s.d.length),2),mx=o.max||Math.max(1e-9,...sets.flatMap(s=>s.d.filter(v=>v!=null)))*1.15;x.strokeStyle='#222';x.fillStyle='#777';x.font='11px system-ui';x.lineWidth=1;
 for(let i=0;i<=3;i++){const y=8+(h-24)*i/3;x.beginPath();x.moveTo(0,y);x.lineTo(w,y);x.stroke();x.fillText(o.fmt(mx*(1-i/3)),4,i?y-3:y+11)}
 sets.forEach(s=>{const base=h-16;let seg=[];const flush=()=>{if(seg.length>1){x.beginPath();seg.forEach((q,i)=>i?x.lineTo(q[0],q[1]):x.moveTo(q[0],q[1]));x.strokeStyle=s.c;x.lineWidth=2;x.lineJoin='round';x.stroke();
   if(s.fill){x.lineTo(seg[seg.length-1][0],base);x.lineTo(seg[0][0],base);x.closePath();x.fillStyle=s.c+'33';x.fill()}}seg=[]};
  s.d.forEach((v,i)=>{if(v==null){flush();return}seg.push([i/(n-1)*w,8+(h-24)*(1-v/mx)])});flush()})}
async function tick(){let d;try{d=await (await fetch('/api/live?name='+encodeURIComponent(NAME),{cache:'no-store'})).json()}catch(e){return}
 if(window.onState)window.onState(d);
 const rt=d.rtt;$('v1').textContent=rt==null?'-':rt.toFixed(rt<10?1:0);ring('r1',rt==null?0:1-Math.min(rt,300)/300,rt==null?'#85857f':rt<80?'#12a150':rt<160?'#e0a100':'#e1131f');
 $('s1').textContent=rt==null?'no reply':rt<80?'excellent':rt<160?'good':'high';
 const q=100-d.loss;$('v2').textContent=q.toFixed(1)+'%';ring('r2',q/100,q>=99?'#12a150':q>=95?'#e0a100':'#e1131f');$('s2').textContent='packet loss '+d.loss.toFixed(1)+'%';
 const tot=d.up+d.down;$('v3').textContent=fm(tot);ring('r3',Math.min(1,tot/104857600),'#e1131f');$('u3').textContent='MB/s';$('s3').textContent='up '+fm(d.up)+'  down '+fm(d.down)+' MB/s';
 const t=d.uptime,days=Math.floor(t/86400);$('v4').textContent=days>0?days+'d':Math.floor(t/3600)+'h';$('u4').textContent=days>0?Math.floor(t%86400/3600)+'h '+Math.floor(t%3600/60)+'m':Math.floor(t%3600/60)+'m';ring('r4',Math.min(1,t/2592000),d.state=='connected'?'#12a150':'#85857f');
 $('s4').textContent='total traffic '+fb(d.tot_up+d.tot_down)+' ('+d.src+')';
 const s=d.series;chart($('c1'),[{d:s.down,c:'#ffffff'},{d:s.up,c:'#e1131f',fill:1}],{fmt:v=>fm(v)+' MB/s'});$('ct1').textContent='up '+fb(d.tot_up)+'  down '+fb(d.tot_down);
 chart($('c2'),[{d:s.rtt,c:'#ffffff',fill:1}],{fmt:v=>v.toFixed(0)+' ms'});$('ct2').textContent=rt==null?'no reply':rt.toFixed(1)+' ms';
 chart($('c3'),[{d:s.loss,c:'#e1131f',fill:1}],{max:Math.max(5,...s.loss),fmt:v=>v.toFixed(0)+'%'});$('ct3').textContent=d.loss.toFixed(1)+'% now'}
tick();setInterval(tick,2000);addEventListener('resize',tick);
</script>"""
def live_block(name): return LIVE.replace("%NAME%", json.dumps(name))

def page(name, body, msg=""): return render_template_string(BASE, page=name, body=body, msg=msg)
def R(tpl, **k): return render_template_string(tpl, **k)
def catalog(): return [l.split("|")[:4] for l in emad("catalog").splitlines() if l.count("|") >= 3]

@app.route("/login", methods=["GET", "POST"])
def login():
    ip = request.remote_addr; f = FAILS.get(ip, (0, 0)); err = ""
    if request.method == "POST":
        c = load()
        if f[0] >= 5 and time.time() - f[1] < 300: err = "Too many attempts. Wait 5 minutes."
        elif hmac.compare_digest(request.form.get("u", ""), c.get("user", "")) and pcheck(request.form.get("p", ""), c.get("pass", "")):
            session.clear(); session["u"] = 1; FAILS.pop(ip, None); return redirect("/")
        else: FAILS[ip] = (f[0] + 1 if time.time() - f[1] < 300 else 1, time.time()); err = "Wrong username or password."
    return R(LOGIN, err=err)
@app.route("/logout", methods=["POST"])
def logout(): session.clear(); return redirect("/login")
@app.route("/api/live")
def api_live(): return jsonify(live(request.args.get("name", "all")))

@app.route("/")
def dash():
    tl = tlist(); sel = request.args.get("name", "all")
    body = R("""<div class="top"><div><h1 class="serif">Overview</h1><p class="sub" style="margin:6px 0 0">{{os}}  |  <span class="mono">{{ip}}</span>  |  server up {{up}}</p></div>
<form method="get"><select name="name" onchange="this.form.submit()" style="min-width:210px"><option value="all">All tunnels ({{n}})</option>{% for t in tl %}<option value="{{t.NAME}}" {{'selected' if t.NAME==sel}}>{{t.NAME}}  ({{t.TYPE}})</option>{% endfor %}</select></form></div>""",
             os=osname(), ip=emad("ip"), up=uptime(), n=len(tl), tl=tl, sel=sel)
    return page("dash", body + (live_block(sel) if tl else '<p>No tunnels yet. <a href="/new">Create the first one.</a></p>'))

def rate_html(n):
    r = RANK.get(n)
    if not r or r["score"] == 0: return '<span class="mono" style="color:#85857f">-</span>'
    return star_html(r["stars"], r.get("gold", False)) + ('<span class="gold-tag">BEST FOR THIS SERVER</span>' if r.get("gold") else "")
RANK = {}
app.jinja_env.globals["rate_html"] = lambda n: markupsafe.Markup(rate_html(n))
@app.route("/tun")
def tun():
    global RANK
    RANK = {r["c"]["NAME"]: r for r in ranked()}
    rows = []
    for c in tlist():
        h = HIST.get(c["NAME"]); rtt = h[-1]["rtt"] if h else None; st, _ = conn_state(c, rtt); rows.append((c, st, rtt))
    body = R("""<div class="top"><div><h1 class="serif">Tunnels</h1><p class="sub" style="margin:6px 0 0">Open a tunnel for live status, charts and editing.</p></div><a class="btn red" href="/new">New tunnel</a></div>
{% if not rows %}<p>No tunnels yet.</p>{% else %}<table><tr><th>Name</th><th>Type</th><th>Role</th><th>Other server</th><th>Ports</th><th>Connection</th><th>Ping</th><th>Rating</th><th></th></tr>
{% for c,st,rtt in rows %}<tr><td><a href="/tun/{{c.NAME}}"><b>{{c.NAME}}</b></a></td><td>{{c.TYPE}}</td><td>{{c.ROLE}}</td><td class="mono">{{c.REMOTE}}</td><td class="mono">{{c.PORTS[:20]}}</td>
<td><span class="dot {{'ok' if st=='connected' else 'off' if st=='stopped' else ''}}"></span> {{st}}</td><td class="mono">{{'%.0f ms'%rtt if rtt is not none else '-'}}</td><td>{{ rate_html(c.NAME) }}</td><td><div class="row">
<a class="btn sm" href="/tun/{{c.NAME}}">Status and edit</a>{% for a in ['start','stop','restart'] %}<form class="inl" method="post" action="/act/{{c.NAME}}/{{a}}"><input type="hidden" name="t" value="{{csrf()}}"><button class="btn sm">{{a|capitalize}}</button></form>{% endfor %}</div></td></tr>{% endfor %}</table>{% endif %}""", rows=rows)
    return page("tun", body, request.args.get("m", ""))
@app.route("/act/<n>/<a>", methods=["POST"])
def doact(n, a):
    if a not in ("start", "stop", "restart", "delete"): abort(404)
    ok = emad("act", a, n).startswith("OK")
    return redirect(("/tun" if a == "delete" else "/tun/" + n) + "?m=" + n + ": " + a + (" done" if ok else " failed"))


@app.route("/api/log/<n>")
def api_log(n):
    if not tconf(n): abort(404)
    out = sh("journalctl", "-u", "emad-" + n, "-n", "60", "--no-pager", "-o", "short-iso", t=8).strip().splitlines()
    c = tconf(n); st, _ = conn_state(c, (HIST[n][-1]["rtt"] if n in HIST and HIST[n] else None))
    lines = [{"t": "log", "m": l} for l in out[-60:]] or [{"t": "d", "m": "no log lines yet"}]
    lines.append({"t": "d", "m": "state: %s, service: %s" % (st, svc(n))})
    return jsonify(lines=lines)
@app.route("/api/packets/<n>")
def api_packets(n):
    c = tconf(n)
    if not c: abort(404)
    i, _ = src_iface(c)
    if not sh("sh", "-c", "command -v tcpdump"): return jsonify(lines=[{"t": "y", "m": "tcpdump is not installed. Run: apt-get install -y tcpdump"}])
    o = sh("timeout", "2", "tcpdump", "-l", "-n", "-q", "-c", "25", "-i", i, t=6)
    lines = []
    for l in o.splitlines()[:25]:
        t = "r" if ("unreach" in l or "RST" in l or "ICMP" in l) else "g"
        lines.append({"t": t, "m": l[:160]})
    return jsonify(lines=lines or [{"t": "d", "m": "no packets in the last 2 seconds on %s" % i}])
@app.route("/api/tune", methods=["POST"])
def api_tune():
    r = emad("tune"); return jsonify(ok=r.startswith("OK"), out=r)


PANELS = {
 "sanaei": {"name": "Sanaei (3x-ui)", "badge": "S", "color": "#e1131f", "steps": [
   ("ورود به پنل", "وارد پنل Sanaei (3x-ui) شو و از منوی سمت چپ گزینه <b>Xray Configs</b> یا <b>Outbounds</b> رو باز کن."),
   ("افزودن Outbound", "روی <b>Add Outbound</b> بزن. <b>Protocol</b> را <code>socks</code> انتخاب کن (یا <code>http</code> اگه تانل HTTP داره)."),
   ("تنظیم آدرس", "در بخش <b>Address</b> بنویس <code>{endpoint_host}</code> و در <b>Port</b> بنویس <code>{endpoint_port}</code>. اگه پنل روی همین سرور ایرانه، به‌جای IP بنویس <code>127.0.0.1</code>."),
   ("ذخیره و اعمال", "Outbound رو با یه <b>Tag</b> دلخواه مثل <code>{name}</code> ذخیره کن و تنظیمات Xray رو <b>Restart</b> کن."),
   ("مسیریابی (Routing)", "از بخش <b>Routing Rules</b> یه قانون اضافه کن که <b>outboundTag</b> اون <code>{name}</code> باشه و <b>inboundTag</b> یا <b>domain/ip</b> ترافیکی که می‌خوای از تانل بره."),
   ("تست", "از کلاینت (مثلاً v2rayNG یا Nekobox) به این پنل وصل شو و سایتی رو باز کن. اگه باز شد، تانل درست کار می‌کنه."),
 ]},
 "pasargad": {"name": "Pasarguard", "badge": "P", "color": "#000000", "steps": [
   ("ورود به پنل", "وارد پنل پاسارگارد شو و به بخش <b>Outbounds</b> یا <b>Xray Config</b> برو."),
   ("افزودن Outbound", "یه Outbound جدید بساز. <b>Protocol</b> را <code>socks</code> بذار (یا <code>http</code>)."),
   ("تنظیم آدرس", "<b>Address</b> را <code>{endpoint_host}</code> و <b>Port</b> را <code>{endpoint_port}</code> بذار. روی همین سرور ایران <code>127.0.0.1</code> بنویس."),
   ("ذخیره و Restart", "با یه <b>Tag</b> مثل <code>{name}</code> ذخیره کن و سرویس Xray رو Restart کن."),
   ("Routing", "در بخش Routing، برای ترافیکی که می‌خوای از تانل بره، <b>outboundTag</b> را <code>{name}</code> بذار."),
   ("تست", "یه کلاینت به پنل وصل کن و یه سایت باز کن تا مطمئن شی ترافیک از تانل رد می‌شه."),
 ]},
 "marzban": {"name": "Marzban", "badge": "M", "color": "#e1131f", "steps": [
   ("ویرایش فایل کانفیگ", "روی سرور پنل، فایل <code>xray_config.json</code> رو باز کن (معمولاً در مسیر <code>/opt/marzban</code> یا از داخل داشبورد بخش Xray Config)."),
   ("اضافه کردن Outbound", "داخل آرایه <b>outbounds</b> یه آیتم جدید اضافه کن با <code>&quot;tag&quot;: &quot;{name}&quot;</code> و <code>&quot;protocol&quot;: &quot;socks&quot;</code>."),
   ("تنظیم سرور", "داخل <b>settings</b> → <b>servers</b> بنویس <code>&quot;address&quot;: &quot;{endpoint_host}&quot;</code> و <code>&quot;port&quot;: {endpoint_port}</code>."),
   ("Routing", "در <b>routing.rules</b> یه قانون اضافه کن با <code>&quot;outboundTag&quot;: &quot;{name}&quot;</code> و شرط دامنه یا IP که می‌خوای."),
   ("ذخیره و ری‌استارت", "فایل رو ذخیره کن و از داشبورد یا با <code>marzban restart</code> سرویس رو ری‌استارت کن."),
   ("تست", "یه کاربر تست بساز، کانفیگش رو به کلاینت بده و سایتی رو باز کن."),
 ]},
}
def panel_guide_html(c, key):
    p = PANELS[key]; mip = emad("ip") or "127.0.0.1"
    port = (c.get("PORTS") or "1").split(",")[0].split("-")[0]
    host = mip if c.get("ROLE") == "iran" else c.get("REMOTE", mip)
    subs = {"endpoint_host": host, "endpoint_port": port, "name": c["NAME"]}
    def fill(t):
        for k, v in subs.items(): t = t.replace("{" + k + "}", str(v))
        return t
    steps = "".join('<div class="stp"><div class="sn">%d</div><div><h3>%s</h3><p>%s</p></div></div>' % (i + 1, t, fill(d)) for i, (t, d) in enumerate(p["steps"]))
    return """<!doctype html><html lang="fa" dir="rtl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>%(name)s guide</title>
<style>:root{--w:#fff;--k:#000;--r:#e1131f}*{box-sizing:border-box}body{margin:0;font:15px/1.9 Vazirmatn,Tahoma,system-ui,sans-serif;background:#f4f4f2;color:var(--k)}
header{background:var(--k);color:#fff;padding:26px 22px;border-bottom:3px solid var(--r)}header h1{margin:0;font-size:24px}header p{margin:6px 0 0;color:#c8c8c4}
.bdg{display:inline-flex;width:40px;height:40px;border-radius:50%%;align-items:center;justify-content:center;background:var(--r);color:#fff;font-weight:700;margin-left:10px;vertical-align:middle}
main{max-width:860px;margin:0 auto;padding:22px}.box{background:var(--w);border-radius:16px;padding:18px 20px;margin-bottom:16px;box-shadow:0 10px 26px #0000001a}
.box h2{margin:0 0 6px;font-size:17px}.stp{display:flex;gap:14px;background:var(--w);border-radius:14px;padding:16px 18px;margin-bottom:12px;border-right:4px solid var(--r);box-shadow:0 6px 18px #0000000f}
.stp h3{margin:0;font-size:16px}.stp p{margin:4px 0 0}.sn{flex:none;width:36px;height:36px;border-radius:50%%;background:var(--k);color:#fff;display:flex;align-items:center;justify-content:center;font-weight:700}
code{background:#f0f0ee;padding:2px 8px;border-radius:6px;direction:ltr;display:inline-block;font:13px ui-monospace,Consolas,monospace;color:#000}
.val{display:flex;flex-wrap:wrap;gap:8px}.val span{background:var(--k);color:#fff;padding:6px 12px;border-radius:99px;font-size:14px}.val b{color:#ff8a90;font-weight:600;margin-left:6px}
.note{border-right:4px solid var(--r);padding:10px 14px;background:#fff5f5;border-radius:10px;margin-top:14px}
footer{text-align:center;color:#8f8f8b;font-size:13px;padding:18px}footer a{color:var(--k)}
</style></head><body>
<header><span class="bdg">%(badge)s</span><span style="font-size:24px;font-weight:600">آموزش اجرای تانل روی پنل %(name)s</span>
<p>تانل <b>%(tname)s</b> (%(ttype)s) — Em4dloverS Tunnel</p></header>
<main>
<div class="box"><h2>مقادیر شما</h2><div class="val"><span><b>Tunnel</b>%(tname)s</span><span><b>Endpoint</b>%(host)s:%(port)s</span><span><b>Type</b>%(ttype)s</span></div>
<div class="note">اگه پنل روی همین سرور ایرانه، Address را <code>127.0.0.1</code> بذار و پورت را همان <code>%(port)s</code> نگه دار.</div></div>
%(steps)s
<div class="box"><h2>اگه کار نکرد</h2><p>اول مطمئن شو تانل در پنل Em4dloverS وضعیت <b>Connected</b> (سبز) داره. بعد پورت‌ها در فایروال ارائه‌دهنده باز باشن. در آخر لاگ تانل رو از صفحه‌ی تانل ببین.</p></div>
</main><footer>Em4dloverS Tunnel &nbsp;|&nbsp; <a href="https://t.me/Em4dloverS">t.me/Em4dloverS</a> &nbsp;|&nbsp; <a href="https://t.me/KaMr4ng">t.me/KaMr4ng</a></footer></body></html>""" % {
     "name": p["name"], "badge": p["badge"], "tname": c["NAME"], "ttype": c.get("TYPE", ""), "host": host, "port": port, "steps": steps}

@app.route("/tun/<n>/guide/<panel>")
def tguide(n, panel):
    c = tconf(n) if n.replace("-", "").replace("_", "").isalnum() else None
    if not c or panel not in PANELS: abort(404)
    return panel_guide_html(c, panel)

@app.route("/tun/<n>")
def tdetail(n):
    c = tconf(n) if n.replace("-", "").replace("_", "").isalnum() else None
    if not c: abort(404)
    body = R("""<div class="top"><div><h1 class="serif">{{c.NAME}}</h1><p class="sub" style="margin:6px 0 0">{{c.TYPE}}  |  {{c.ROLE}}  |  {{c.LOCAL}} to {{c.REMOTE}}</p></div>
<div class="row"><span class="pill"><span class="dot off" id="dotc"></span><span id="stc">checking</span></span><button class="btn" id="chk">{{ico('ref')}}Check now</button>
{% for a in ['start','stop','restart'] %}<form class="inl" method="post" action="/act/{{c.NAME}}/{{a}}"><input type="hidden" name="t" value="{{csrf()}}"><button class="btn">{{a|capitalize}}</button></form>{% endfor %}
<form class="inl" method="post" action="/act/{{c.NAME}}/delete" onsubmit="return confirm('Delete {{c.NAME}}?')"><input type="hidden" name="t" value="{{csrf()}}"><button class="btn danger">Delete</button></form></div></div>
<div class="kv" id="kv"><div><small>Connection</small><b id="k1">-</b></div><div><small>Detail</small><b id="k2" style="font-weight:500">Press Check now</b></div><div><small>Ping (4 packets)</small><b id="k3">-</b></div><div><small>Packet loss</small><b id="k4">-</b></div><div><small>Service</small><b id="k5">-</b></div></div>""", c=c)
    body += live_block(n)
    body += R("""<script>
function setS(s){const m={connected:['ok','Connected'],disconnected:['','Disconnected'],stopped:['off','Stopped']}[s]||['off',s];$('dotc').className='dot '+m[0];$('stc').textContent=m[1]}
window.onState=d=>setS(d.state);
async function chk(){const b=$('chk');b.disabled=true;try{const d=await (await fetch('/api/check/{{c.NAME}}',{cache:'no-store'})).json();setS(d.state);$('k1').textContent=d.state;$('k2').textContent=d.detail;$('k3').textContent=d.rtt==null?'no reply':d.rtt+' ms';$('k4').textContent=d.loss+'%';$('k5').textContent=d.service}finally{b.disabled=false}}
$('chk').onclick=chk;chk();
let pk=false;
function esc(t){return t.replace(/[&<>]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]))}
function paint(lines){const b=$('lg');b.innerHTML=lines.map(l=>'<div class="'+(l.t=='log'?'':l.t)+'">'+esc(l.m)+'</div>').join('');b.scrollTop=b.scrollHeight}
async function loadLog(){try{paint((await (await fetch('/api/log/{{c.NAME}}',{cache:'no-store'})).json()).lines)}catch(e){}}
async function pkts(){if(!pk)return;try{const d=await (await fetch('/api/packets/{{c.NAME}}',{cache:'no-store'})).json();paint(d.lines)}catch(e){}}
async function tune(){const t=$('tuneb');t.disabled=true;$('tuner').textContent='optimizing...';try{const fd=new FormData();fd.append('t','{{csrf()}}');const d=await (await fetch('/api/tune',{method:'POST',body:fd})).json();$('tuner').textContent=d.ok?'done: '+d.out:'failed'}finally{t.disabled=false}}
loadLog();setInterval(loadLog,4000);setInterval(pkts,2000);
</script>
<h2 class="serif">Panel setup guide</h2><p class="sub" style="margin-top:0">Pick your panel. The guide opens in Persian with the values of this tunnel filled in.</p>
<div class="row" style="margin-bottom:24px">{% for k,lbl,col in [('sanaei','Sanaei (3x-ui)','#e1131f'),('pasargad','Pasarguard','#000'),('marzban','Marzban','#e1131f')] %}<a class="btn" href="/tun/{{c.NAME}}/guide/{{k}}" target="_blank" style="border-color:{{col}}"><span style="display:inline-flex;width:22px;height:22px;border-radius:50%;background:{{col}};color:#fff;align-items:center;justify-content:center;font-size:12px;font-weight:700">{{lbl[0]}}</span>{{lbl}}</a>{% endfor %}</div>
<h2 class="serif">Live log and packets</h2>
<div class="row" style="margin-bottom:10px"><button class="btn" onclick="pk=!pk;this.textContent=pk?'Pause packets':'Live packets'">Live packets</button><button class="btn" onclick="loadLog()">Refresh log</button></div>
<div class="logbox" id="lg"></div>
<h2 class="serif">Optimize this server</h2><p class="sub" style="margin-top:0">Applies BBR, buffers and the best MTU for each kernel tunnel on this server. Safe to run again.</p>
<button class="btn red" id="tuneb" onclick="tune()">Optimize now</button> <span id="tuner" class="mono" style="margin-left:10px;color:var(--g3)"></span>
<h2 class="serif">Edit tunnel</h2><p class="sub" style="margin-top:0">Saving restarts this tunnel. Apply the same changes on the other server. Type {{c.TYPE}}, role {{c.ROLE}} and ID {{c.IDX}} are fixed. Delete and recreate to change them.</p>
<form method="post" action="/tun/{{c.NAME}}/edit" class="grid"><input type="hidden" name="t" value="{{csrf()}}">
<div><label>Other server IP</label><input name="remote" value="{{c.REMOTE}}" required></div><div><label>This server IP</label><input name="local" value="{{c.LOCAL}}" required></div>
{% if c.PORTS != '1' %}<div><label>Ports (add or remove: 80,443,2000-2100)</label><input name="ports" value="{{c.PORTS}}" required></div>{% endif %}
{% if c.CPORT %}<div><label>Control port</label><input name="cport" type="number" value="{{c.CPORT}}"></div><div><label>Token</label><input name="token" value="{{c.TOKEN}}"></div>{% endif %}
{% if c.TYPE=='wg' %}<div><label>WireGuard peer public key</label><input name="peer" value="{{c.PEER}}"></div>{% endif %}
<div style="align-self:end"><button class="btn red" style="padding:12px 22px">Save and restart</button></div></form>""", c=c)
    return page("tun", body, request.args.get("m", ""))
@app.route("/tun/<n>/edit", methods=["POST"])
def tedit(n):
    if not tconf(n): abort(404)
    kv = ["%s=%s" % (k, request.form.get(k, "").strip()) for k in ("remote", "local", "ports", "cport", "token", "peer") if k in request.form]
    r = emad("edit", n, *kv); return redirect("/tun/%s?m=%s" % (n, "Saved and restarted." if r.startswith("OK") else "Not saved: " + r.replace("ERR ", "")))
@app.route("/api/check/<n>")
def api_check(n):
    c = tconf(n)
    if not c: abort(404)
    s = svc(n); rtt, loss = ping(peer_ip(c), 4) if s == "active" else (None, 100.0); st, d = conn_state(c, rtt)
    return jsonify(state=st, detail=d, rtt=rtt, loss=loss, service=s)


JOB_PAGE = """<h1 class="serif">Installing tools</h1><p class="sub">Tools for this tunnel type are installed automatically. You can leave this page; the work continues on the server.</p>
<div class="jobbox" id="jb"><div class="jrow"><span class="jspin"></span><span>Starting</span></div></div>
<div class="row" style="margin-top:18px"><a class="btn" href="/tun">Go to tunnels</a></div>
<style>.jobbox{max-width:760px;border:1px solid var(--g2);border-radius:16px;padding:10px 6px}
.jrow{display:flex;align-items:center;gap:14px;padding:12px 16px;border-bottom:1px solid var(--g2)}.jrow:last-child{border-bottom:0}
.jspin{width:20px;height:20px;border-radius:50%;border:3px solid var(--g2);border-top-color:var(--rd);animation:spin .8s linear infinite;flex:none}
@keyframes spin{to{transform:rotate(360deg)}}
.jok{width:20px;height:20px;border-radius:50%;background:var(--ok);flex:none;display:flex;align-items:center;justify-content:center}
.jok svg{width:12px;height:12px}.jok path{fill:none;stroke:#fff;stroke-width:3;stroke-linecap:round;stroke-linejoin:round;stroke-dasharray:24;stroke-dashoffset:24;animation:draw .5s forwards}
.jfail{width:20px;height:20px;border-radius:50%;background:var(--rd);color:#fff;font-weight:700;font-size:13px;display:flex;align-items:center;justify-content:center;flex:none}
.jdone{padding:14px 16px;font-weight:600}</style>
<script>
const jid="__JID__";
function row(s,m){if(s=='run')return '<div class="jrow"><span class="jspin"></span><span>'+m+'</span></div>';
 if(s=='ok')return '<div class="jrow"><span class="jok"><svg viewBox="0 0 12 12"><path d="M2 6.5 L5 9 L10 3"/></svg></span><span>'+m+'</span></div>';
 if(s=='fail')return '<div class="jrow"><span class="jfail">x</span><span style="color:#e1131f">'+m+'</span></div>';return '';}
async function poll(){try{const d=await (await fetch('/api/job/'+jid,{cache:'no-store'})).json();
 let h=d.steps.map(x=>row(x.s,x.m)).join('');
 if(d.done){h+='<div class="jdone">'+(d.result.startsWith('OK')?'Tunnel created and started.':'Result: '+d.result)+'</div>';}
 document.getElementById('jb').innerHTML=h||row('run','Starting');
 if(!d.done)setTimeout(poll,700);}catch(e){setTimeout(poll,1500)}}
poll();
</script>"""
@app.route("/job/<jid>")
def job(jid):
    if not re.fullmatch(r"j[0-9a-f]{12}", jid): abort(404)
    return page("new", JOB_PAGE.replace("__JID__", jid))
@app.route("/api/job/<jid>")
def api_job(jid):
    if not re.fullmatch(r"j[0-9a-f]{12}", jid): abort(404)
    f = os.path.join(CONF, "jobs", jid + ".log")
    if not os.path.exists(f): abort(404)
    steps, done, result = [], False, ""
    for l in open(f, encoding="utf-8", errors="replace").read().splitlines():
        if "|" not in l: continue
        s, m = l.split("|", 1)
        if s == "done": done, result = True, m
        elif s in ("run", "ok", "fail"): steps.append({"s": s, "m": m})
    return jsonify(steps=steps, done=done, result=result)

def start_job(name, typ, role, local, remote, ports, cport, token, idx, peer):
    jid = "j" + secrets.token_hex(6); jdir = os.path.join(CONF, "jobs"); os.makedirs(jdir, exist_ok=True)
    jf = os.path.join(jdir, jid + ".log"); open(jf, "w").write("run|Starting\n")
    args = [EMAD, "api", "create"] + [str(x) for x in (name, typ, role, local, remote, ports, cport, token, idx, peer)]
    subprocess.Popen(args, env=dict(os.environ, EMAD_JOB=jf), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    return jid

@app.route("/new", methods=["GET", "POST"])
def new():
    msg = ""
    if request.method == "POST":
        f = request.form; g = lambda k, d="": f.get(k, d).strip()
        if g("mode") == "pair":
            BH = ("tcp", "tcpudp", "udp", "tcpmux", "ws", "wsmux", "wss")
            t1 = g("t1") if g("t1") in BH else "tcp"; t2 = g("t2") if g("t2") in BH else ""
            base = g("name"); cp = int(g("cport") or 33001); specs = []
            if g("role") == "foreign":
                if t1: specs.append((base + "-" + t1, "backhaul-" + t1, "1", cp))
                if t2 and t2 != t1: specs.append((base + "-" + t2, "backhaul-" + t2, "1", cp + 1))
            else:
                if g("tcp_ports"): specs.append((base + "-" + t1, "backhaul-" + t1, g("tcp_ports"), cp))
                if g("udp_ports") and t2: specs.append((base + "-" + t2, "backhaul-" + t2, g("udp_ports"), cp + 1))
            if not specs: msg = "Enter at least one port group."
            else:
                for n, typ, ports, c in specs: start_job(n, typ, g("role"), g("local"), g("remote"), ports, c, g("token"), g("idx"), "")
                return redirect("/tun?m=" + str(len(specs)) + " tunnel(s) started. Check the list below.")
        else:
            jid = start_job(g("name"), g("type"), g("role"), g("local"), g("remote"), g("ports") or "1", g("cport") or "0", g("token"), g("idx"), g("peer"))
            return redirect("/job/" + jid)
    body = R("""<h1 class="serif">New tunnel</h1><p class="sub">Run this form on both servers. Use the same ID, control port and token on each side.</p>
<form method="post" class="grid"><input type="hidden" name="t" value="{{csrf()}}">
<div><label>Mode</label><select id="md" name="mode"><option value="single">Single tunnel</option><option value="pair">TCP + UDP pair</option></select></div>
<div class="pr" style="display:none"><label>Group 1 transport (Backhaul)</label><select name="t1"><option value="tcp">tcp</option><option value="tcpudp">tcpudp</option><option value="tcpmux">tcpmux</option><option value="udp">udp</option><option value="ws">ws</option><option value="wsmux">wsmux</option><option value="wss">wss</option></select></div>
<div class="pr" style="display:none"><label>Group 2 transport (Backhaul, optional)</label><select name="t2"><option value="">none</option><option value="tcp">tcp</option><option value="tcpudp">tcpudp</option><option value="tcpmux">tcpmux</option><option value="udp">udp</option><option value="ws">ws</option><option value="wsmux">wsmux</option><option value="wss">wss</option></select></div>
<div class="pr" style="display:none"><label>Group 1 ports (e.g. 443,80)</label><input name="tcp_ports" placeholder="443,80"></div>
<div class="pr" style="display:none"><label>Group 2 ports (e.g. 2000-2100)</label><input name="udp_ports" placeholder="2000-2100"></div>

<div id="tyw" style="grid-column:1/-1"><label>Tunnel type (42 types, grouped)</label><select name="type" required>{% for g in groups %}<optgroup label="{{g}}">{% for c in cat if c[3]==g %}<option value="{{c[0]}}">{{c[1]}}  -  {{c[2]}}</option>{% endfor %}</optgroup>{% endfor %}</select></div>
<div><label>Name</label><input name="name" pattern="[a-z0-9_-]{1,24}" placeholder="t1" required></div>
<div><label>This server is</label><select id="rl" name="role"><option value="iran">ایران (ورودی، پورت‌ها اینجا)</option><option value="foreign">خارج (خروجی، پورت لازم نیست)</option></select></div>
<div><label>This server IP</label><input name="local" value="{{ip}}" required></div><div><label>Other server IP</label><input name="remote" required></div>
<div id="pw"><label>Ports (80,443,2000-2100)</label><input id="pi" name="ports" value="443"></div><div><label>Tunnel ID (1-250)</label><input name="idx" type="number" min="1" max="250" value="1" required></div>
<div><label>Control port (proxy-based types)</label><input name="cport" type="number" value="33001"></div><div><label id="tl">Token</label><div class="row" style="flex-wrap:nowrap"><input id="ti" name="token" value="{{tok}}" autocomplete="off" style="font-family:ui-monospace,Consolas,monospace"><button type="button" class="btn sm" id="tc">Copy</button></div><small id="th" style="color:#85857f"></small></div>
<div><label>WireGuard peer public key (optional)</label><input name="peer"></div>
<div style="align-self:end"><button class="btn red" style="padding:12px 22px">Create and start</button></div></form><script>
const rl=document.getElementById("rl"),pw=document.getElementById("pw"),ti=document.getElementById("ti"),tl=document.getElementById("tl"),th=document.getElementById("th"),tc=document.getElementById("tc"),md=document.getElementById("md"),tyw=document.getElementById("tyw");
const TOK=ti.value;
function sw(){const f=rl.value=="foreign",p=md.value=="pair";
 document.querySelectorAll(".pr").forEach(e=>e.style.display=p?"":"none");
 tyw.style.display=p?"none":"";
 pw.style.display=(f||p)?"none":"";
 if(f){ti.value="";ti.placeholder="Paste the token from the Iran server";tl.textContent="Token from the Iran server";th.textContent="Paste the token that the Iran server created. It must match exactly.";tc.style.display="none";}
 else{ti.value=TOK;tl.textContent="Token (create on this Iran server, then copy it to the foreign server)";th.textContent="Shown once here. Copy it now and paste it on the foreign server.";tc.style.display="";}
 if(p&&!f){document.querySelector('[name=which]').closest(".pr").style.display="none";}
}
rl.onchange=sw;md.onchange=sw;sw();
tc.onclick=()=>{navigator.clipboard&&navigator.clipboard.writeText(ti.value);tc.textContent="Copied";setTimeout(()=>tc.textContent="Copy",1500)};
</script>""", cat=catalog(), groups=sorted({c[3] for c in catalog()}), ip=emad("ip"), tok="".join(secrets.choice(string.ascii_letters + string.digits) for _ in range(40)))
    return page("new", body, msg)


HOWTO = [
 ("GRE", "Kernel tunnel. The Iran server creates a point-to-point interface with a /30 address (10.N.0.1 and 10.N.0.2). Chosen ports are forwarded with DNAT to the foreign side through that interface. Fast and simple, but it uses IP protocol 47, which some networks block. Variants: GRE-TAP (layer 2), IPv6 GRE, and FOU/GUE, which wrap GRE in UDP so it passes NAT and UDP filters.", "Needs: kernel modules ip_gre and fou. Does not work inside OpenVZ or LXC."),
 ("FRP", "Reverse proxy. The foreign server runs frpc and connects outward to frps on the Iran server (control port + token). The Iran server then publishes each port to users. Transports: TCP, KCP (UDP, good on lossy links), QUIC, and WebSocket (passes HTTP-only networks).", "Needs: frps and frpc binaries. Outbound connection starts from the foreign side."),
 ("Backhaul", "Reverse tunnel. The Iran server listens on the control port; the foreign client connects out and multiplexes the forwarded ports over one connection. Transports: TCP, TCPMux (many streams on one TCP), UDP, WebSocket and WSMux.", "Needs: backhaul binary. Foreign side connects out, so no inbound port is needed there."),
 ("Rathole", "Reverse tunnel written in Rust. The Iran server exposes the service ports; the foreign client connects out with a token. Very low overhead, TCP only.", "Needs: rathole binary."),
 ("GOST", "Relay. GOST runs on both ends. The Iran side listens on the chosen ports and sends traffic through a GOST chain to the foreign GOST server. Relay mode forwards ports; SOCKS5 mode gives a proxy. Each transport (TCP, TLS, MTLS, WS, MWS, WSS, MWSS, H2, H2C, QUIC, KCP, gRPC) is a separate type.", "Needs: gost binary. Pick TLS or WSS on filtered networks; KCP or QUIC on lossy links."),
]
@app.route("/howto")
def howto():
    cards = "".join('<div class="fam"><h3>%s</h3><p>%s</p><p class="mono" style="color:#85857f">%s</p></div>' % (n, d, r) for n, d, r in HOWTO)
    body = '<div class="howto"><h1 class="serif">How each tunnel works</h1><p class="sub">Short, accurate notes for the five families this server supports. Exact behavior follows the generated scripts on the server.</p>' + cards + '</div>'
    return page("how", body)

@app.route("/stat")
def stat():
    rows = [l.split("|") for l in emad("status", t=120).splitlines() if l.count("|") == 2]
    body = R("""<div class="top"><div><h1 class="serif">Compatibility</h1><p class="sub" style="margin:6px 0 0">Which tunnel types this server can run. 4 of 4 means fully supported.</p></div></div>
<div class="cgrid">{% for t,n,s in rows %}{% set s=s|int %}
<div class="cc {{'full' if s==4 else 'part' if s==3 else 'no'}}"><div class="ctop"><b>{{n}}</b>
{% if s==4 %}<span class="tick"><svg viewBox="0 0 52 52"><circle cx="26" cy="26" r="24"/><path d="M14 27 l8 8 l16-17"/></svg></span>{% endif %}</div>
<div class="seg {{'' if s==4 else 'y' if s==3 else 'r'}}">{% for i in range(4) %}<i class="{{'f' if i<s}}" style="animation-delay:{{i*90}}ms"></i>{% endfor %}</div>
<div class="cs">{% if s==4 %}<span class="ok">OK for this tunnel ({{s}}/4)</span>{% elif s==3 %}<span class="wn">Partly supported ({{s}}/4)</span>{% else %}<span class="no-t blink">Tunnel does not fit this server ({{s}}/4)</span>{% endif %}</div></div>{% endfor %}</div>""", rows=rows)
    return page("stat", body)

@app.route("/set", methods=["GET", "POST"])
def settings():
    msg = ""; c = load()
    if request.method == "POST":
        u, p = request.form.get("u", "").strip(), request.form.get("p", "")
        if len(u) >= 3 and len(p) >= 8 and pcheck(request.form.get("old", ""), c.get("pass", "")):
            c["user"] = u; c["pass"] = phash(p); save(c); msg = "Login updated."
        else: msg = "Check the current password. New username needs 3+ characters and password 8+."
    body = R("""<h1 class="serif">Settings</h1><p class="sub">Panel address: <span class="mono">{{addr}}</span>. For a domain with SSL use option 6 then 7 in the emad menu.</p>
<form method="post" class="grid"><input type="hidden" name="t" value="{{csrf()}}"><div><label>Current password</label><input name="old" type="password" required></div>
<div><label>New username</label><input name="u" value="{{u}}" required></div><div><label>New password</label><input name="p" type="password" minlength="8" required></div>
<div style="align-self:end"><button class="btn red" style="padding:12px 22px">Save login</button></div></form>""", addr=url(emad("ip")), u=c.get("user", ""))
    return page("set", body, msg)

if __name__ == "__main__":
    c = load(); kw = {}
    if c.get("cert") and os.path.exists(c["cert"]): kw["ssl_context"] = (c["cert"], c["key"])
    app.run(host=os.environ.get("EMAD_HOST", "0.0.0.0"), port=int(os.environ.get("EMAD_PORT", c.get("port", 8443))), threaded=True, **kw)
