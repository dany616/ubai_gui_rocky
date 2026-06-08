# Troubleshooting

## Windows Cannot Connect To 127.0.0.1:9999

Check the Windows local forward:

```powershell
netstat -ano | findstr 9999
netstat -ano | findstr 9922
```

If nothing is listening, the PC -> gate local forward is not open.

Check the gate relay from the Windows GUI status output, or manually on the gate:

```bash
nc -vz 127.0.0.1 9999
nc -vz 127.0.0.1 9922
```

If the gate ports are closed, inspect the Slurm log:

```bash
tail -n 120 logs/ubai-cst-xrdp-<jobid>.out
tail -n 120 logs/ubai-cst-xrdp-<jobid>.err
```

## Compute To Gate Reverse Tunnel Fails

Common causes:

- the relay key was not uploaded to `~/ubai_gui_secrets`
- the relay public key is missing from `~/.ssh/authorized_keys`
- port 9999 or 9922 is already in use on the gate node
- the Slurm job exited before opening the tunnel
- the container xrdp or sshd port did not become reachable from the compute node

From the compute node job log, check whether these lines appear:

```text
[OK] Compute node can reach container XRDP/SSH ports.
[OK] Reverse tunnel established.
[OK] Gate node can reach forwarded RDP/SSH ports.
```

## VSCode Cannot Connect To root@localhost:9922

The container starts an internal `sshd` on `127.0.0.1:9922`. The Slurm job reverse-forwards that port to the gate, and the Windows GUI local-forwards it back to `127.0.0.1:9922` on this PC.

Check Windows:

```powershell
Test-NetConnection 127.0.0.1 -Port 9922
ssh -vvv root@localhost -p 9922
```

Prefer this VSCode Remote-SSH target:

```text
ssh://root@ubai-container
```

No unauthenticated root SSH is opened. The GUI creates an internal key, adds it to the container root `authorized_keys`, and configures the local SSH client to use it. If key auth fails, use the same root password as XRDP.

## XRDP Login Works But Desktop Is Black

This usually means xrdp auth worked but session startup failed.

Check container logs:

```text
/work/logs/xrdp.stderr
/work/logs/xrdp-sesman.stderr
/var/log/xrdp.log
/var/log/xrdp-sesman.log
```

Try inside container:

```bash
which startxfce4
cat ~/.Xclients
```

The image is configured to use the Xvnc backend. If login succeeds but the desktop does not open, inspect the job-local xrdp and sesman logs first.

## CST GUI Opens But 3D View Is Slow

Check OpenGL:

```bash
glxinfo | grep -E "OpenGL vendor|OpenGL renderer|OpenGL version"
```

If renderer contains `llvmpipe`, the GUI is using CPU software rendering. That may still be usable for setup but slow for heavy 3D interaction.

## Find Mixed Nodes With At Least 400 GB Free Memory

The Windows GUI has a `노드 사용률 조회` button that queries Slurm through the gate node and highlights mixed nodes whose `FreeMem` is at least `409600 MB` (`400 * 1024`).

Manual check on the gate node:

```bash
for n in $(sinfo -N -t mix -h -o "%N"); do
  echo "===== $n ====="
  scontrol show node "$n" | egrep "CPUAlloc|CPUTot|RealMemory|AllocMem|FreeMem|Gres|GresUsed"
done
```

Relevant fields:

- `CPUAlloc / CPUTot`: allocated CPU cores over total CPU cores.
- `AllocMem / RealMemory`: Slurm allocated memory over configured node memory.
- `FreeMem`: currently free memory in MB; `FreeMem >= 409600` means at least 400 GB is free.
- `Gres / GresUsed`: configured and used generic resources, usually GPUs.

## CST Cannot Get License

Check license server reachability from the compute node/container:

```bash
nc -vz LICENSE_HOST 27000
```

Exact port depends on the CST/Dassault license configuration.
