# Safety and reversibility

Fingerprint authentication is convenient, but it should never be your only way into a system.

This project is intentionally conservative because broken authentication is not a fun puzzle when the machine in question is the one you need to fix the puzzle.

## Keep password login

Do not disable password login while testing.

Before changing PAM, sudo, polkit, display-manager settings, udev rules, or systemd units, make sure you can still log in with a password.

## Prefer diagnostics before mutation

Recommended order:

1. inspect visible hardware,
2. inspect `fprintd-list`,
3. test `fprintd-enroll`,
4. test `fprintd-verify`,
5. watch logs,
6. only then change authentication integration.

## Make one change at a time

Do not change all of these at once:

- PAM configuration,
- authselect profile,
- polkit rules,
- udev rules,
- kernel parameters,
- BIOS settings,
- fingerprint enrollments.

Make one change, test, write down the result.

Yes, this is slower. It is also how one avoids summoning the debugging hydra.

## Reverting the script

Remove the installed script:

```bash
sudo rm -f /usr/local/sbin/fprintd-edp-guard
```

## Reverting the systemd unit

Disable and remove:

```bash
sudo systemctl disable --now fprintd-edp-guard.service
sudo rm -f /etc/systemd/system/fprintd-edp-guard.service
sudo systemctl daemon-reload
```

## Reverting the udev rule

Remove the rule:

```bash
sudo rm -f /etc/udev/rules.d/99-fprintd-edp-guard.rules
sudo udevadm control --reload-rules
sudo udevadm trigger
```

## Reverting enrollments

Remove fingerprints for your user:

```bash
fprintd-delete "$USER"
```

Then re-enroll if needed:

```bash
fprintd-enroll "$USER"
```

## Log collection checklist

When asking for help, collect:

```bash
fprintd-list "$USER"
lsusb
journalctl -b | grep -Ei 'fprint|libfprint|finger|elan|synaptics'
```

If the issue happens live:

```bash
journalctl -f | grep -Ei 'fprint|libfprint|finger|elan|synaptics|pam|polkit'
```

Then trigger the failing operation in another terminal.

## Final rule

A fingerprint reader should make login easier, not make the machine depend on one small sensor having a good day.
