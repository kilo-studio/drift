# Privacy

**Last updated: 2026-05-24**

Drift is built so the only place your data lives is your own device.

## What Drift stores

When you log a hit, Drift records two things on your device: the moment you logged it and your current timezone offset. That's the whole picture. There is no account, no profile, no name, no email. The app never asks for any of that and has nowhere to put it.

Your settings (session threshold, rolling-window length, sleep window, notification preferences) are stored on your device alongside the hits.

## What Drift sends anywhere else

Nothing, unless you turn on iCloud sync. With sync off (the default), every hit stays on your device. With it on, your hits sync through your own iCloud account, and even then they never reach a server we run. Details below.

## iCloud sync (optional, off by default)

Drift can keep your hits in step across your devices using iCloud. It's off until you turn it on, in Settings.

When it's on, your hits sync through the private iCloud database tied to your Apple Account, using Apple's CloudKit. That's the same place the rest of your iCloud data lives. They move between your own devices and Apple's servers, and nowhere else. They never pass through a server we operate, because we don't operate any, and we never receive a copy. What Apple does with data held in iCloud is covered by Apple's privacy policy and your iCloud terms.

Only your hits sync. The stats Drift shows you are recomputed on each device, not synced.

Turn sync off and Drift stops syncing from that point on. Hits already on each device stay where they are.

## Analytics, crash reporting, third-party services

None.

Drift does not include any analytics SDKs. Drift does not include any third-party crash reporting. Drift does not call out to any servers we operate, because we don't operate any servers.

The app declares **"Data Not Collected"** in its App Store privacy label, and that's accurate.

## Notifications

When Drift sends a notification (celebrating a long gap, gently noticing the pattern), that notification is scheduled by the app locally on your device and delivered by Apple's notification system. Drift doesn't send notifications from a remote server.

You can turn notifications off entirely in Settings, or pick which kinds you want (immediate confirmation, beating-your-average, beating-your-record) and how much earlier or later they should fire.

## Exporting and deleting your data

Settings → Data → **export hits** writes a JSON file with every hit Drift has recorded. You can save it to Files, share it, email it to yourself, keep it in iCloud Drive, wherever you want a copy.

Settings → Data → **reset all data** deletes every hit and clears your records. This can't be undone, so the export option is right above it.

Uninstalling the app from your device removes the data stored locally.

## Children

Drift is not directed at children. Drift does not knowingly collect information from anyone, including children, because Drift does not collect information from anyone at all.

## Changes to this policy

If anything material about how Drift handles data changes, this page will be updated and the "Last updated" date at the top will move forward. Because Drift doesn't collect data, the kinds of changes that would matter are small, typically an explanation of a new optional feature.

## Contact

Questions about privacy in Drift: email griffin@kilo.studio.
