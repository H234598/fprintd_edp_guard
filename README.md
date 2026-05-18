# fprintd eDP guard

`fprintd eDP guard` is a practical Fedora/Linux helper setup for laptops that are usually used closed on a dock with an external USB fingerprint reader.

The problem is wonderfully mundane and therefore extremely Linux-desktop-shaped:

- the laptop has an internal fingerprint reader,
- the laptop is often closed while docked,
- the internal reader is physically unreachable in that setup,
- an external USB fingerprint reader is connected,
- `fprintd` can see multiple readers and may not make the choice you expect.

This repository documents that setup and provides conservative helper files to make the fingerprint-reader situation visible, debuggable, and less surprising.

## Scope

This project does not replace `fprintd`, `libfprint`, PAM, polkit, or your distribution's authentication stack.

It provides:

- a diagnostic guard script,
- an optional systemd oneshot unit,
- a commented udev template,
- installation notes,
- troubleshooting notes,
- hardware notes for the internal-vs-external-reader situation.

The design principle is: **observe first, change later, keep everything reversible.**

Authentication tooling should be boring. Boring means recoverable. Recoverable means you do not lock yourself out because one tiny glowing USB goblin had an opinion.

## Original hardware situation

The original situation involved two fingerprint devices:

- an internal Synaptics fingerprint sensor,
- an external ElanTech USB fingerprint sensor.

The laptop is often used closed on a docking station. The internal sensor exists, but is not useful in normal desk operation. The external reader is the one that should matter.

A typical `fprintd-list` situation looked like this:

```text
found 2 devices
Device at /net/reactivated/Fprint/Device/1
Device at /net/reactivated/Fprint/Device/0
Using device /net/reactivated/Fprint/Device/1
Fingerprints for user teladi on Synaptics Sensors (press):
 - #0: right-index-finger
Using device /net/reactivated/Fprint/Device/0
User teladi has no fingers enrolled for ElanTech Fingerprint Sensor.
```

That is the moment where debugging gets slippery: the system sees both devices, enrollments may live on one reader, and your finger may be on another reader.

## Repository layout

```text
.
├── README.md
├── INSTALLATION.md
├── TROUBLESHOOTING.md
├── scripts/
│   └── fprintd-edp-guard.sh
├── systemd/
│   └── fprintd-edp-guard.service
├── udev/
│   └── 99-fprintd-edp-guard.rules
└── docs/
    ├── hardware-notes.md
    └── safety-and-reversibility.md
```

## Quick start

Install dependencies:

```bash
sudo dnf install fprintd fprintd-pam
```

Install the guard script:

```bash
sudo install -Dm755 scripts/fprintd-edp-guard.sh /usr/local/sbin/fprintd-edp-guard
```

Run it manually:

```bash
/usr/local/sbin/fprintd-edp-guard
```

Run it in strict mode, where a missing external reader returns a failing exit code:

```bash
/usr/local/sbin/fprintd-edp-guard --require-external
```

Install the optional systemd unit:

```bash
sudo install -Dm644 systemd/fprintd-edp-guard.service /etc/systemd/system/fprintd-edp-guard.service
sudo systemctl daemon-reload
sudo systemctl enable --now fprintd-edp-guard.service
```

Check the boot-time result:

```bash
journalctl -u fprintd-edp-guard.service -b --no-pager
```

## Configuration

The script uses simple name-pattern matching by default.

Defaults:

```bash
FPRINTD_EXTERNAL_PATTERN="Elan|ELAN|ElanTech|USB"
FPRINTD_INTERNAL_PATTERN="Synaptics|internal|builtin|built-in"
```

Override them for your hardware:

```bash
FPRINTD_EXTERNAL_PATTERN="ElanTech" /usr/local/sbin/fprintd-edp-guard
```

or in the systemd unit via `Environment=` lines.

## Important safety note

Do **not** remove password login while experimenting.

Do **not** make fingerprint authentication your only administrative path.

Always keep at least one known-good recovery path:

- password login,
- sudo password,
- root shell recovery,
- live USB,
- another admin user.

Fingerprint support on Linux is useful, but it is not a sacred oath sworn by the hardware gods.

## License

MIT. Use it, adapt it, annotate it, and keep the escape hatch open.
