//
//  WalkInDirector.swift
//  Abimo
//
//  The first-user walk-in: a one-time mascot-guided tour that leads a brand
//  new user to record their first idea and through the results. Deliberately
//  separate from MascotDirector — its one-popup-per-session cap and trigger
//  throttles would fight a multi-beat tour. MascotDirector defers to this
//  (see its fire() guard) so the two can never double-popup.
//
//  Each beat is a cheap conditional overlay on a screen the user reaches
//  through the real flow; all tour state lives here, views stay dumb.
//

import Foundation
import Combine

enum WalkInStep: String {
    case welcome    // center popup
    case record     // pulse on Record tab (elsewhere) + pitch bubble (on Record screen)
    case cooking    // pipeline in flight — tour stays silent
    case tasteTest  // beat cards inside SWOTAnalysisView
    case actionPlan // final nudge on the Actions tab
    case done       // completed OR skipped forever — terminal
}

@MainActor
final class WalkInDirector: ObservableObject {
    static let shared = WalkInDirector()

    /// nil = eligibility not yet determined this install.
    @Published private(set) var step: WalkInStep?
    /// The welcome popup payload; rendered by MainContentView while non-nil.
    @Published private(set) var welcomeMoment: MascotMoment?

    var isActive: Bool { step != nil && step != .done }

    private let stepKey = "walkin_step"
    /// Legacy first-welcome flag — set alongside ours so the old popup path
    /// can never fire again on top of the tour (double-popup guard).
    private let legacyWelcomeKey = "mascot_first_welcome_shown"

    private let defaults = UserDefaults.standard
    private let supabase = SupabaseService.shared
    private let analytics = AnalyticsService.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        step = defaults.string(forKey: stepKey).flatMap(WalkInStep.init(rawValue:))

        // Advance/park the tour as the pipeline finishes or fails. The tour
        // never shows UI while cooking — PipelineProgressView owns that moment.
        IdeaPipelineService.shared.$stage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stage in
                guard let self, self.step == .cooking else { return }
                switch stage {
                case .done:
                    self.advance(to: .tasteTest, completing: .cooking)
                case .failed:
                    // Quietly park: the pipeline's retry card owns the failure
                    // moment; the record-beat hints return if the user bails.
                    self.persist(.record)
                case .idle, .running:
                    break
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Eligibility

    /// Call once when the authenticated main screen appears. Decides whether
    /// this install ever sees the tour, or resumes a tour in progress.
    /// Nothing renders until this resolves, so there is no first-frame flash.
    ///
    /// Known accepted edge: UserDefaults is per-device, so signing into a
    /// different account inherits this install's tour state.
    func evaluateOnLaunch() async {
        if let step {
            switch step {
            case .welcome:
                // Killed before acknowledging — re-offer the popup.
                if welcomeMoment == nil {
                    welcomeMoment = MascotVoice.moment(for: .walkInWelcome)
                }
            case .cooking:
                // The pipeline never survives a relaunch. Promote: the taste
                // beats only render once an analysis is actually on screen.
                persist(.tasteTest)
            default:
                break
            }
            return
        }

        // Existing installs already had their first-touch moment — never tour.
        guard !defaults.bool(forKey: legacyWelcomeKey) else {
            persist(.done)
            return
        }

        // Authoritative server count — correctly skips a returning user on a
        // fresh device. On network error, stay undetermined and retry next launch.
        guard let count = try? await supabase.countVoiceNotes() else { return }
        if count == 0 {
            defaults.set(true, forKey: legacyWelcomeKey)
            persist(.welcome)
            welcomeMoment = MascotVoice.moment(for: .walkInWelcome)
            analytics.log(.walkInStarted)
        } else {
            persist(.done)
        }
    }

    // MARK: - Beat transitions (views call these; all logging lives here)

    func welcomeAcknowledged() {
        guard step == .welcome else { return }
        welcomeMoment = nil
        advance(to: .record, completing: .welcome)
    }

    /// The user submitted a recording — called from RecordingView.stopAndSave().
    func recordingSubmitted() {
        guard step == .record else { return }
        advance(to: .cooking, completing: .record)
    }

    /// Last taste-test beat card tapped away.
    func tasteTestFinished() {
        guard step == .tasteTest else { return }
        advance(to: .actionPlan, completing: .tasteTest)
    }

    /// "Got it" on the actions nudge — seeing it is enough, don't nag.
    func finishFinalBeat() {
        guard step == .actionPlan else { return }
        complete()
    }

    /// A micro-action was checked off while the final beat was showing.
    func microActionCompleted() {
        guard step == .actionPlan else { return }
        complete()
    }

    /// "Not now" from any beat: the tour ends forever, instantly and quietly.
    func skip() {
        guard isActive, let current = step else { return }
        welcomeMoment = nil
        persist(.done)
        analytics.log(.walkInSkipped(step: current.rawValue))
    }

    // MARK: - Internals

    private func advance(to next: WalkInStep, completing completed: WalkInStep) {
        persist(next)
        analytics.log(.walkInStepCompleted(step: completed.rawValue))
    }

    private func complete() {
        persist(.done)
        analytics.log(.walkInCompleted)
    }

    private func persist(_ new: WalkInStep) {
        step = new
        defaults.set(new.rawValue, forKey: stepKey)
    }
}
