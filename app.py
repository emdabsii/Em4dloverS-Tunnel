#!/usr/bin/env python3
# Em4dloverS Tunnel Panel  |  t.me/Em4dloverS
import os, sys, json, hashlib, hmac, secrets, subprocess, time
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

if __name__ == "__main__" and len(sys.argv) > 1 and sys.argv[1] in ("set", "url"):
    if sys.argv[1] == "url": print(url(sys.argv[2] if len(sys.argv) > 2 else "127.0.0.1")); sys.exit(0)
    c = load()
    for kv in sys.argv[2:]:
        k, v = kv.split("=", 1)
        if k == "pass": c["pass"] = phash(v)
        elif k in ("port", "user", "domain", "cert", "key"): c[k] = int(v) if k == "port" else v
    c.setdefault("secret", secrets.token_hex(32)); save(c); sys.exit(0)

from flask import Flask, request, session, redirect, render_template_string, abort

app = Flask(__name__)
_c = load()
app.secret_key = _c.get("secret", secrets.token_hex(32))
app.config.update(SESSION_COOKIE_HTTPONLY=True, SESSION_COOKIE_SAMESITE="Lax", SESSION_COOKIE_SECURE=bool(_c.get("cert")))
FAILS = {}

def emad(*a, t=300):
    try:
        r = subprocess.run([EMAD, "api", *map(str, a)], capture_output=True, text=True, timeout=t)
        return r.stdout.strip()
    except Exception as e:
        return "ERR " + str(e)
