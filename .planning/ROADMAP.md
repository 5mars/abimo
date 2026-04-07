# Roadmap: Abimo

## Milestones

- ✅ **v1.0 Actions Flow Revamp** - Phases 1-4 (shipped 2026-03-19)
- ✅ **v1.1 Actions Flow UX** - Phases 5-8 (shipped 2026-03-20)
- ✅ **v1.2 Flow Polish** - Phases 9-10 (shipped 2026-03-21)
- ✅ **v1.3 Actions Polish** - Phases 11-13 (shipped 2026-03-21)
- ✅ **v1.4 Custom Tab Bar** - Phase 14 (shipped 2026-03-22)
- ✅ **v1.5 UI Polish** - Phases 15-16 (shipped 2026-03-27)
- ✅ **v1.6 Bug Fixes & Polish** - Phases 17-19 (shipped 2026-03-27)
- ✅ **v1.7 UX Clarity** - Phases 20-23 (shipped 2026-03-29)
- ✅ **v1.8 Notifications** - Phases 24-26 (shipped 2026-03-30)
- 🚧 **v1.9 Settings & Profile** - Phases 27-29

## Phases

<details>
<summary>✅ v1.0 Actions Flow Revamp (Phases 1-4) - SHIPPED 2026-03-19</summary>

- [x] Phase 1: Foundation (2/2 plans) — completed 2026-03-18
- [x] Phase 2: Journey Path and Action Cards (3/3 plans) — completed 2026-03-19
- [x] Phase 3: Celebration System (2/2 plans) — completed 2026-03-19
- [x] Phase 4: Polish (1/1 plan) — completed 2026-03-19

</details>

<details>
<summary>✅ v1.1 Actions Flow UX (Phases 5-8) - SHIPPED 2026-03-20</summary>

- [x] Phase 5: ViewModel Foundation and Ordering Model (2/2 plans) — completed 2026-03-19
- [x] Phase 6: Tap Bubbles on Nodes (1/1 plan) — completed 2026-03-19
- [x] Phase 7: Action Picker Sheet (1/1 plan) — completed 2026-03-19
- [x] Phase 8: Two-Step Completion Sheet and Full Wiring (2/2 plans) — completed 2026-03-20

</details>

<details>
<summary>✅ v1.2 Flow Polish (Phases 9-10) - SHIPPED 2026-03-21</summary>

- [x] Phase 9: Recording Flow Polish (1/1 plan) — completed 2026-03-21
- [x] Phase 10: SWOT and Action Plan Flow (2/2 plans) — completed 2026-03-21

</details>

<details>
<summary>✅ v1.3 Actions Polish (Phases 11-13) - SHIPPED 2026-03-21</summary>

- [x] Phase 11: Tooltip Overhaul and Action Switching (1/1 plan) — completed 2026-03-21
- [x] Phase 12: Path Curves and Actions Tab Cleanup (2/2 plans) — completed 2026-03-21
- [x] Phase 13: All-Actions View and Unified Switching (1/1 plan) — completed 2026-03-21

</details>

<details>
<summary>✅ v1.4 Custom Tab Bar (Phase 14) - SHIPPED 2026-03-22</summary>

- [x] Phase 14: Custom Tab Bar (2/2 plans) — completed 2026-03-22

</details>

<details>
<summary>✅ v1.5 UI Polish (Phases 15-16) - SHIPPED 2026-03-27</summary>

- [x] Phase 15: Title Consistency (1/1 plan) — completed 2026-03-22
- [x] Phase 16: Recording Page Polish (2/2 plans) — completed 2026-03-27

</details>

<details>
<summary>✅ v1.6 Bug Fixes & Polish (Phases 17-19) - SHIPPED 2026-03-27</summary>

- [x] Phase 17: Loading Experience (2/2 plans) — completed 2026-03-27
- [x] Phase 18: Analysis Refresh — merged into Phase 17
- [x] Phase 19: Ideas List Polish — merged into Phase 17

</details>

<details>
<summary>✅ v1.7 UX Clarity (Phases 20-23) - SHIPPED 2026-03-29</summary>

- [x] Phase 20: Ideas Tab Clarity (1/1 plan) — completed 2026-03-29
- [x] Phase 21: Actions Tab Clarity (1/1 plan) — completed 2026-03-29
- [x] Phase 22: Action Node & Detail Redesign (2/2 plans) — completed 2026-03-29
- [x] Phase 23: Action Picker Clarity (1/1 plan) — completed 2026-03-29

</details>

<details>
<summary>✅ v1.8 Notifications (Phases 24-26) - SHIPPED 2026-03-30</summary>

- [x] Phase 24: Notification Infrastructure (2/2 plans) — completed 2026-03-30
- [x] Phase 25: Copy & Mood System (1/1 plan) — completed 2026-03-30
- [x] Phase 26: Notification Triggers (2/2 plans) — completed 2026-03-30

