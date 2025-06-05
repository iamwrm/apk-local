# Tailscale Exit Node Configuration

This document explains how to configure one Linux server to use another as an exit node in Tailscale, routing all traffic through the exit node.

## Setup

### On Exit Node (Server B)
Enable exit node advertising:
```bash
sudo tailscale up --advertise-exit-node
```

### On Client (Server A)
Configure to use the exit node:
```bash
sudo tailscale up --exit-node=<server-B-tailscale-IP>
```

Replace `<server-B-tailscale-IP>` with the Tailscale IP of server B (find it with `tailscale ip` on server B).

## Persistence Across Reboots

The `tailscale up` command should persist automatically, but if it doesn't, use one of these methods:

### Method 1: Systemd Service Override (Recommended)
```bash
sudo systemctl edit tailscaled
```

Add the following content:
```ini
[Service]
ExecStartPost=/usr/bin/tailscale up --exit-node=<server-B-tailscale-IP>
```

### Method 2: Custom Systemd Service
Create a new service file:
```bash
sudo nano /etc/systemd/system/tailscale-exit-node.service
```

Content:
```ini
[Unit]
Description=Set Tailscale Exit Node
After=tailscaled.service
Wants=tailscaled.service

[Service]
Type=oneshot
ExecStart=/usr/bin/tailscale up --exit-node=<server-B-tailscale-IP>
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

Enable the service:
```bash
sudo systemctl enable tailscale-exit-node.service
```

### Method 3: Crontab
Add to crontab:
```bash
crontab -e
```

Add line:
```bash
@reboot /usr/bin/tailscale up --exit-node=<server-B-tailscale-IP>
```

## Verification

Check that traffic is being routed through the exit node:
```bash
curl ifconfig.me
```

This should return the public IP of server B instead of server A.

## Troubleshooting

- Ensure both servers are connected to Tailscale: `tailscale status`
- Check exit node is advertised: `tailscale status` on server B should show "offers exit node"
- Verify connectivity: `tailscale ping <server-B-tailscale-IP>`