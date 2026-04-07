---
phase: 29-data-privacy-app-info
plan: 01
subsystem: ui
tags: [supabase, rpc, userdefaults, swiftui, privacy, account-deletion]

requires:
  - phase: 27-settings-profile
    provides: SettingsView shell rows and notification toggles
provides:
  - deleteAccount() RPC method in SupabaseService
  - deleteAccountAndSignOut() and clearLocalData() in AuthViewModel
  - Wired Data & Privacy section with confirmation alerts and privacy link
affects: [29-02-about-info]

tech-stack:
  added: []
  patterns: [supabase-rpc-account-deletion, removePersistentDomain-reset, local-auth-state-clearing]

key-files:
  created: []
  modified:
    - Abimo/Services/SupabaseService.swift
    - Abimo/ViewModels/AuthViewModel.swift
    - Abimo/Views/Settings/SettingsView.swift

key-decisions:
  - "Clear local auth state directly after RPC deletion instead of calling signOut() (Supabase Swift Issue #358/#404)"
  - "Use removePersistentDomain for UserDefaults reset instead of individual key deletion"
  - "Use Link view for privacy policy (opens in Safari) rather than in-app SFSafariViewController"

patterns-established:
  - "RPC account deletion: storage cleanup then server-side RPC, no client-side signOut"
  - "UserDefaults full reset: removePersistentDomain + re-register defaults"

requirements-completed: [DATA-01, DATA-02, DATA-03, DATA-04]

duration: 2min
completed: 2026-04-07
---

# Phase 29 Plan 01: Data & Privacy Summary

**Account deletion via Supabase RPC with storage cleanup, local data clearing via removePersistentDomain, and privacy policy Link to Safari**

## Performance

- **Duration:** 2 min
- **Started:** 2026-04-07T15:07:02Z
- **Completed:** 2026-04-07T15:08:26Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- SupabaseService.deleteAccount() lists/removes storage files then calls delete_user_account RPC
- AuthViewModel.deleteAccountAndSignOut() calls RPC then clears local state without signOut()
- AuthViewModel.clearLocalData() wipes UserDefaults via removePersistentDomain and re-registers notification defaults
- SettingsView Data & Privacy section fully wired with destructive confirmation alerts and privacy link

## Task Commits

Each task was committed atomically:

1. **Task 1: Add deleteAccount to SupabaseService and deleteAccountAndSignOut to AuthViewModel** - `75c54a2` (feat)
2. **Task 2: Wire Data & Privacy section in SettingsView with alerts, buttons, and privacy link** - `43bd75c` (feat)

## Files Created/Modified
- `Abimo/Services/SupabaseService.swift` - Added deleteAccount() with storage cleanup + RPC call
- `Abimo/ViewModels/AuthViewModel.swift` - Added deleteAccountAndSignOut() and clearLocalData() methods
- `Abimo/Views/Settings/SettingsView.swift` - Wired Data & Privacy section with buttons, alerts, and Link

## Decisions Made
- Clear local auth state directly after RPC deletion instead of calling signOut() -- user no longer exists server-side so signOut() would throw (per Supabase Swift Issue #358/#404)
- Use removePersistentDomain for complete UserDefaults reset rather than deleting individual keys -- future-proof against new keys
- Use SwiftUI Link view for privacy policy -- opens in Safari without SafariServices dependency

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- xcodebuild not available in CLI environment (Xcode not installed at active developer directory). Code was verified by manual inspection of syntax and structure. Build verification should be done in Xcode IDE.

## User Setup Required

**External services require manual configuration:**
- Run the `delete_user_account()` SQL function in Supabase SQL Editor (see RESEARCH.md for the full SQL)
- Without this RPC function, account deletion will fail at runtime

## Next Phase Readiness
- Data & Privacy section complete, ready for Plan 02 (About & App Info section)
- RPC function must be deployed to Supabase before testing account deletion

## Known Stubs
None -- all data flows are wired to real service calls and system APIs.

---
*Phase: 29-data-privacy-app-info*
*Completed: 2026-04-07*
