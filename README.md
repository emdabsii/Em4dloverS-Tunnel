<p align="center"><img src="assets/logo.png" width="120" alt="Em4dloverS"></p>

<h1 align="center">Em4dloverS Tunnel</h1>

<p align="center">
  <a href="https://t.me/Em4dloverS"><img alt="Channel" src="https://img.shields.io/badge/Telegram-Em4dloverS-e1131f?logo=telegram&logoColor=white"></a>
  <a href="https://t.me/KaMr4ng"><img alt="Support" src="https://img.shields.io/badge/Support-KaMr4ng-000000?logo=telegram&logoColor=white"></a>
</p>

<p align="center"><b>[ English ](#english)</b> &nbsp;|&nbsp; <b>[ فارسی ](#فارسی)</b></p>

---

<a id="english"></a>
## English

**Em4dloverS Tunnel** is a tunnel manager for Iran-to-foreign (and foreign-to-foreign) servers. It has a terminal menu and a web panel with live status, charts and a live log.

### Supported systems
| OS | Versions |
|---|---|
| Ubuntu | 20.04, 22.04, 24.04, 26.04 |
| Debian | 11, 12, 13 |

Run as `root`. Other systems are refused with a clear message.

### Install (run on every server)
```bash
bash <(curl -Ls https://raw.githubusercontent.com/emdabsii/Em4dloverS-Tunnel/main/install.sh)
```
The installer shows a live progress bar from the first second, downloads only the files it needs, and falls back to a mirror if GitHub is slow. Afterwards, open the menu any time with:
```bash
emad
```

### Main menu
| No. | Option | What it does |
|---|---|---|
| 1 | Install requirements | Installs the engine for one tunnel family, or all of them |
| 2 | Create tunnel | Wizard: type (70 types, grouped), name, role (Iran or Foreign), IPs, ports, tunnel ID, control port, token |
| 3 | Manage tunnels | Start, stop, restart, edit (IP, ports, control port, token, WireGuard peer), live logs, delete |
| 4 | Tunnel Status | Shows which of the 70 types this server can run, 4 of 4 means fully supported |
| 5 | Optimize network | BBR congestion control, fq queue, larger buffers, MTU tuning |
| 6 | Web panel | Status, start/stop, change login, new random password, change port, repair, uninstall |
| 7 | Panel SSL | Let's Encrypt certificate for a domain |
| 8 | Reset panel login | Change username and password |
| 9 | Contact | Channel and support links |

### The 70 tunnel types
| Group | Count | Types |
|---|---|---|
| Kernel | 9 | GRE, GRE-TAP, IPIP, VXLAN, GENEVE, GRE6, GRE6-TAP, IPIP6, Direct DNAT |
| UDP Encap | 6 | GRE/GRE-TAP/IPIP over FOU and GUE (passes through NAT and UDP filters) |
| WireGuard | 3 | WireGuard, WireGuard + PSK, WireGuard MTU 1280 |
| Relay | 3 | Socat TCP, Socat UDP, HAProxy TCP |
| GOST Relay | 12 | TCP, TLS, MTLS, WS, MWS, WSS, MWSS, H2, H2C, QUIC, KCP, gRPC |
| GOST SOCKS5 | 12 | Same 12 transports as SOCKS5 |
| Reverse | 12 | Rathole, Backhaul (TCP, TCPMux, UDP, WS, WSMux), FRP (TCP, KCP, QUIC, WebSocket), Chisel HTTP, Chisel HTTPS |
| Hysteria2 | 2 | QUIC tunnel, with and without salamander obfuscation |
| Xray | 11 | VMess (TCP, WS, gRPC, HTTPUpgrade, mKCP), VLESS (WS, gRPC, HTTPUpgrade), Shadowsocks (AES-128, AES-256, ChaCha20) |

### How to build a tunnel
1. Run `emad` on the **foreign** server, choose **Create tunnel**, role **Foreign**. No ports are needed here. Pick a type, a tunnel ID (1 to 250), a control port and a token.
2. Run `emad` on the **Iran** server with the **same** type, tunnel ID, control port and token. Role **Iran**, and enter the ports you want to forward (for example `80,443,2000-2100`).
3. Check the status in the tunnel page. A green state means the peer answers through the tunnel.
4. For WireGuard, copy the public key from one side to the other (Manage tunnels, then `k`).

### Web panel
- **Overview:** four live rings (latency, link quality, current traffic in MB/s, uptime with total traffic) and live charts for throughput, latency and packet loss.
- **Tunnels:** all tunnels with state, ping and quick actions.
- **Tunnel page:** connection state with the reason, Check now (4-packet test), start/stop/restart, live log, live packets, optimize button and edit form.
- **Compatibility:** each tunnel type with its fit score. Full support shows an animated tick, partial shows a warning, no fit shows a red alert.
- **Units:** speeds in MB/s, totals in MB, GB and TB.

### Security
- Passwords are stored as salted PBKDF2 hashes (200,000 rounds). Login is rate-limited after 5 failed attempts.
- Every change form has a CSRF token. Session cookies are HTTP-only and SameSite.
- Tunnel settings and tokens are stored with mode `600`. Input is validated before any command runs.
- The SSH port is refused when creating a tunnel, so you cannot lock yourself out.

### Honest limits
- Kernel tunnels (GRE, IPIP, VXLAN and others) do not work inside OpenVZ or LXC containers. Compatibility shows this.
- Traffic per tunnel is exact only for kernel tunnels. Other types show the traffic of the server network card.
- Real connectivity depends on your provider, firewall and the other server. Always open the control port and tunnel ports in the provider firewall.
- Test one tunnel on two servers before building many.

### Uninstall
```bash
emad  # then 6, then 8 (uninstall panel), and remove tunnels from 3
rm -rf /opt/emadlovers /usr/local/bin/emad
```

---

<a id="فارسی"></a>
## فارسی

**Em4dloverS Tunnel** یک مدیر تانل برای ارتباط سرور ایران با خارج (و خارج با خارج) است. منوی ترمینال داره و یک وب‌پنل با وضعیت زنده، نمودار و لاگ زنده.

### سیستم‌عامل‌های پشتیبانی‌شده
| سیستم‌عامل | نسخه‌ها |
|---|---|
| Ubuntu | 20.04، 22.04، 24.04، 26.04 |
| Debian | 11، 12، 13 |

با کاربر `root` اجرا کن. سیستم‌عامل‌های دیگه با پیام واضح رد می‌شن.

### نصب (روی هر سرور اجرا کن)
```bash
bash <(curl -Ls https://raw.githubusercontent.com/emdabsii/Em4dloverS-Tunnel/main/install.sh)
```
نصب‌کننده از ثانیه‌ی اول نوار پیشرفت نشون می‌ده، فقط فایل‌های لازم رو دانلود می‌کنه و اگه گیت‌هاب کند بود از آینه استفاده می‌کنه. بعدش هر وقت خواستی منو رو باز کن:
```bash
emad
```

### منوی اصلی
| شماره | گزینه | کار |
|---|---|---|
| 1 | نصب پیش‌نیازها | نصب موتور یک خانواده تانل یا همه‌ی آن‌ها |
| 2 | ساخت تانل | ویزارد: نوع تانل (۷۰ نوع، دسته‌بندی‌شده)، نام، سمت سرور (ایران یا خارج)، IPها، پورت‌ها، شناسه‌ی تانل، پورت کنترل، توکن |
| 3 | مدیریت تانل‌ها | شروع، توقف، ری‌استارت، ویرایش (IP، پورت‌ها، پورت کنترل، توکن، کلید WireGuard)، لاگ زنده، حذف |
| 4 | وضعیت تانل‌ها | نشون می‌ده این سرور کدوم‌یک از ۷۰ نوع رو می‌تونه اجرا کنه؛ ۴ از ۴ یعنی پشتیبانی کامل |
| 5 | بهینه‌سازی شبکه | BBR، صف fq، بافرهای بزرگ‌تر، تنظیم MTU |
| 6 | وب‌پنل | وضعیت، شروع و توقف، تغییر یوزر و رمز، رمز رندوم جدید، تغییر پورت، تعمیر، حذف |
| 7 | SSL پنل | گواهی Let's Encrypt برای دامنه |
| 8 | ریست ورود پنل | تغییر یوزرنیم و رمز |
| 9 | تماس | لینک کانال و پشتیبانی |

### ۷۰ نوع تانل
| دسته | تعداد | نوع‌ها |
|---|---|---|
| کرنل | ۹ | GRE، GRE-TAP، IPIP، VXLAN، GENEVE، GRE6، GRE6-TAP، IPIP6، DNAT مستقیم |
| UDP Encap | ۶ | GRE و GRE-TAP و IPIP داخل FOU و GUE (از NAT و فیلتر UDP رد می‌شه) |
| WireGuard | ۳ | WireGuard، WireGuard با PSK، WireGuard با MTU 1280 |
| رله | ۳ | Socat TCP، Socat UDP، HAProxy TCP |
| GOST رله | ۱۲ | TCP، TLS، MTLS، WS، MWS، WSS، MWSS، H2، H2C، QUIC، KCP، gRPC |
| GOST SOCKS5 | ۱۲ | همان ۱۲ پروتکل به‌صورت SOCKS5 |
| معکوس | ۱۲ | Rathole، Backhaul (TCP، TCPMux، UDP، WS، WSMux)، FRP (TCP، KCP، QUIC، WebSocket)، Chisel HTTP، Chisel HTTPS |
| Hysteria2 | ۲ | تانل QUIC، با و بدون obfs (salamander) |
| Xray | ۱۱ | VMess (TCP، WS، gRPC، HTTPUpgrade، mKCP)، VLESS (WS، gRPC، HTTPUpgrade)، Shadowsocks (AES-128، AES-256، ChaCha20) |

### ساخت یک تانل
1. روی سرور **خارج** `emad` رو اجرا کن، **ساخت تانل** و سمت **خارج** رو انتخاب کن. اینجا پورت لازم نیست. نوع، شناسه‌ی تانل (۱ تا ۲۵۰)، پورت کنترل و توکن رو وارد کن.
2. روی سرور **ایران** همون نوع، همون شناسه، همون پورت کنترل و همون توکن. سمت **ایران** و پورت‌هایی که می‌خوای فوروارد بشن (مثلاً `80,443,2000-2100`).
3. وضعیت رو از صفحه‌ی تانل چک کن. وضعیت سبز یعنی طرف مقابل از داخل تانل جواب می‌ده.
4. برای WireGuard، کلید عمومی هر طرف رو به طرف دیگه بده (مدیریت تانل‌ها، بعد `k`).

### وب‌پنل
- **صفحه‌ی اصلی:** چهار حلقه‌ی زنده (پینگ، کیفیت لینک، ترافیک لحظه‌ای بر حسب MB/s، آپ‌تایم با ترافیک کل) و نمودارهای زنده برای سرعت، پینگ و پکت لاست.
- **تانل‌ها:** همه‌ی تانل‌ها با وضعیت، پینگ و دکمه‌های سریع.
- **صفحه‌ی تانل:** وضعیت اتصال با دلیلش، Check now (تست ۴ پکتی)، شروع و توقف، لاگ زنده، پکت‌های زنده، دکمه‌ی بهینه‌سازی و فرم ویرایش.
- **وضعیت تانل‌ها:** هر نوع تانل با امتیاز سازگاری. پشتیبانی کامل تیک سبز متحرک، نیمه‌کامل هشدار زرد، ناسازگار هشدار قرمز چشمک‌زن.
- **واحدها:** سرعت بر حسب MB/s، مصرف کل بر حسب MB، GB و TB.

### امنیت
- رمزها با PBKDF2 و نمک (۲۰۰ هزار دور) ذخیره می‌شن. بعد از ۵ تلاش اشتباه ورود موقتاً قفل می‌شه.
- هر فرم تغییر توکن CSRF داره. کوکی‌های نشست فقط HTTP و SameSite هستن.
- تنظیمات تانل و توکن‌ها با مجوز `600` ذخیره می‌شن. ورودی‌ها قبل از اجرای هر دستور بررسی می‌شن.
- ساخت تانل روی پورت SSH رد می‌شه تا خودت رو قفل نکنی.

### محدودیت‌های واقعی
- تانل‌های کرنلی (GRE، IPIP، VXLAN و بقیه) داخل OpenVZ یا LXC کار نمی‌کنن. صفحه‌ی وضعیت این رو نشون می‌ده.
- ترافیک دقیق هر تانل فقط برای تانل‌های کرنلیه. بقیه، ترافیک کارت شبکه‌ی سرور رو نشون می‌دن.
- اتصال واقعی به ارائه‌دهنده، فایروال و سرور مقابل بستگی داره. پورت کنترل و پورت‌های تانل رو توی فایروال ارائه‌دهنده باز کن.
- قبل از ساخت چند تانل، یک تانل روی دو سرور تست کن.

### حذف
```bash
emad  # بعد 6 و 8 برای حذف پنل، و از 3 تانل‌ها رو حذف کن
rm -rf /opt/emadlovers /usr/local/bin/emad
```
