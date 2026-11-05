<p align="center"><img src="assets/logo.png" width="110" alt="Em4dloverS"></p>

# Em4dloverS Tunnel

Tunnel manager for Ubuntu 20.04 / 22.04 / 24.04 / 26.04 and Debian 11 / 12 / 13.
Menu script plus a web panel. Channel: https://t.me/Em4dloverS  Support: https://t.me/kamr4

!\[menu](assets/menu.png)
!\[panel](assets/panel.png)

## Install (one command, run as root on every server)

```bash
bash <(curl -Ls https://raw.githubusercontent.com/Em4dLoverS/Em4dloverS-Tunnel/main/install.sh)
```

Run it later with:

```bash
emad
```

Update:

```bash
cd /opt/emadlovers \&\& git pull
```

## What is inside

34 real tunnel types, each generates a systemd service and survives reboot:

|Group|Types|
|-|-|
|Kernel|GRE, GRE-TAP, IPIP, VXLAN, GRE6, IPIP6, WireGuard, Direct DNAT|
|Relays|Socat TCP, Socat UDP, HAProxy TCP|
|GOST relay|tcp, tls, mtls, ws, mws, wss, mwss, h2, h2c, quic, kcp, grpc|
|Reverse|Rathole, Backhaul (tcp, tcpmux, udp, ws, wsmux), FRP (tcp, kcp, quic, websocket), Chisel|

* Any number of ports per tunnel (`80,443,2000-2100`)
* Any number of tunnels, so one Iran server can connect to many foreign servers and the reverse
* Each tunnel type installs its own requirements automatically
* Tunnel Status: 4/4 green means the type fits your server
* BBR, fq and buffer optimizer
* Web panel on a random free 5-digit port, optional Let's Encrypt SSL, login reset

## How to build a tunnel

1. Run `emad` on both servers.
2. Choose 2 (Create tunnel). Pick Iran on the entry server and Foreign on the exit server.
3. Use the same Tunnel ID, control port and token on both sides.
4. For WireGuard, exchange the public keys (Manage tunnels, then k).

## Web panel

Menu option 6 installs it and prints the address and login. Option 7 adds a domain with SSL. Option 8 resets the login.

## Notes

* Ports equal to your SSH port are refused.
* Kernel tunnels do not work on OpenVZ or LXC containers. Tunnel Status shows this.
* Open the control port and tunnel ports in your provider firewall.