def uptime():
    try: s = int(float(open("/proc/uptime").read().split()[0])); return "%dd %dh %dm" % (s // 86400, s % 86400 // 3600, s % 3600 // 60)
    except Exception: return "-"
def osname():
    try: return dict(l.strip().split("=", 1) for l in open("/etc/os-release") if "=" in l)["PRETTY_NAME"].strip('"')
    except Exception: return "-"
def csrf():
    if "t" not in session: session["t"] = secrets.token_hex(16)
    return session["t"]
@app.before_request
def guard():
    if request.endpoint in ("login", "static"): return
    if not session.get("u"): return redirect("/login")
    if request.method == "POST" and not hmac.compare_digest(request.form.get("t", ""), session.get("t", "x")): abort(400)
app.jinja_env.globals.update(csrf=csrf)

ICON = {
 "dash": '<path d="M3 3h7v7H3zM14 3h7v4h-7zM14 10h7v11h-7zM3 13h7v8H3z"/>',
 "tun": '<path d="M3 12h4m10 0h4M7 12a5 5 0 0 1 10 0 5 5 0 0 1-10 0z"/>',
 "new": '<path d="M12 5v14M5 12h14"/>',
 "stat": '<path d="M4 20V10m6 10V4m6 16v-7m4 7H2"/>',
 "set": '<path d="M4 6h10m4 0h2M4 12h2m4 0h10M4 18h12m4 0h0"/><circle cx="16" cy="6" r="2"/><circle cx="8" cy="12" r="2"/><circle cx="18" cy="18" r="2"/>',
 "tg": '<path d="M21 4 3 11l5 2 2 6 3-4 5 4z"/>',
}
def ico(n): return '<svg class="i" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">%s</svg>' % ICON[n]
app.jinja_env.globals["ico"] = lambda n: __import__("markupsafe").Markup(ico(n))
LOGO = "data:image/png;base64,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"
app.jinja_env.globals["LOGO"] = LOGO

CSS = """
:root{--bk:#000;--wh:#fff;--rd:#e1131f;--g1:#f3f3f2;--g2:#dcdcda;--g3:#8b8b88;--ok:#14a44d}
*{box-sizing:border-box}html{color-scheme:light}body{margin:0;font:15px/1.5 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;background:var(--wh);color:var(--bk)}
a{color:inherit}.serif{font-family:"Bodoni Moda","Didot","Playfair Display",Georgia,serif}.mono{font-family:ui-monospace,Menlo,Consolas,monospace}
.shell{display:grid;grid-template-columns:260px 1fr;min-height:100vh}
.rail{background:var(--bk);color:#eee;padding:28px 20px;display:flex;flex-direction:column;gap:28px;position:sticky;top:0;height:100vh}
.brand{display:flex;align-items:center;gap:12px}.brand img{width:44px;height:44px;border-radius:10px}.brand b{font-size:22px;letter-spacing:.2px}.brand b em{color:var(--rd);font-style:normal}
.rail nav{display:flex;flex-direction:column;gap:2px}.rail nav a{display:flex;gap:12px;align-items:center;padding:11px 12px;border-radius:10px;text-decoration:none;color:#b9b9b6;transition:background .15s,color .15s}
.rail nav a:hover{background:#151515;color:#fff}.rail nav a.on{background:var(--wh);color:var(--bk)}.rail nav a.on .i{color:var(--rd)}
.i{width:19px;height:19px;flex:none}.rail .sp{flex:1}
.tg{display:flex;align-items:center;gap:10px;padding:10px 12px;border:1px solid #2b2b2b;border-radius:10px;text-decoration:none;color:#ddd;font-size:14px}.tg:hover{border-color:var(--rd);color:#fff}.tg.dim{color:#8a8a88}
main{padding:34px 44px 60px;max-width:1180px;width:100%}
h1{font-size:34px;margin:0 0 4px;font-weight:600}.sub{color:var(--g3);margin:0 0 28px}
.strip{display:grid;grid-template-columns:repeat(auto-fit,minmax(170px,1fr));border-top:2px solid var(--bk);border-bottom:1px solid var(--g2);margin-bottom:34px}
.strip div{padding:16px 18px 16px 0}.strip small{color:var(--g3);display:block}.strip strong{font-size:18px;font-weight:600}
table{width:100%;border-collapse:collapse}th{text-align:left;font-weight:500;color:var(--g3);font-size:13px;padding:0 10px 10px 0;border-bottom:1px solid var(--bk)}td{padding:14px 10px 14px 0;border-bottom:1px solid var(--g2);vertical-align:middle}
.dot{display:inline-block;width:9px;height:9px;border-radius:50%;background:var(--rd);margin-right:8px}.dot.on{background:var(--ok);box-shadow:0 0 0 4px #14a44d22}
.btn{font:inherit;cursor:pointer;border:1px solid var(--bk);background:var(--wh);color:var(--bk);padding:7px 13px;border-radius:9px;transition:transform .12s,background .15s,color .15s}
.btn:hover{background:var(--bk);color:#fff}.btn:active{transform:translateY(1px)}.btn.red{background:var(--rd);border-color:var(--rd);color:#fff}.btn.red:hover{background:#b80f19}.btn.sm{padding:4px 10px;font-size:13px}.btn.danger:hover{background:var(--rd);border-color:var(--rd)}
.row{display:flex;gap:6px;flex-wrap:wrap}form.inl{display:inline}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:18px 22px;max-width:860px}
label{display:block;font-size:13px;color:var(--g3);margin-bottom:5px}input,select{width:100%;font:inherit;padding:11px 12px;border:1px solid var(--g2);border-radius:10px;background:#fff;color:var(--bk)}
input:focus,select:focus,.btn:focus-visible,a:focus-visible{outline:2px solid var(--rd);outline-offset:2px}
.note{border-left:3px solid var(--rd);padding:8px 14px;background:var(--g1);margin:0 0 24px;max-width:860px}
.seg{display:inline-flex;gap:3px}.seg i{width:16px;height:8px;background:var(--g2);border-radius:2px}.seg i.f{background:var(--ok)}.seg.y i.f{background:#e0a100}.seg.r i.f{background:var(--rd)}
.hide{display:none}
@media(max-width:820px){.shell{grid-template-columns:1fr}.rail{position:static;height:auto;flex-direction:row;flex-wrap:wrap;align-items:center;padding:14px}.rail nav{flex-direction:row;flex-wrap:wrap}.rail .sp,.rail .tg{display:none}main{padding:22px 16px 50px}table{display:block;overflow-x:auto}}
@media(prefers-reduced-motion:reduce){*{transition:none!important;animation:none!important}}
"""
BASE = """<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Em4dloverS Tunnel</title><link rel="icon" href="{{LOGO}}"><style>""" + CSS + """</style></head><body><div class="shell">
<aside class="rail"><div class="brand"><img src="{{LOGO}}" alt=""><b class="serif">Em4d<em>loverS</em></b></div>
<nav>{% for k,l,i in [('dash','Overview','dash'),('tun','Tunnels','tun'),('new','New tunnel','new'),('stat','Compatibility','stat'),('set','Settings','set')] %}
<a href="/{{'' if k=='dash' else k}}" class="{{'on' if page==k}}">{{ico(i)}}<span>{{l}}</span></a>{% endfor %}</nav><div class="sp"></div>
<a class="tg" href="https://t.me/Em4dloverS" target="_blank" rel="noopener">{{ico('tg')}}Channel  t.me/Em4dloverS</a>
<a class="tg dim" href="https://t.me/kamr4" target="_blank" rel="noopener">{{ico('tg')}}Support  t.me/kamr4</a>
<form method="post" action="/logout"><input type="hidden" name="t" value="{{csrf()}}"><button class="btn sm" style="width:100%">Sign out</button></form></aside>
<main>{% if msg %}<div class="note">{{msg}}</div>{% endif %}{{body|safe}}</main></div></body></html>"""
LOGIN = """<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Sign in</title><link rel="icon" href="{{LOGO}}">
<style>""" + CSS + """
body{background:#000;color:#fff;min-height:100vh;display:grid;grid-template-columns:1.1fr 1fr}
.hero{padding:56px;display:flex;flex-direction:column;justify-content:space-between;border-right:1px solid #1d1d1d;overflow:hidden;position:relative}
.hero h2{font-size:clamp(40px,6vw,84px);line-height:.95;margin:0;font-weight:500}.hero h2 em{color:var(--rd);font-style:normal}
.trace{position:absolute;left:0;right:0;bottom:40%;width:100%;height:120px}.trace path{fill:none;stroke:var(--rd);stroke-width:2;stroke-dasharray:1400;stroke-dashoffset:1400;animation:d 3.2s ease-out forwards}
@keyframes d{to{stroke-dashoffset:0}}
.box{display:flex;align-items:center;justify-content:center;padding:32px}.box form{width:100%;max-width:340px;display:flex;flex-direction:column;gap:16px}
.box input{background:#0c0c0c;border-color:#2a2a2a;color:#fff}.box label{color:#9a9a97}.err{color:#ff6b73}
@media(max-width:820px){body{grid-template-columns:1fr}.hero{min-height:220px;padding:28px}}</style></head><body>
<section class="hero"><div class="brand"><img src="{{LOGO}}" alt=""><span class="mono" style="color:#9a9a97">tunnel panel</span></div>
<svg class="trace" viewBox="0 0 800 120" preserveAspectRatio="none"><path d="M0 70H180L205 70 225 18 252 108 276 44 292 70H520L540 70 556 30 576 96 592 70H800"/></svg>
<h2 class="serif">Em4d<em>loverS</em><br>Tunnel</h2></section>
<section class="box"><form method="post"><div class="serif" style="font-size:30px">Sign in</div>{% if err %}<div class="err">{{err}}</div>{% endif %}
<div><label for="u">Username</label><input id="u" name="u" autocomplete="username" required autofocus></div>
<div><label for="p">Password</label><input id="p" name="p" type="password" autocomplete="current-password" required></div>
<button class="btn red" style="padding:12px">Sign in</button></form></section></body></html>"""

def page(name, body, msg=""):
    return render_template_string(BASE, page=name, body=body, msg=msg)
def R(tpl, **k): return render_template_string(tpl, **k)

def tunnels():
    rows = []
    for l in emad("list").splitlines():
        p = l.split("|")
        if len(p) == 6: rows.append(dict(n=p[0], t=p[1], r=p[2], rem=p[3], ports=p[4], s=p[5]))
    return rows
def catalog(): return [l.split("|") for l in emad("catalog").splitlines() if l.count("|") == 2]

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

@app.route("/")
def dash():
    ts = tunnels(); act = sum(1 for t in ts if t["s"] == "active"); load1 = os.getloadavg()[0]
    body = R("""<h1 class="serif">Overview</h1><p class="sub">Live state of this server.</p>
<div class="strip"><div><small>Public IP</small><strong class="mono">{{ip}}</strong></div><div><small>System</small><strong>{{os}}</strong></div>
<div><small>Uptime</small><strong>{{up}}</strong></div><div><small>Load</small><strong>{{ld}}</strong></div><div><small>Tunnels running</small><strong>{{a}} of {{n}}</strong></div></div>
<div class="row"><a class="btn red" href="/new" style="text-decoration:none">Create tunnel</a><a class="btn" href="/tun" style="text-decoration:none">Manage tunnels</a></div>""",
        ip=emad("ip"), os=osname(), up=uptime(), ld="%.2f" % load1, a=act, n=len(ts))
    return page("dash", body)

@app.route("/tun")
def tun():
    body = R("""<h1 class="serif">Tunnels</h1><p class="sub">Start, stop and remove tunnels on this server.</p>
{% if not ts %}<p>No tunnels yet. <a href="/new">Create the first one.</a></p>{% else %}<table><tr><th>Name</th><th>Type</th><th>Role</th><th>Other server</th><th>Ports</th><th>State</th><th></th></tr>
{% for t in ts %}<tr><td><b>{{t.n}}</b></td><td>{{t.t}}</td><td>{{t.r}}</td><td class="mono">{{t.rem}}</td><td class="mono">{{t.ports[:22]}}</td>
<td><span class="dot {{'on' if t.s=='active'}}"></span>{{t.s}}</td><td><div class="row">
{% for a in ['start','stop','restart','delete'] %}<form class="inl" method="post" action="/act/{{t.n}}/{{a}}" {% if a=='delete' %}onsubmit="return confirm('Delete {{t.n}}?')"{% endif %}><input type="hidden" name="t" value="{{csrf()}}"><button class="btn sm {{'danger' if a=='delete'}}">{{a|capitalize}}</button></form>{% endfor %}
</div></td></tr>{% endfor %}</table>{% endif %}""", ts=tunnels())
    return page("tun", body, request.args.get("m", ""))
@app.route("/act/<n>/<a>", methods=["POST"])
def doact(n, a):
    if a not in ("start", "stop", "restart", "delete"): abort(404)
    return redirect("/tun?m=" + (n + ": " + a + " " + ("done" if emad("act", a, n).startswith("OK") else "failed")))

@app.route("/new", methods=["GET", "POST"])
def new():
    msg = ""
    if request.method == "POST":
        f = request.form; g = lambda k, d="": f.get(k, d).strip()
        r = emad("create", g("name"), g("type"), g("role"), g("local"), g("remote"), g("ports") or "1", g("cport") or "0", g("token"), g("idx"), g("peer"))
        msg = "Result: " + r.splitlines()[-1] if r else "No response from emad."
    cat = catalog()
    body = R("""<h1 class="serif">New tunnel</h1><p class="sub">Run this form on both servers. Use the same ID, control port and token on each side.</p>
<form method="post" class="grid"><input type="hidden" name="t" value="{{csrf()}}">
<div><label>Tunnel type</label><select name="type">{% for c in cat %}<option value="{{c[0]}}">{{c[1]}} - {{c[2]}}</option>{% endfor %}</select></div>
<div><label>Name</label><input name="name" pattern="[a-z0-9_-]{1,24}" placeholder="t1" required></div>
<div><label>This server is</label><select name="role"><option value="iran">Iran (entry)</option><option value="foreign">Foreign (exit)</option></select></div>
<div><label>This server IP</label><input name="local" value="{{ip}}" required></div>
<div><label>Other server IP</label><input name="remote" required></div>
<div><label>Ports (80,443,2000-2100)</label><input name="ports" value="443"></div>
<div><label>Tunnel ID (1-250)</label><input name="idx" type="number" min="1" max="250" value="1" required></div>
<div><label>Control port (proxy-based types)</label><input name="cport" type="number" value="33001"></div>
<div><label>Token (same on both)</label><input name="token" value="{{tok}}"></div>
<div><label>WireGuard peer public key (optional)</label><input name="peer"></div>
<div style="align-self:end"><button class="btn red" style="padding:12px 22px">Create and start</button></div></form>""",
        cat=cat, ip=emad("ip"), tok=secrets.token_hex(8))
    return page("new", body, msg)

@app.route("/stat")
def stat():
    rows = [l.split("|") for l in emad("status", t=120).splitlines() if l.count("|") == 2]
    body = R("""<h1 class="serif">Compatibility</h1><p class="sub">How well each tunnel fits this server. 4 of 4 means everything it needs is available.</p>
<table><tr><th>Tunnel</th><th>Fit</th><th></th></tr>{% for t,n,s in rows %}{% set s=s|int %}<tr><td>{{n}}</td><td><span class="seg {{'' if s==4 else 'y' if s==3 else 'r'}}">{% for i in range(4) %}<i class="{{'f' if i<s}}"></i>{% endfor %}</span></td><td>{{s}}/4</td></tr>{% endfor %}</table>""", rows=rows)
    return page("stat", body)

@app.route("/set", methods=["GET", "POST"])
def settings():
    msg = ""; c = load()
    if request.method == "POST":
        u, p = request.form.get("u", "").strip(), request.form.get("p", "")
        if len(u) >= 3 and len(p) >= 8 and pcheck(request.form.get("old", ""), c.get("pass", "")):
            c["user"] = u; c["pass"] = phash(p); save(c); msg = "Login updated."
        else: msg = "Check the current password. New username needs 3+ characters and password 8+."
    body = R("""<h1 class="serif">Settings</h1><p class="sub">Panel address: <span class="mono">{{addr}}</span>. To add a domain with SSL, use option 7 in the emad menu.</p>
<form method="post" class="grid"><input type="hidden" name="t" value="{{csrf()}}"><div><label>Current password</label><input name="old" type="password" required></div>
<div><label>New username</label><input name="u" value="{{u}}" required></div><div><label>New password</label><input name="p" type="password" minlength="8" required></div>
<div style="align-self:end"><button class="btn red" style="padding:12px 22px">Save login</button></div></form>""", addr=url(emad("ip")), u=c.get("user", ""))
    return page("set", body, msg)

if __name__ == "__main__":
    c = load(); kw = {}
    if c.get("cert") and os.path.exists(c["cert"]): kw["ssl_context"] = (c["cert"], c["key"])
    app.run(host=os.environ.get("EMAD_HOST", "0.0.0.0"), port=int(os.environ.get("EMAD_PORT", c.get("port", 8443))), threaded=True, **kw)
