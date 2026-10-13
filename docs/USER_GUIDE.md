# Pomodoro User Guide

This guide covers the current macOS application. All button names match the English interface.

## Contents

- [Set up and launch](#set-up-and-launch)
- [Your first focus session](#your-first-focus-session)
- [Timer controls and session cycle](#timer-controls-and-session-cycle)
- [Use the menu bar](#use-the-menu-bar)
- [Choose a task from Reminders](#choose-a-task-from-reminders)
- [Add focus records to Calendar](#add-focus-records-to-calendar)
- [Saved state, sleep, and quitting](#saved-state-sleep-and-quitting)
- [Troubleshooting](#troubleshooting)
- [Current limitations](#current-limitations)

## Set up and launch

You need macOS 14 or later and Xcode 15 or later, or a command-line toolchain with Swift 5.9+ and the macOS SDK. This project currently ships as source code rather than a downloadable installer.

1. Download or clone the repository and open Terminal in its root directory.
2. Build the application:

   ```sh
   ./scripts/build-app.sh
   ```

3. Launch the packaged app:

   ```sh
   open build/Pomodoro.app
   ```

You can also open `build/Pomodoro.app` in Finder. Keep using the packaged app for Calendar and Reminders access; it contains the permission descriptions macOS needs.

Building again updates the app at the same location. Quit the running app before opening a newly built version. The build uses a local ad-hoc signature; it is not a notarized public release.

## Your first focus session

1. Enter a task in **What will you focus on?**, such as “Read chapter 3.” Leaving the title empty is allowed.
2. Optionally enable **Automatically start breaks**. It is off by default.
3. Click **Start / Resume** to start a 25-minute focus session.
4. Click **Pause** if you need to stop working, then **Start / Resume** to continue.
5. When the session finishes, the app plays a system sound and increases **Completed sessions**.
6. Start the break manually, or let the app start it if automatic breaks are enabled.
7. After the break finishes, click **Start / Resume** to begin the next focus session.

Task and calendar selection are disabled while the timer is running. Pause first to change them. Changes apply to the next running segment; existing records retain their original task and calendar.

## Timer controls and session cycle

| Control | What it does |
| --- | --- |
| **Start / Resume** | Starts the current phase or resumes its remaining time. |
| **Pause** | Stops the countdown and saves the elapsed focus segment. Paused time is excluded. |
| **End / Reset Session** | Ends the current segment and resets the current phase to its full duration. It keeps existing records and the completed-session count. |
| **Automatically start breaks** | Starts a break after a completed focus session. It does not automatically start the next focus session. |

The cycle uses fixed durations:

| Phase | Duration | Next phase after completion |
| --- | --- | --- |
| **Focus** | 25 minutes | Short Break, or Long Break after every fourth completed focus session |
| **Short Break** | 5 minutes | Focus |
| **Long Break** | 15 minutes | Focus |

Ending a focus session early preserves elapsed focus time but does not increase **Completed sessions** or advance to a break. Ending a break early resets that break; it does not skip to Focus. If a phase has already reached its deadline, it is treated as completed.

The completed-session count persists across app launches; it is not a daily counter. The fourth, eighth, twelfth, and subsequent multiples of four completed focus sessions lead to a long break.

## Use the menu bar

Click the timer item in the macOS menu bar to open the same controls as the main window. While running, the menu bar shows the remaining time. When stopped or paused, it shows **Pomodoro**.

Both views share the same timer, task, settings, and records. Closing the main window does not quit the app; you can continue through the menu bar. To quit completely, use **Pomodoro → Quit Pomodoro** in the application menu or press **Command-Q** when the app is active.

## Choose a task from Reminders

1. Click **Load Tasks** in the **Reminders** section.
2. Allow Reminders access in the macOS prompt. Calendar access is requested separately and is not required to load tasks.
3. Choose a list in **Reminder List**, or select **All Lists**. Your selection is remembered across launches. Empty lists are available too and show **No incomplete tasks in this list.**
4. Tasks from the selected list appear in a scrollable list, with their source reminder list beneath each title.
5. Click a task. Its title becomes the task for your focus session.
6. Click **Start / Resume** when ready.

Selecting a reminder only copies its title. The app does not mark it complete, edit it, or track future changes to that reminder. Completed reminders are excluded. Click **Load Tasks** again to update the list after making changes in Apple Reminders.

## Add focus records to Calendar

### Select a calendar

1. Click **Connect Calendar** and grant Calendar access.
2. While the timer is stopped or paused, select a destination in the **Calendar** picker.
3. Start or resume your focus session.

Only calendars that permit changes appear in the picker. The destination is captured when each focus segment starts.

### Save a record

1. Pause, finish, or end a focus session to generate a record.
2. Find the record in the list below the controls. Newest records appear first.
3. Click **Add to Calendar** beside that record.
4. Look for **Saved to Calendar.**, then check Apple Calendar at the record's date and time.

The event uses the task title, or **Pomodoro Focus** for an empty title, and the actual start and end time of the focus segment. It is a record of time already spent, not a future scheduled session. Breaks and paused time are excluded.

For example, focus for 10 minutes, pause for 3 minutes, and resume for 15 minutes. The app creates two focus records totaling 25 minutes. Add each separately to Calendar; the 3-minute gap is not included.

If a record was created without a calendar selection, it uses the currently selected calendar when exported. A record with a saved destination continues to use that calendar. Selecting a different calendar does not redirect old records that already have a destination.

The app checks existing events for a record identifier in the event notes. Clicking **Add to Calendar** again reports **This record already exists in Calendar.** if that matching event is still present. Removing or changing the identifier in Apple Calendar can prevent this duplicate check from recognizing the event.

**Automatically sync focus records** is on by default. After selecting a calendar, pausing, ending, or completing a focus session automatically syncs the new segment. If permission is missing, the app requests Calendar access and retries queued records once granted. Failed records remain pending across restarts; use **Retry Pending** or the record’s **Retry Sync** button. Disable automatic sync if you prefer the manual steps above. Older records created before automatic sync was enabled can still be added manually. Adding a record does not remove it from the local list. To edit or delete a saved event, use Apple Calendar.

## Saved state, sleep, and quitting

The app saves the current phase, remaining time or deadline, task title, calendar selection, completed-session count, focus records, and automatic-break preference locally on your Mac.

- **Paused timer:** stays paused when you reopen the app.
- **Running timer:** continues according to its saved deadline, including time spent asleep or with the app closed.
- **Expired timer:** finishes when the app next processes it. The focus record ends at the original deadline, excluding extra elapsed time.
- **Automatic break after recovery:** starts at recovery time. The app does not generate multiple missed focus sessions or breaks.

Pause before sleeping or quitting if you want away time excluded from your focus record. The app cannot play its completion sound while it is closed, and this version has no Notification Center alerts.

Calendar and Reminders lists are not restored on launch. Click **Load Tasks** and **Connect Calendar** to load them again. Previously saved permission choices are managed by macOS.

Deleting the app bundle does not necessarily clear local preferences or records. There is currently no in-app reset or focus-record deletion control. Activity logs can be deleted separately.

## Troubleshooting

| Problem or message | What to check |
| --- | --- |
| Build fails | Confirm the required macOS version and Swift toolchain are installed. Run the script from this repository and include the Terminal error when reporting an issue. |
| Calendar or Reminders access was denied | Open **System Settings → Privacy & Security**, find the corresponding permission, and allow Pomodoro. Reopen the app if needed, then click **Load Tasks** or **Connect Calendar** as appropriate. System labels may vary by macOS version. |
| No tasks in the Reminders list | Click **Load Tasks** and read the status below it. Grant Reminders access if requested. If the list is empty, create an incomplete task in Apple Reminders and load again. |
| No Calendar picker | Click **Connect Calendar** and grant Calendar access. Confirm Apple Calendar has a calendar you can edit; read-only calendars are excluded. |
| **Connect to Calendar first.** | Click **Connect Calendar** and grant Calendar access before exporting. |
| **Select a writable calendar.** | Select an editable calendar. If the record has a saved destination that was deleted or became read-only, this version cannot reassign that record in the interface. |
| **This record already exists in Calendar.** | The duplicate check found the previously saved event. Check Apple Calendar instead of exporting it again. |
| Multiple records for one session | Each pause ends a focus segment. This preserves actual working time and excludes pause gaps. |
| Timer changed after reopening | A running countdown continues while the app is closed. Pause before quitting to preserve remaining time. |
| **End / Reset Session** did not clear history | This button resets the current phase only. History and the completed-session count remain saved. |
| No completion sound | Check system sound settings and whether the app was running. There are no notifications while the app is closed. |

If a problem persists, open a GitHub Issue with your macOS version, reproduction steps, and expected and actual behavior. Include the error message, but remove private task titles and calendar information.

## Current limitations

This version does not offer custom durations, daily statistics, charts, cross-device sync, automatic reminder completion, file export, or in-app deletion of focus records. Calendar authorization, Reminders authorization, and menu bar behavior require manual testing on macOS and are not covered by the timer unit tests.

## Activity Log

Click **Activity Log** below the calendar controls to view the latest 500 operations and sync results, newest first. Entries include app launches, task and calendar selections, timer actions, task-loading results, and calendar sync results with timestamps. These logs are saved on this Mac and may contain task titles and calendar names.

- Click the trash icon beside an entry to delete it permanently.
- Click **Clear All**, then **Delete All**, to remove all saved activity logs.
- Click **Done** to return to the timer.

Deleting activity logs does not remove focus records, pending sync requests, or events already saved in Apple Calendar. New actions create new log entries. The main view also shows Calendar permission status. If sync fails, check the corresponding activity entry and reconnect Calendar or select a writable calendar before retrying.
