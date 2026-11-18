# Declutter

Removes the optional Apple apps from a Mac: Pages, Numbers, Keynote, iMovie, GarageBand, and GarageBand's sound library. The sound library is only offered when Logic Pro and MainStage aren't installed. Everything goes to the Trash, so it can be put back.

Safari, Mail and the other built-in apps are on macOS's sealed system volume and can't be removed without disabling System Integrity Protection, so Declutter leaves them alone. The download page (`index.html`) explains this and has a guide for iPhone and iPad, where no app is allowed to delete other apps.

- `src/declutter.sh`: the app itself. Bash 3.2 plus AppleScript dialogs. Try it without removing anything: `bash src/declutter.sh --dry-run`
- `src/make_icon.py`: draws the icon
- `build.sh`: builds `Declutter.app` and zips it into `Declutter.zip` (needs Python with Pillow)

The app isn't signed or notarized, so the first time it's opened macOS asks the user to approve it in System Settings → Privacy & Security.
