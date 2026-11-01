# Product content is not an artifact

S20 puts every artifact in English, and *Artifact* names "code" among the committed files it
covers — so, read literally, it also put a product's user-facing text in English. That is not a
harness decision. **Product content** — the text a product shows its users: UI strings (admin
included), emails, public pages and their metadata (`llms.txt`, JSON-LD, `<title>`), and error
messages surfaced to them — is therefore carved out of *Artifact*, and its language is the
product's to decide, recorded as a product invariant in `.agents/ubiquitous-language-invariants.md`.
Tests and fixtures quote product content verbatim; test names, comments and identifiers remain
artifacts and stay in English.

The carve-out lives in the scaffold's definition rather than in each project's `AGENTS.md`
because a project-owned file cannot exempt anything from a scaffold invariant: the review gate
reads S20 and the *Artifact* row as the authority, so a local exemption would still let a
reviewer flag every non-English string in a component as a hard violation.

## Considered Options

- **A per-project exemption line in `AGENTS.md`** — what the first downstream project tried. It
  does not bind the gate, for the reason above.
- **A bilingual exception in S20** — rejected by S20 itself ("no bilingual exception"), and it
  would reopen the question for artifacts, which this decision leaves untouched.
- **Every string literal outside S20** — simplest to state, but it exempts log messages, thrown
  internal errors and test names, which are written for a later developer, not for a user.