</details>

### 🚧 v1.9 Settings & Profile (In Progress)

**Milestone Goal:** Transform the bare Profile tab into a proper settings experience with notification controls, data & privacy management, app info, and real profile stats.

- [x] **Phase 27: Settings Screen & Profile Stats** - Dedicated settings screen with gear icon navigation, wire up real idea/analysis counts (completed 2026-04-07)
- [ ] **Phase 28: Notification Preferences** - Per-type notification toggles with UserDefaults persistence, wire into NotificationScheduler
- [ ] **Phase 29: Data, Privacy & App Info** - Delete account, clear local data, privacy policy link, version, rate app, feedback, about

## Phase Details

### Phase 15: Title Consistency
**Goal**: All main page navigation titles render in black with the playful rounded font, eliminating the white-on-pink visibility issue
**Depends on**: Phase 14
**Requirements**: TITL-01
**Success Criteria** (what must be TRUE):
  1. Each of the 4 main pages (Ideas, Record, Actions, Profile) displays its navigation title in black
  2. The title font matches the existing playful rounded style used by "The Lab" header
  3. No white title text appears on any main page regardless of scroll position or sheet state
**Plans**: 1 plan

Plans:
- [x] 15-01-PLAN.md — Apply .toolbarColorScheme(.light) to RecordingView, ActionsTabView, and ProfileView

### Phase 16: Recording Page Polish
**Goal**: The recording page shows a real audio-level waveform, uses brand colors on all buttons, and always displays a visible discard/cancel control whenever a recording exists
**Depends on**: Phase 15
**Requirements**: WAVE-01, BTNS-01, CANC-01
**Success Criteria** (what must be TRUE):
  1. Waveform bars during an active recording animate in direct response to microphone audio levels — quiet input produces short bars, loud input produces tall bars
  2. All recording controls (start, stop, lock-in, cancel) render in brand colors with no green visible anywhere
  3. A discard/cancel button is visible and tappable as soon as a recording begins, and remains visible after recording stops until the user takes an action
  4. Tapping discard clears the current recording and returns the page to its initial state, allowing the user to start a fresh recording
**Plans**: 2 plans

Plans:
- [x] 16-01-PLAN.md — Waveform sensitivity fix and green-to-brand color replacement
- [x] 16-02-PLAN.md — Unified discard pill button, waveform fix, and visual verification

### Phase 17: Loading Experience
**Goal**: All loading states use a unified mascot loading component that fills its container, shows contextual text, and never coexists with the navigation bar
**Depends on**: Phase 16
**Requirements**: LOAD-01, LOAD-02, LOAD-03, LOAD-04
**Success Criteria** (what must be TRUE):
  1. A reusable MascotLoadingView exists with large mascot image and configurable text, filling its parent
  2. App launch transitions from splash → full-page mascot loading (no navbar) → app content
  3. SWOT analysis loading within sheets uses MascotLoadingView with consistent background
  4. No loading screen + navbar flash when dismissing sheets or navigating back
**Plans**: 2 plans

Plans:
- [x] 17-01-PLAN.md — MascotLoadingView with fullscreen/inline modes, update all loading locations
- [x] 17-02-PLAN.md — SWOT analysis refresh, delete confirmation, NoteDetailView layout fix

### Phase 18: Analysis Refresh
**Goal**: Closing the SWOT analysis sheet immediately refreshes the idea detail view to show completed analysis
**Depends on**: Phase 17
**Requirements**: REFR-01
**Success Criteria** (what must be TRUE):
  1. After SWOT analysis completes and the sheet is dismissed, the idea detail page shows the analysis — not "Run it through the lab"
  2. No need to exit and return to the idea for the analysis to appear
**Plans**: TBD (via /gsd:plan-phase 18)

### Phase 19: Ideas List Polish
**Goal**: Swipe-to-delete on the ideas list is smooth with no flicker, and requires user confirmation before deletion
**Depends on**: Phase 16 (independent of 17-18)
**Requirements**: LIST-01, LIST-02
**Success Criteria** (what must be TRUE):
  1. Swiping to delete an idea produces no list flicker or visual glitches
  2. A confirmation dialog appears before an idea is actually deleted
  3. Canceling the dialog preserves the idea in its original position
**Plans**: TBD (via /gsd:plan-phase 19)

### Phase 20: Ideas Tab Clarity
**Goal**: The Ideas tab instantly communicates "this is where your ideas live" with clear status progression and a guided empty state
**Depends on**: Phase 19
**Requirements**: IDEA-01, IDEA-02, IDEA-03
**Success Criteria** (what must be TRUE):
  1. Header and section labels use plain language that immediately identifies this as the ideas space
  2. Idea cards show clear status progression (not just binary "Fresh"/"Analyzed")
  3. Empty state explains what to do with a single clear CTA
