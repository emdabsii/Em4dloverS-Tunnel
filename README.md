<p align="center"><img src="https://raw.githubusercontent.com/emdabsii/Em4dloverS-Tunnel/main/assets/logo.png" width="120" alt="Em4dloverS"></p>

<h1 align="center">Em4dloverS Tunnel</h1>
<p align="center">Tunnel manager for an Iran server and foreign servers, with a terminal menu and a web panel.<br>مدیریت تانل بین سرور ایران و سرورهای خارج، با منوی ترمینال و وب‌پنل.</p>

<p align="center">
  <a href="https://t.me/Em4dloverS"><img alt="Channel" src="https://img.shields.io/badge/Telegram-Em4dloverS-e1131f?logo=telegram&logoColor=white"></a>
  <a href="https://t.me/KaMr4ng"><img alt="Support" src="https://img.shields.io/badge/Support-KaMr4ng-000000?logo=telegram&logoColor=white"></a>
</p>

<p align="center"><b><a href="#english">English</a></b> &nbsp;|&nbsp; <b><a href="#فارسی">فارسی</a></b></p>

---

<a id="english"></a>
## English

### Requirements
- Ubuntu 20.04, 22.04, 24.04, 26.04 or Debian 11, 12, 13.
- Root access on every server. Other systems are refused.

### Install
Run this on **every** server:
```bash
bash <(curl -Ls https://raw.githubusercontent.com/emdabsii/Em4dloverS-Tunnel/main/install.sh)
```
The installer shows a progress bar from the first second and downloads only the files it needs. Then open the menu any time with `emad`.

### Menu
| Option | What it does |
|---|---|
| 1 | Install requirements for a tunnel family (or all of them) |
| 2 | Create tunnel: type, name, side (Iran or Foreign), IPs, ports, tunnel ID, control port, token |
| 3 | Manage tunnels: start, stop, restart, edit, guide, logs, delete |
| 4 | Tunnel Status: which tunnel types this server can run (4/4 = fully supported) |
| 5 | Optimize network: BBR, fq queue, buffers, MTU |
| 6 | Web panel: status, start/stop, login, port, repair, uninstall |
| 7 | Panel SSL: Let's Encrypt certificate for your domain |
| 8 | Reset panel login |
| 9 | Contact |

### Setup link
On the Iran server, open a tunnel and run:
```bash
emad link NAME
```
This prints an `em4d://...` link. On the foreign server run:
```bash
emad apply-link 'em4d://...'
```
The link carries the tunnel name, type, both IPs, tunnel ID, control port and token. It does not contain ports, which only the Iran side needs.

### Web panel
- **Overview:** live latency, link quality, current traffic (MB/s) and uptime, with charts.
- **Tunnels:** state, ping and actions for every tunnel. Each tunnel has its own page with a connection check, live log, live packets, edit form and an optimize button.
- **Compatibility:** which tunnel types this server supports.
- **Setup guides:** Sanaei (3x-ui), Pasarguard and Marzban, in Persian, with this tunnel's values filled in.

### Security
- Passwords are stored as salted PBKDF2 hashes. Login locks after 5 failed attempts.
- Every change form has a CSRF token. Session cookies are HTTP-only and SameSite.
- Tunnel files and tokens are stored with mode `600`. Input is validated before any command runs.
- Tunnels cannot use your SSH port.

### Notes and limits
- Kernel tunnels (GRE, IPIP, VXLAN and others) do not work inside OpenVZ or LXC containers. Tunnel Status shows this.
- Per-tunnel traffic is exact only for kernel tunnels. Other types show the server network card.
- Test one tunnel between two real servers before building many. Connectivity depends on your provider and firewall.
- Open the control port and tunnel ports in your provider firewall.

### Uninstall
```bash
emad   # option 6 then 8 to remove the panel; option 3 to remove tunnels
rm -rf /opt/emadlovers /usr/local/bin/emad
```

---

<a id="فارسی"></a>
## فارسی

### پیش‌نیازها
- Ubuntu 20.04، 22.04، 24.04، 26.04 یا Debian 11، 12، 13.
- دسترسی root روی همه‌ی سرورها. سیستم‌عامل‌های دیگه رد می‌شن.

