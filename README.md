# macOS Multi Audio Out

A tiny macOS utility to route audio to multiple outputs simultaneously.

## Download & Install

Quick one-liner for lazy folks:

```bash
curl -sSL https://github.com/juri1212/macos-multi-audio-out/releases/latest/download/multi-audio-out.zip -o multi-audio-out.zip && unzip -q multi-audio-out.zip && rm -rf multi-audio-out.zip && mv "multi-audio-out.app" /Applications/ && open /Applications/multi-audio-out.app
```

### Or step by step:
- Download the latest release and unzip it with a single command:

```bash
curl -sSL https://github.com/juri1212/macos-multi-audio-out/releases/latest/download/multi-audio-out.zip -o multi-audio-out.zip
unzip multi-audio-out.zip
rm -rf multi-audio-out.zip
```

- Move the app to `/Applications` and open it:

```bash
mv "multi-audio-out.app" /Applications/
open /Applications/multi-audio-out.app
```

- Quick one-liner for lazy folks:

```bash
curl -sSL https://github.com/juri1212/macos-multi-audio-out/releases/latest/download/multi-audio-out.zip -o multi-audio-out.zip && unzip -q multi-audio-out.zip && mv "multi-audio-out.app" /Applications/ && open /Applications/multi-audio-out.app
```

> Note: You may be prompted to allow the app in System Settings → Privacy & Security. Approve any prompts and, if necessary, grant the app permissions to access audio devices.

## Troubleshooting

- If macOS prevents opening the app because it's from an unidentified developer, Control-click the app in Finder and choose `Open`, then confirm.
- If the app needs to access audio devices or system settings, go to `System Settings` → `Privacy & Security` and allow the requested permissions.
- If the downloaded file is different than the example above, replace the file name in the `curl` command with the correct file name shown on the release page.

## Uninstall

To remove the app and its preferences:

```bash
rm -rf /Applications/multi-audio-out.app
rm -rf ~/Library/Preferences/juri1212.multi-audio-out.plist
```

## License

See the project repository for license information.