**Plans**: 1 plan

Plans:
- [ ] 20-01-PLAN.md — Header subtitle, section label, status badges, mascot empty state, card next-step hints

### Phase 21: Actions Tab Clarity
**Goal**: First-time and returning users understand what actions are, why they matter, and what to do next
**Depends on**: Phase 20
**Requirements**: ACTN-01, ACTN-02, ACTN-03
**Success Criteria** (what must be TRUE):
  1. New users see contextual explanation of actions before the empty state
  2. Action plan cards clearly show progress and next step
  3. All CTAs use motivating, specific language
**Plans**: TBD (via /gsd:plan-phase 21)

### Phase 22: Action Node & Detail Redesign
**Goal**: Tapping an action node provides structured, guided information that makes completing the action feel obvious
**Depends on**: Phase 21
**Requirements**: NODE-01, NODE-02, NODE-03, DETL-01, DETL-02, DETL-03
**Success Criteria** (what must be TRUE):
  1. Node interaction shows action name, description, how Abimo helps, and a clear CTA
  2. No ambiguous "More" button — detail content is integrated or clearly labeled
  3. Locked nodes explain specifically what's needed to unlock
  4. Action detail leads with what to DO, not what the action IS
  5. Template/deep link are presented as primary help, not hidden below fold
**Plans**: 2 plans

Plans:
- [ ] 22-01-PLAN.md — Redesign NodeBubbleView: self-contained with deep links + Mark Complete
- [ ] 22-02-PLAN.md — Below-node positioning, scroll-to-view, remove ActionDetailSheet

### Phase 23: Action Picker Clarity
**Goal**: The action picker communicates why picking matters, gives enough context to choose, and uses motivating language
**Depends on**: Phase 22
**Requirements**: PICK-01, PICK-02, PICK-03
**Success Criteria** (what must be TRUE):
  1. Picker header frames selection as commitment, not just choice
  2. Each action shows time estimate and brief context
  3. Confirm button uses specific, motivating language
**Plans**: TBD (via /gsd:plan-phase 23)

### Phase 24: Notification Infrastructure
**Goal**: Push notification permission flow and a local scheduling service that can schedule, cancel, and attach mascot images to notifications
**Depends on**: Phase 23
**Requirements**: NOTIF-01, NOTIF-02, NOTIF-03
**Success Criteria** (what must be TRUE):
  1. App requests notification permission at an appropriate moment (first launch or first plan creation)
  2. A NotificationService exists that schedules and cancels local notifications
  3. Notifications include the mascot image as an attachment when supported
**Plans**: 2 plans

Plans:
- [ ] 24-01-PLAN.md — NotificationService singleton with scheduling, cancellation, mascot attachment
- [ ] 24-02-PLAN.md — Pre-permission mascot screen + RootView integration

### Phase 25: Copy & Mood System
**Goal**: A notification copy engine with multiple message variants per trigger, organized by sass level, with a MascotMood enum for future asset variants
**Depends on**: Phase 24
**Requirements**: COPY-01, COPY-02, COPY-03, MOOD-01, MOOD-02, MOOD-03
**Success Criteria** (what must be TRUE):
  1. NotificationCopy provides messages organized by trigger type and sass level (playful, sassy, guilt-trip)
  2. MascotMood enum maps to asset names (using MascotNeutral as placeholder)
  3. Each message has a title and body with personality
**Plans**: TBD (via /gsd:plan-phase 25)

### Phase 26: Notification Triggers
**Goal**: Wire all notification triggers — inactivity (1/3/7+ days), incomplete actions (24h), unanalyzed ideas (24h), streak-at-risk, and streak milestones
**Depends on**: Phase 25
**Requirements**: INACT-01–04, ACTN-01–02, IDEA-01–02, STRK-01–02
**Success Criteria** (what must be TRUE):
  1. Inactivity notifications fire at 1, 3, and 7+ days with escalating sass
  2. Opening the app cancels pending inactivity notifications and reschedules
  3. Incomplete action nudges fire 24h after commitment
  4. Unanalyzed idea nudges fire 24h after recording
  5. Streak-at-risk fires in the evening if no action completed today
  6. Streak milestone notifications fire at 3, 7, 14, 30 days
**Plans**: TBD (via /gsd:plan-phase 26)

### Phase 27: Settings Screen & Profile Stats
**Goal**: A dedicated Settings screen accessible from Profile via gear icon, with real idea/analysis counts on the Profile hero card
**Depends on**: Phase 26
**Requirements**: SETT-01, SETT-02, STAT-01, STAT-02
**Success Criteria** (what must be TRUE):
  1. A gear icon in the Profile navigation bar opens a separate Settings screen
  2. Settings screen uses grouped sections with headers matching the app's visual style
  3. Profile stats show real counts of ideas and analyses pulled from data
