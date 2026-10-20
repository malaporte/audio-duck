# Audio Duck

A tiny macOS menu bar app that keeps your audio ducks in a row: it picks the system input and output devices from a priority list. When devices are plugged in or unplugged, it switches to the highest-priority device that is connected.

## Install

Requires macOS 14+, Xcode, and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
make install
```

This generates the Xcode project from `project.yml`, builds a Release build, copies it to `~/Applications`, and launches it.

## Develop

The Xcode project is generated from `project.yml` and isn't checked in. To work in Xcode:

```bash
make open
```

Run `make project` again after adding or removing source files. `make build` builds without installing, and `make clean` removes the build output and the generated project.

The duck is drawn in code in `DuckShape.swift` and used for both the menu bar and the app icon. After changing it, run `make icon` to redraw the app icon.

## Use

Click the duck in the menu bar and choose **Settings…** (or open the app again from Finder or Spotlight):

- Switch between the **Output** and **Input** lists, then drag devices to reorder them. The highest connected device is used, and the one in use is marked **Active**.
- New devices are added to the bottom of the list the first time they're connected.
- Devices that aren't connected stay in the list, greyed out, so they keep their place. Click **Forget** to remove one.
- The toggles at the bottom turn automatic switching on or off, play alerts on the chosen output, and start the app at login.

If you pick a device by hand in System Settings, the app leaves it alone until a device is added or removed.

## Config file

Settings live in `~/.config/audio-duck/config.json`:

```json
{
  "enabled": true,
  "setSoundEffectsDevice": true,
  "output": ["Scarlett Solo USB", "MacBook Pro Speakers"],
  "input": ["HyperX SoloCast", "Scarlett Solo USB", "MacBook Pro Microphone"]
}
```

Each entry matches a device's name (case-insensitive) or its exact UID. Names can use `*` and `?` wildcards, such as `"*AirPods*"`. A wildcard that matches more than one device picks the first one CoreAudio lists. After editing the file by hand, click **Reload** in the settings window.

Logs: `log stream --predicate 'subsystem == "local.audio-duck"'`
