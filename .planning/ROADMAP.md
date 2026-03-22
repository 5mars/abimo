# Roadmap: Abimo

## Milestones

- ✅ **v1.0 Actions Flow Revamp** - Phases 1-4 (shipped 2026-03-19)
- ✅ **v1.1 Actions Flow UX** - Phases 5-8 (shipped 2026-03-20)
- ✅ **v1.2 Flow Polish** - Phases 9-10 (shipped 2026-03-21)
- ✅ **v1.3 Actions Polish** - Phases 11-13 (shipped 2026-03-21)
- ✅ **v1.4 Custom Tab Bar** - Phase 14 (shipped 2026-03-22)
- 🚧 **v1.5 UI Polish** - Phases 15-16 (in progress)

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

### 🚧 v1.5 UI Polish (In Progress)

**Milestone Goal:** Fix visual inconsistencies and improve the recording experience — consistent title colors, real waveform, brand-colored buttons, and proper cancel flow.

- [ ] **Phase 15: Title Consistency** - Black playful titles on all 4 main pages
- [ ] **Phase 16: Recording Page Polish** - Real waveform, brand colors, and always-visible cancel

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
- [ ] 15-01-PLAN.md — Apply .toolbarColorScheme(.light) to RecordingView, ActionsTabView, and ProfileView

### Phase 16: Recording Page Polish
**Goal**: The recording page shows a real audio-level waveform, uses brand colors on all buttons, and always displays a visible discard/cancel control whenever a recording exists
**Depends on**: Phase 15
**Requirements**: WAVE-01, BTNS-01, CANC-01
**Success Criteria** (what must be TRUE):
  1. Waveform bars during an active recording animate in direct response to microphone audio levels — quiet input produces short bars, loud input produces tall bars
  2. All recording controls (start, stop, lock-in, cancel) render in brand colors with no green visible anywhere
  3. A discard/cancel button is visible and tappable as soon as a recording begins, and remains visible after recording stops until the user takes an action
  4. Tapping discard clears the current recording and returns the page to its initial state, allowing the user to start a fresh recording
**Plans**: TBD

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
| 15. Title Consistency | v1.5 | 0/1 | Not started | - |
| 16. Recording Page Polish | v1.5 | 0/? | Not started | - |