**Plans**: 1 plan

Plans:
- [x] 27-01-PLAN.md — SettingsView shell, Supabase count queries, gear icon + real stats in ProfileView

### Phase 28: Notification Preferences
**Goal**: Users can toggle each notification category on/off from Settings, and the notification scheduler respects those preferences
**Depends on**: Phase 27
**Requirements**: NPRF-01, NPRF-02, NPRF-03, NPRF-04, NPRF-05, NPRF-06
**Success Criteria** (what must be TRUE):
  1. Settings screen has toggles for inactivity reminders, action nudges, idea nudges, and streak notifications
  2. Toggle states persist across app launches via UserDefaults
  3. NotificationScheduler skips scheduling for disabled categories
  4. Toggling a category off cancels any pending notifications for that category
**Plans**: TBD (via /gsd:plan-phase 28)

### Phase 29: Data, Privacy & App Info
**Goal**: Settings screen includes data & privacy controls (delete account, clear local data, privacy policy) and app info (version, rate, feedback, about)
**Depends on**: Phase 28
**Requirements**: DATA-01, DATA-02, DATA-03, DATA-04, INFO-01, INFO-02, INFO-03, INFO-04
**Success Criteria** (what must be TRUE):
  1. "Delete Account" shows confirmation dialog, deletes Supabase user data, and signs out
  2. "Clear Local Data" resets UserDefaults with confirmation
  3. Privacy policy link opens in Safari or in-app browser
  4. App version and build number are displayed
  5. "Rate the App" opens App Store review page
  6. "Send Feedback" opens pre-filled email
  7. About/Credits section is accessible
**Plans**: TBD (via /gsd:plan-phase 29)

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Foundation | v1.0 | 2/2 | Complete | 2026-03-18 |
| 2. Journey Path and Action Cards | v1.0 | 3/3 | Complete | 2026-03-19 |
| 3. Celebration System | v1.0 | 2/2 | Complete | 2026-03-19 |
| 4. Polish | v1.0 | 1/1 | Complete | 2026-03-19 |
| 5. ViewModel Foundation and Ordering Model | v1.1 | 2/2 | Complete | 2026-03-19 |
| 6. Tap Bubbles on Nodes | v1.1 | 1/1 | Complete | 2026-03-19 |
| 7. Action Picker Sheet | v1.1 | 1/1 | Complete | 2026-03-19 |
| 8. Two-Step Completion Sheet and Full Wiring | v1.1 | 2/2 | Complete | 2026-03-20 |
| 9. Recording Flow Polish | v1.2 | 1/1 | Complete | 2026-03-21 |
| 10. SWOT and Action Plan Flow | v1.2 | 2/2 | Complete | 2026-03-21 |
| 11. Tooltip Overhaul and Action Switching | v1.3 | 1/1 | Complete | 2026-03-21 |
| 12. Path Curves and Actions Tab Cleanup | v1.3 | 2/2 | Complete | 2026-03-21 |
| 13. All-Actions View and Unified Switching | v1.3 | 1/1 | Complete | 2026-03-21 |
| 14. Custom Tab Bar | v1.4 | 2/2 | Complete | 2026-03-22 |
| 15. Title Consistency | v1.5 | 1/1 | Complete    | 2026-03-22 |
| 16. Recording Page Polish | v1.5 | 2/2 | Complete | 2026-03-27 |
| 17. Loading Experience | v1.6 | 2/2 | Complete | 2026-03-27 |
| 18. Analysis Refresh | v1.6 | — | Merged into P17 | 2026-03-27 |
| 19. Ideas List Polish | v1.6 | — | Merged into P17 | 2026-03-27 |
| 20. Ideas Tab Clarity | v1.7 | 0/1 | Planned | |
| 21. Actions Tab Clarity | v1.7 | 1/1 | Complete | 2026-03-29 |
| 22. Action Node & Detail Redesign | v1.7 | 2/2 | Complete | 2026-03-29 |
| 23. Action Picker Clarity | v1.7 | 1/1 | Complete | 2026-03-29 |
| 24. Notification Infrastructure | v1.8 | 2/2 | Complete | 2026-03-30 |
| 25. Copy & Mood System | v1.8 | 1/1 | Complete | 2026-03-30 |
| 26. Notification Triggers | v1.8 | 2/2 | Complete | 2026-03-30 |
| 27. Settings Screen & Profile Stats | v1.9 | 1/1 | Complete   | 2026-04-07 |
| 28. Notification Preferences | v1.9 | 0/0 | Planned | |
| 29. Data, Privacy & App Info | v1.9 | 0/0 | Planned | |
