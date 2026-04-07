# Requirements: Abimo

**Defined:** 2026-04-07
**Core Value:** Users actually complete their micro-actions because the experience is engaging, rewarding, and fun — not another abandoned to-do list.

## v1.9 Requirements

Requirements for Settings & Profile milestone. Each maps to roadmap phases.

### Settings Screen

- [x] **SETT-01**: A dedicated Settings screen is accessible from the Profile tab via a gear icon in the navigation bar
- [x] **SETT-02**: Settings screen uses grouped sections with clear headers matching the app's visual style

### Notification Preferences

- [ ] **NPRF-01**: User can toggle inactivity reminder notifications on/off
- [ ] **NPRF-02**: User can toggle action nudge notifications on/off
- [ ] **NPRF-03**: User can toggle idea nudge notifications on/off
- [ ] **NPRF-04**: User can toggle streak notifications on/off
- [ ] **NPRF-05**: Toggle states persist across app launches (UserDefaults)
- [ ] **NPRF-06**: NotificationScheduler respects toggle states — disabled categories are not scheduled

### Data & Privacy

- [ ] **DATA-01**: User can delete their account with a confirmation dialog explaining the action is permanent
- [ ] **DATA-02**: Account deletion removes user data from Supabase and signs the user out
- [ ] **DATA-03**: User can clear local data (UserDefaults, cached preferences) with confirmation
- [ ] **DATA-04**: A privacy policy link is accessible and opens in an in-app browser or Safari

### App Info

- [ ] **INFO-01**: App version and build number are displayed (pulled from bundle)
- [ ] **INFO-02**: "Rate the App" opens the App Store review page
- [ ] **INFO-03**: "Send Feedback" opens a pre-filled email or feedback link
- [ ] **INFO-04**: An About/Credits screen or section is accessible

### Profile Stats

- [x] **STAT-01**: Profile screen shows real count of user's ideas (from Supabase data)
- [x] **STAT-02**: Profile screen shows real count of user's completed analyses (from Supabase data)

## Previous Milestones

### v1.8 (Complete)
- [x] Push notifications, notification copy with sass levels, all triggers wired

### v1.7 (Complete)
- [x] Ideas tab clarity, Actions tab onboarding, self-contained popovers, picker commitment framing

### v1.6 (Complete)
- [x] Unified mascot loading, analysis refresh, delete confirmation

### v1.5 (Complete)
- [x] Title consistency, real waveform, brand colors, discard button

## Out of Scope

| Feature | Reason |
|---------|--------|
| Notification scheduling UI (quiet hours, frequency) | Per-type toggles are sufficient for v1.9 — add timing controls later if needed |
| Appearance settings (dark mode, text size) | iOS system settings handle this — not enough value for v1.9 |
| Profile editing (name, avatar) | User model is email-only from Supabase auth — would need schema changes |
| Data export | Low user demand, complex implementation — revisit if requested |
| In-app feedback form | Email link is simpler and sufficient |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SETT-01 | Phase 27 | Complete |
| SETT-02 | Phase 27 | Complete |
| NPRF-01 | Phase 28 | Pending |
| NPRF-02 | Phase 28 | Pending |
| NPRF-03 | Phase 28 | Pending |
| NPRF-04 | Phase 28 | Pending |
| NPRF-05 | Phase 28 | Pending |
| NPRF-06 | Phase 28 | Pending |
| DATA-01 | Phase 29 | Pending |
| DATA-02 | Phase 29 | Pending |
| DATA-03 | Phase 29 | Pending |
| DATA-04 | Phase 29 | Pending |
| INFO-01 | Phase 29 | Pending |
| INFO-02 | Phase 29 | Pending |
| INFO-03 | Phase 29 | Pending |
| INFO-04 | Phase 29 | Pending |
| STAT-01 | Phase 27 | Complete |
| STAT-02 | Phase 27 | Complete |

**Coverage:**
- v1.9 requirements: 18 total
- Mapped to phases: 18
- Unmapped: 0

---
*Requirements defined: 2026-04-07*
