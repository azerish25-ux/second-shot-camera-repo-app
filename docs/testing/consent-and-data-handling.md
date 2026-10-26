# Phase 01 — consent and data handling

**Status: DRAFTED, NOT IN FORCE.** No participant has been recruited and no data
exists. This document must be reviewed by the owner before any outreach. It is
plain-language engineering text, **not legal advice**; the owner confirms that the
final wording satisfies the rules of the jurisdiction where the study runs.

## 1. Who this covers

Study participants (the [usefulness protocol](phase-01-protocol.md)) and
interview participants ([interview guide](interview-guide.md)). Participants are
identified in all records by a code (`P01`…`P10`); the mapping from code to person
lives in a single owner-controlled file outside this repository.

## 2. What is collected, why, and for how long

| Data | Why | Where it lives | Retention |
| --- | --- | --- | --- |
| Participant code | Link cases to one person without names | Sanitized records in `docs/reports` | Kept |
| Consent record (name, contact, signature, date) | Prove consent and allow withdrawal | Owner-controlled location, **never** this repository | Until withdrawal + 12 months, then deleted |
| Attempt ledger (scenario, condition, attempt number, outcome) | The study's measurements | Restricted evidence area, then sanitized copy committed | Sanitized subset kept |
| Raw video/photo/audio of a scene | Review the reproductions | Restricted evidence area only | Deleted within 30 days of the analysis freeze |
| World maps / AR maps | Diagnose relocalisation behaviour when relevant | Restricted evidence area only | Deleted with the raw media |
| Device identifiers, device model/OS build | Reproduce a technical result | Redacted technical summary; no serial numbers or advertising identifiers | Model/OS build only |
| Interview notes, quotes | Hypothesis generation | Restricted area, then sanitized quotes | Deletion on request |
| Interview/session audio or screen recording | Only if separately approved | Restricted area | Deleted with the raw media |

Sanitized means: no faces, no names, no address or location, no room geometry,
no private interiors, no audio of bystanders, no device serial number, no
contact details. Sanitized results under `docs/reports` may be public.

## 3. Separate decisions the participant makes

Each of these is asked and recorded on its own line. Refusing any single one does
not end participation:

1. **Experiment participation** — attempt the scenarios in both conditions.
2. **Interview** — answer questions about their own workflow.
3. **Scene footage retention** — may the recorded clips be kept for review, for
   the stated retention window?
4. **Public/marketing use** — may this specific clip or quote be published with
   attribution removed? Revocable, per clip, at any time.
5. **Optional audio/screen recording** of the session itself.

## 4. Withdrawal

- A participant may withdraw at any moment, for any reason or none, with no
  consequence and no explanation required.
- Withdrawal route: the same channel used to arrange the session, plus the
  written contact on the consent form (no secret channel; no chat tool that
  requires an account the participant lacks).
- On withdrawal: collected raw media for that participant is deleted, their case
  rows are removed from the analysis, and the aggregate reports state that one
  participant withdrew without identifying them. Consent records are retained
  only as long as needed to prove the deletion happened.
- Withdrawal is available after the session too; the deletion deadline is
  honoured from the date of the request.

## 5. Risks, safety and what the app does not do

Participants are told in plain language, before starting:

- The app being tested is an **early synthetic demonstration**. It does not yet
  record real camera footage and makes no claim about repeating a real move.
- They move slowly on level, clear ground, on a route they can see, and may stop
  at any time. No stairs, roads, walking backwards or obstacles.
- A spotter helps when the operator is looking at the phone.
- Physical risks are minimal but real: walking while holding a phone, dropping
  the device, and heat or battery drain on long sessions. Any discomfort ends
  the session immediately.
- No footage, map or measurement is uploaded to any server by the app in this
  build; nothing about the study is sent outside the locations in §2.
- They receive no product, no payment and no promise of one unless the owner
  separately approved compensation (§8).

## 6. Data protection in practice

- Restricted evidence area: owner-approved storage, access limited to the owner
  and named reviewers, not a public GitHub Actions artifact, not a public bucket.
- This repository holds only sanitized summaries, synthetic reproductions and
  references that reveal no private material.
- `docs/reports` entries name the retention deadline and the access conditions.
- Deletion is actually performed and dated; the deletion is recorded without
  retaining the deleted content.
- Reviewers see condition-hidden outputs where feasible and sign the same
  confidentiality conditions.

## 7. Consent form outline (to be completed by the owner)

1. Study title, version, date, contact for the study owner.
2. What the study is and is not (synthetic demo; usefulness study planned later).
3. What happens in the session: scenarios, attempts, timing, two reviewers.
4. Data items, locations, retention window, who can see them.
5. The five separate permissions in §3, each with its own yes/no.
6. Right to withdraw, how, and what happens to existing data.
7. Safety instructions and stop conditions.
8. No guarantee of a product, feature or purchase; no compensation unless
   explicitly written here.
9. Participant signature and date; owner/coordinator signature and date.
10. A copy is offered to the participant.

## 8. Authority boundaries

- Owner approval is required before: recruiting or contacting anyone, offering
  any compensation, publishing participant material, or running the session as a
  real study rather than a rehearsal.
- Compensation, if any, is arranged by the owner; the agent does not promise it.
- Nothing in this phase authorizes TestFlight, store distribution, paid
  services, or collection of payment information.

## 9. Rehearsal mode

Two repository contributors may dry-run the protocol against each other with no
data collection and no publication. Such a run is labelled **rehearsal**,
produces at most sanitized notes, and must never be reported as a participant
result or as evidence toward G1/G2.