### نصب
این دستور رو روی **همه‌ی** سرورها اجرا کن:
```bash
bash <(curl -Ls https://raw.githubusercontent.com/emdabsii/Em4dloverS-Tunnel/main/install.sh)
```
نصب‌کننده از ثانیه‌ی اول نوار پیشرفت نشون می‌ده و فقط فایل‌های لازم رو دانلود می‌کنه. بعدش هر وقت خواستی منو رو با `emad` باز کن.

### منو
| گزینه | کار |
|---|---|
| ۱ | نصب پیش‌نیازهای یک خانواده‌ی تانل (یا همه) |
| ۲ | ساخت تانل: نوع، نام، سمت سرور (ایران یا خارج)، IPها، پورت‌ها، شناسه‌ی تانل، پورت کنترل، توکن |
| ۳ | مدیریت تانل‌ها: شروع، توقف، ری‌استارت، ویرایش، آموزش، لاگ، حذف |
| ۴ | وضعیت تانل‌ها: کدوم نوع تانل روی این سرور اجرا می‌شه (۴ از ۴ = پشتیبانی کامل) |
| ۵ | بهینه‌سازی شبکه: BBR، صف fq، بافرها، MTU |
| ۶ | وب‌پنل: وضعیت، شروع و توقف، ورود، پورت، تعمیر، حذف |
| ۷ | SSL پنل: گواهی Let's Encrypt برای دامنه |
| ۸ | ریست ورود پنل |
| ۹ | تماس |

### لینک تنظیم
روی سرور ایران، یه تانل رو انتخاب کن و این دستور رو بزن:
```bash
emad link NAME
```
یه لینک `em4d://...` می‌ده. روی سرور خارج این دستور رو بزن:
```bash
emad apply-link 'em4d://...'
```
لینک شامل نام، نوع، هر دو IP، شناسه‌ی تانل، پورت کنترل و توکنه. پورت‌های فوروارد داخلش نیستن، چون فقط سمت ایران لازمن.

### وب‌پنل
- **نمای کلی:** تأخیر، کیفیت لینک، ترافیک لحظه‌ای (MB/s) و آپ‌تایم، با نمودار زنده.
- **تانل‌ها:** وضعیت، پینگ و دکمه‌ها برای هر تانل. هر تانل صفحه‌ی خودش رو داره با بررسی اتصال، لاگ زنده، پکت زنده، فرم ویرایش و دکمه‌ی بهینه‌سازی.
- **سازگاری:** کدوم نوع تانل روی این سرور پشتیبانی می‌شه.
- **آموزش پنل‌ها:** Sanaei (3x-ui)، Pasarguard و Marzban، به فارسی و با مقادیر همین تانل پر شده.

### امنیت
- رمزها با PBKDF2 و نمک ذخیره می‌شن. بعد از ۵ تلاش اشتباه ورود قفل می‌شه.
- هر فرم تغییر CSRF داره. کوکی‌های نشست HTTP-only و SameSite هستن.
- فایل‌های تانل و توکن‌ها با مجوز `600` ذخیره می‌شن. ورودی‌ها قبل از اجرای دستور بررسی می‌شن.
- تانل روی پورت SSH ساخته نمی‌شه.

### نکات و محدودیت‌ها
- تانل‌های کرنلی (GRE، IPIP، VXLAN و بقیه) داخل OpenVZ یا LXC کار نمی‌کنن. صفحه‌ی وضعیت این رو نشون می‌ده.
- ترافیک دقیق هر تانل فقط برای تانل‌های کرنلیه. بقیه، ترافیک کارت شبکه‌ی سرور رو نشون می‌دن.
- قبل از ساخت چند تانل، یکی رو بین دو سرور واقعی تست کن. اتصال به ارائه‌دهنده و فایروال بستگی داره.
- پورت کنترل و پورت‌های تانل رو توی فایروال ارائه‌دهنده باز کن.

### حذف
```bash
emad   # گزینه‌ی ۶ و ۸ برای حذف پنل؛ گزینه‌ی ۳ برای حذف تانل‌ها
rm -rf /opt/emadlovers /usr/local/bin/emad
```
