# Smart Todo v1.1 — Release Notes

**Version:** 1.1 (Build 2)
**Date:** March 2026
**Minimum iOS:** 26.0

---

## What's New

### Notes Integration with Share Extension
Import tasks directly from Apple Notes without leaving the app you're in. Select text in Notes, tap Share, and choose Smart Todo — your notes are analyzed and organized right inside the Share Extension.

- **AI-Powered Grouping** — Items are automatically grouped by where they can be completed (supermarket, pharmacy, hardware store, etc.) and turned into tasks with subtasks.
- **Full In-Extension Experience** — Review, select, and import grouped tasks without switching apps. See a Smart Todo-like interface with group cards, selection controls, and import progress.
- **Subtask Checkboxes** — Each imported item becomes a checkable subtask under its parent task, so you can track individual items as you complete them.
- **Secure with Face ID** — The Share Extension authenticates with Face ID (or device passcode) before importing, ensuring only authorized users can add tasks to your account.

### Subtasks Support
Tasks now support subtasks with individual checkboxes. Break down complex tasks into smaller actionable items and track progress on each one.

### Simplified Onboarding
The product tour and onboarding flow have been streamlined for a faster setup experience.

- **Reduced from 7 to 5 onboarding pages** — Notes Integration is now highlighted as the first feature after Welcome.
- **Streamlined guided tour** — Reduced from 7 to 5 steps, focusing on the actions that matter most: Notes Import, Add Task, and Points of Interest.
- **Smart Notifications & Location Alerts** combined into a single, clear onboarding page.

### In-App Notes Import
Paste or type text directly into Smart Todo using the Notes Import screen (accessible from the toolbar). AI analyzes and groups your text the same way the Share Extension does.

---

## Bug Fixes & Improvements

- **Fixed** — Time and Location notification tabs in Add/Edit Task now work correctly (resolved Swift type-checker issue with complex Form bodies).
- **Fixed** — App no longer crashes when accessing Face ID without a usage description.
- **Fixed** — Share Extension correctly falls back to device passcode when Face ID/Touch ID is unavailable.
- **Fixed** — Duplicate shared import checks on app foreground removed (was firing twice).
- **Fixed** — Thread-safety issue in Share Extension text collection resolved.
- **Fixed** — N+1 Core Data fetch when scheduling notifications for imported tasks eliminated.
- **Improved** — Removed unnecessary file existence check before reading shared import data (TOCTOU pattern).
- **Improved** — Dead state variables cleaned up from the app entry point.
- **Improved** — Contextual help added for the Notes Import screen with step-by-step guidance.

---

## App Store Compliance (carried over from v1.0 patch)

- **Guideline 1.5** — Primary support contact is now email (mailto:) with GitHub Issues as secondary.
- **Guideline 5.1.1** — Permission button labels updated ("Enable" → "Continue", "Skip for Now" → "Set Up Later").
- **Guideline 5.1.1(v)** — Account deletion feature added with full data wipe (Core Data + UserDefaults).

---

## Data Migration

Existing v1.0 users will have all their tasks, groups, and points of interest automatically preserved. Core Data lightweight migration handles the version transition seamlessly — no user action required.

---

## Privacy

All data remains on-device. AI processing, location matching, and notes analysis happen entirely locally. No data is sent to external servers.
