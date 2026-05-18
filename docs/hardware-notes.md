# Hardware notes

This project came from a docked laptop setup with two fingerprint readers.

## Internal reader

The internal reader was reported by `fprintd` as a Synaptics device.

In docked use, the laptop is closed. That means the internal reader is physically present but practically unavailable.

That distinction matters:

- the kernel can see the device,
- `fprintd` can see the device,
- the user cannot conveniently touch the device.

That is exactly the kind of mismatch that makes authentication debugging feel haunted.

## External reader

The external reader was reported as an ElanTech fingerprint sensor.

It is connected through USB and is physically available at the desk.

This is the reader that should be used during docked operation.

## Inspecting devices

Use:

```bash
fprintd-list "$USER"
```

Use USB inspection:

```bash
lsusb
```

For more detail:

```bash
lsusb -v
```

For kernel messages:

```bash
dmesg -T | grep -Ei 'usb|finger|fprint|elan|synaptics'
```

For service logs:

```bash
journalctl -b | grep -Ei 'fprint|libfprint|finger|elan|synaptics'
```

## Why not hard-code vendor/product IDs?

Because readers vary.

Even the same marketing name can appear with different USB IDs across revisions, firmware versions, or laptop generations.

This repository therefore ships templates and patterns instead of pretending there is one universal value.

## When BIOS/UEFI can disable the internal reader

If firmware settings offer a way to disable the internal fingerprint reader, that is often cleaner than fighting device selection later in userspace.

Prefer this order:

1. firmware/BIOS setting,
2. clean kernel/device-level configuration,
3. udev tagging and service diagnostics,
4. PAM/polkit changes only after the reader situation is clear.

## When verification still fails

If the external reader appears correctly but `fprintd-verify` fails, this project may not be enough.

Possible causes:

- poor driver support in `libfprint`,
- firmware behavior,
- bad enrollment sample,
- sensor dirt or finger placement,
- USB power management,
- a real bug.

At that point, collect logs and test with the simplest possible path:

```bash
fprintd-delete "$USER"
fprintd-enroll "$USER"
fprintd-verify "$USER"
```

Do this while watching logs:

```bash
journalctl -f | grep -Ei 'fprint|libfprint|finger'
```
