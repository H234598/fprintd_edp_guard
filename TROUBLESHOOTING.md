# Troubleshooting

This document collects the common failure modes around `fprintd`, internal laptop fingerprint readers, and external USB fingerprint readers.

The important rule: debug the visible devices first. Do not start by changing PAM. PAM is the basement. We do not begin in the basement unless the lights are already on.

## Show fingerprint devices

```bash
fprintd-list "$USER"
```

This is the first command to run.

Useful things to notice:

- How many devices are found?
- Are both the internal and external readers listed?
- Which device has enrolled fingers?
- Does the device name match the physical reader you are touching?

## Run the guard script

```bash
/usr/local/sbin/fprintd-edp-guard
```

Strict mode:

```bash
/usr/local/sbin/fprintd-edp-guard --require-external
```

Verbose mode:

```bash
/usr/local/sbin/fprintd-edp-guard --verbose
```

## Symptom: two readers are found

Example:

```text
found 2 devices
Synaptics Sensors (press)
ElanTech Fingerprint Sensor
```

This is not automatically wrong. It only becomes a problem when the desktop, PAM, sudo, polkit or your own mental model assumes the wrong reader.

Things to check:

```bash
fprintd-list "$USER"
fprintd-verify "$USER"
```

If verification asks you to touch a reader, make sure you are touching the device that actually has an enrollment.

## Symptom: enrollment works but verification fails

This can happen for several reasons.

### 1. Bad enrollment sample

Delete and re-enroll the finger:

```bash
fprintd-delete "$USER"
fprintd-enroll "$USER"
fprintd-verify "$USER"
```

During enrollment:

- vary finger angle slightly,
- do not press too hard,
- keep the sensor clean,
- make sure the same reader is used throughout.

### 2. Wrong reader used during verify

Run:

```bash
fprintd-list "$USER"
```

Check which device actually has enrolled fingers.

### 3. Driver or firmware quality

Some readers are visible to `fprintd` but still perform poorly.

Check libfprint/fprintd logs:

```bash
journalctl -b | grep -Ei 'fprint|libfprint|finger'
```

Run verify and watch logs live:

```bash
journalctl -f | grep -Ei 'fprint|libfprint|finger'
```

Then in another terminal:

```bash
fprintd-verify "$USER"
```

## Symptom: external USB reader disappears

Check USB:

```bash
lsusb
```

Check kernel messages:

```bash
dmesg -T | grep -Ei 'usb|finger|fprint|elan|synaptics'
```

Power management can be involved. As a diagnostic step only, you can test whether USB autosuspend is related.

Temporary kernel-parameter test examples vary by distribution and bootloader. On Fedora with GRUB, persistent kernel arguments are usually managed with `grubby`, but do not blindly paste boot parameters unless you understand the rollback path.

Useful inspection:

```bash
cat /sys/module/usbcore/parameters/autosuspend 2>/dev/null || true
```

## Symptom: PAM login behaves differently from command line verify

First verify the reader itself:

```bash
fprintd-verify "$USER"
```

If command-line verification fails, PAM is not the first problem.

If command-line verification works but login/sudo does not, inspect PAM configuration.

Fedora often uses authselect:

```bash
authselect current
```

Do not manually mangle PAM files unless you are prepared to recover from a broken login stack.

## Symptom: polkit or GUI authentication does not use fingerprint

Check whether `fprintd` works outside the GUI first:

```bash
fprintd-verify "$USER"
```

Then check logs while triggering the GUI prompt:

```bash
journalctl -f | grep -Ei 'polkit|fprint|pam'
```

Some GUI authentication paths behave differently from terminal PAM paths.

## Symptom: the internal reader should be ignored

Options, from least invasive to more invasive:

1. Do nothing, but make sure the external reader is enrolled and visible.
2. Use this guard script to detect whether the external reader is available at boot.
3. Use a udev rule or hardware-level method to disable the internal device.
4. Use BIOS/UEFI settings if the machine exposes a fingerprint-reader disable switch.

Prefer BIOS/UEFI or clean hardware disablement when available. It is simpler than fighting device selection above the kernel.

## Useful commands

List fingerprints:

```bash
fprintd-list "$USER"
```

Enroll:

```bash
fprintd-enroll "$USER"
```

Verify:

```bash
fprintd-verify "$USER"
```

Delete enrollments:

```bash
fprintd-delete "$USER"
```

Show USB devices:

```bash
lsusb
```

Show fprint-related logs:

```bash
journalctl -b | grep -Ei 'fprint|libfprint|finger|elan|synaptics'
```

Watch logs live:

```bash
journalctl -f
```

## Interpreting the guard script exit codes

The script uses simple exit codes:

- `0`: no fatal issue detected,
- `1`: strict mode requested an external reader, but no matching external reader was found,
- `2`: `fprintd-list` failed or `fprintd` is unavailable,
- `64`: invalid command-line usage.

## Recovery advice

If authentication changes lock you out of a graphical login, try:

- a TTY login with username/password,
- booting an older kernel,
- booting into rescue mode,
- using a live USB to undo PAM/systemd/udev changes.

The most important safety practice is boring: never remove password login while testing fingerprint authentication.
