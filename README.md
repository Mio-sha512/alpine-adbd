# alpine-adbd

Standalone `adbd` packaged for Alpine Linux. Can be used to provide adb functionality to any device with USB gadget support.

Architectures: `x86_64`, `aarch64`, `armv7`, `riscv64`.

## Install

```sh
wget -q https://mio-sha512.github.io/alpine-adbd/alpine-adbd.rsa.pub \
  -O /etc/apk/keys/alpine-adbd.rsa.pub
echo "https://mio-sha512.github.io/alpine-adbd" >> /etc/apk/repositories
apk update
apk add adbd
rc-update add adbd
rc-service adbd start
```

`adb devices` on your computer should now list the machine.

Updates should be picked up automatically by `apk upgrade` as new releases get
published.

## Configuration
adbd requires a configfs gadget with an `ffs.adb` function mounted at
`/dev/usb-ffs/adb` without it the service refuses to start (no TCP
fallback for safety as it's unauthenticated and provides a root shell).

If you do want TCP, set `ADBD_PORT` in `/etc/conf.d/adbd`. 

`adb reboot <arg>` runs `/system/bin/reboot <arg>` put a wrapper script
there to customize reboot modes. (like `edl` or `fastboot`)

## Credits

Built from [`nmeum/android-tools`](https://github.com/nmeum/android-tools)
releases. Patches 0029/0030 are carried from
[happyme531/standalone-linux-adbd](https://github.com/happyme531/standalone-linux-adbd);
0031–0034 are original to this repo. Full per-file attribution is in
[`CREDITS`](CREDITS).
