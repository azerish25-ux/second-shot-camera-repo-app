# Phase 12 — review originals and align their timelines

**Status: PLANNED.**

**Dependencies:** reliable storage, capture ledgers, and [phase-11 interruption handling](11-tracking-recovery.md). Read [alignment and export architecture](../architecture/alignment-and-export.md). Synthetic sample media can validate the interface before physical captures are available, but must be labeled.

## Outcome and limits

Give creators a useful result even when advanced alignment is inappropriate: two original takes, synchronized comparison, clear warnings, and a user-adjustable time offset. Review must expose mismatch rather than conceal it. This phase does not synthesize missing frames, apply optical-flow retiming, perform spatial registration, or claim that synchronized playback means identical camera motion.

## Implementation work

1. Implement `Sources/SecondShotCore/Review/TimelineMapping.swift` using rational media times. Define the sign convention once: `retakeTime = referenceTime + offset`. Derive the valid overlap from both assets' actual time ranges. Empty overlap, missing media, and invalid ledgers return typed failures rather than fabricated duration values.
2. Add a `ReviewSession` that holds immutable take identifiers, orientation information, the current offset, trim range, selected audio source, and review mode. Editing these choices creates a derived plan; original files and capture timestamps remain unchanged.
3. Build `Sources/SecondShotApp/Review/ReviewScreen.swift` with side-by-side, draggable wipe, and alternating-original views. Each panel names its take. Offer frame stepping, a shared playhead, and a visible reset-to-original action. Avoid making a tiny thumbnail the only way to judge a moving edge.
4. Load AV assets asynchronously and normalize display orientation through one tested adapter. Use actual presentation timestamps instead of assuming that sample number divided by nominal frame rate identifies every frame. Exact paused inspection and smooth playback are separate paths with separate tolerances.
5. Suggest an initial offset from capture-start metadata only where its meaning is established. Always permit manual correction in frame-sized increments. A visible marker or clap can help during testing; do not promise to align arbitrary actor actions or unrelated microphone recordings automatically.
6. Show tracking gaps, incomplete-take state, and lens/origin incompatibility alongside the timeline. Original-media comparison may remain available for incompatible origins; pose-based diagnostics must be disabled with a reason. Do not reject the creator's access to their own video because a spatial analysis cannot run.

## Interaction and failure behavior

Playback should pause when the app backgrounds or another modal action owns media. Cancelling an asset load must not replace a later selected project. Release observers and player resources when leaving review. If one clip cannot decode, keep the other available and offer file diagnostics, retry, or return to the project—never delete both. Separate playback audio selection from source-file ownership; changing “Listen to retake” must not modify audio in either original.

## Verification and provisional acceptance

- [ ] `TimelineMappingTests` cover positive/negative offsets, rational rates such as 30000/1001, unequal durations, no overlap, missing PTS, and boundaries exactly at the last valid sample.
- [ ] Generated synthetic clips contain frame numbers, a moving geometric marker, and timed audio pulses. Verify selected frames and waveform timing rather than trusting the player UI.
- [ ] Simulator UI tests cover comparison modes, large text, VoiceOver labels, slider/reset behavior, failed media loading, and navigation during an unfinished load.
- [ ] Proposed paused-seek target: the displayed pair is within one output frame of the chosen mapping on deterministic assets. Playback drift and seek accuracy are measured separately.
- [ ] Physical review checks at least portrait and landscape captures, muted audio, captured audio, an interrupted clip, and independently moving foreground content. Do not rate camera matching based solely on synchronized sound.

## Evidence and handoff

Record fixture generator version, expected/observed timestamps, original media dimensions, UI screenshots, and every incompatible-input result. Store consented real footage outside git. Commit the timeline core, review UI, and tests coherently; identify unsupported formats and hand off to [registration diagnostics](13-registration-diagnostics.md). Update status only with actual test evidence.

## Primary references

- [Apple: AVPlayer](https://developer.apple.com/documentation/avfoundation/avplayer).
- [Apple: CMTime](https://developer.apple.com/documentation/coremedia/cmtime).
