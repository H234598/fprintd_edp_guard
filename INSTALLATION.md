# Installation

This guide assumes Fedora or a Fedora-like system using `fprintd`, `libfprint`, PAM and systemd.

The commands are deliberately plain. Authentication debugging is already exciting enough without clever one-liners wearing a fake moustache.

## 1. Install fingerprint packages

```bash
sudo dnf install fprintd fprintd-pam
```

On some Fedora installations these packages may already be present.

Check:

```bash
rpm -q fprintd fprintd-pam
```

## 2. Inspect visible fingerprint devices

Run:

```bash
fprintd-list "$USER"
```

You are looking for how many devices are found and which names they have.

Example shape:

```text
found 2 devices
Using device /net/reactivated/Fprint/Device/1
Fingerprints for user USERNAME on Synaptics Sensors (press):
 - #0: right-index-finger
Using device /net/reactivated/Fprint/Device/0
User USERNAME has no fingers enrolled for ElanTech Fingerprint Sensor.
```

If you see both an internal and an external reader, write down the names. The guard script uses these names for pattern matching.

## 3. Install the guard script

From the repository root:

```bash
sudo install -Dm755 scripts/fprintd-edp-guard.sh /usr/local/sbin/fprintd-edp-guard
```

Run it:

```bash
/usr/local/sbin/fprintd-edp-guard
```

Expected behavior:

- it prints the current user,
- it prints the external/internal matching patterns,
- it runs `fprintd-list`,
- it reports whether a likely external reader was found,
- it reports whether a likely internal reader was found,
- it exits successfully unless strict mode is used.

## 4. Test strict mode

Strict mode is useful for systemd or login diagnostics:

```bash
/usr/local/sbin/fprintd-edp-guard --require-external
```

If the external reader is missing, strict mode returns a non-zero exit code.

Check:

```bash
echo $?
```

## 5. Adjust reader patterns if needed

Default external pattern:

```bash
Elan|ELAN|ElanTech|USB
```

Default internal pattern:

```bash
Synaptics|internal|builtin|built-in
```

Run with overrides:

```bash
FPRINTD_EXTERNAL_PATTERN="ElanTech" /usr/local/sbin/fprintd-edp-guard
```

```bash
FPRINTD_INTERNAL_PATTERN="Synaptics" /usr/local/sbin/fprintd-edp-guard
```

## 6. Optional: install the systemd unit

Install:

```bash
sudo install -Dm644 systemd/fprintd-edp-guard.service /etc/systemd/system/fprintd-edp-guard.service
sudo systemctl daemon-reload
sudo systemctl enable --now fprintd-edp-guard.service
```

Check status:

```bash
systemctl status fprintd-edp-guard.service
```

Read logs:

```bash
journalctl -u fprintd-edp-guard.service -b --no-pager
```

The unit is a oneshot diagnostic guard. It does not keep running permanently.

## 7. Optional: prepare a udev rule

The udev file in this repository is a template:

```text
udev/99-fprintd-edp-guard.rules
```

It intentionally does not ship with real vendor/product IDs enabled.

Find your USB fingerprint reader:

```bash
lsusb
```

Example shape:

```text
Bus 003 Device 004: ID 04f3:0c4c Elan Microelectronics Corp. Fingerprint Sensor
```

Here:

- vendor ID: `04f3`
- product ID: `0c4c`

Then edit the udev template before installing it.

Install only after reviewing it:

```bash
sudo install -Dm644 udev/99-fprintd-edp-guard.rules /etc/udev/rules.d/99-fprintd-edp-guard.rules
sudo udevadm control --reload-rules
sudo udevadm trigger
```

## 8. Enroll on the intended reader

Before enrolling, make sure the external reader is visible:

```bash
/usr/local/sbin/fprintd-edp-guard --require-external
```

Then enroll:

```bash
fprintd-enroll "$USER"
```

Verify:

```bash
fprintd-verify "$USER"
```

If enrollment works but verification fails, see `TROUBLESHOOTING.md`.

## 9. Keep a recovery path

Do not disable password authentication while testing.

Before touching PAM, polkit, sudo or display-manager authentication, make sure you can still log in through a normal password path.

A fingerprint reader is a convenience. A password is the boring old bridge home.
