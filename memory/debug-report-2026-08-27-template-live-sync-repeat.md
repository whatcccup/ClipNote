# Debug Report - 2026-08-27 - Template Live Sync and Repeat Clip

## Symptom
Changes to a template's note content in Settings did not refresh an already-open popup or embedded side panel. After the panel showed "Sent to Obsidian", the action appeared finished, so users could not safely add an updated note or regenerate Interpreter/LLM results.

## Root Cause
The open clipper panel only listened for local-storage highlight changes. It ignored sync-storage changes to `template_list` and chunked `template_*` records. Therefore, the currently selected template object and cached compiled note stayed stale.

Separately, successful and failed Interpreter runs permanently disabled the button. Auto-run also disabled the button, leaving no visible way to request a fresh LLM generation. Transcript completion retained any prior "sent" state even though its note data had changed.

## Fix
- Watch `storage.sync` template changes in `extension/src/core/popup.ts`, debounce the update, reload settings/templates, preserve the selected template ID where possible, invalidate compilation caches, clear stale save state, and rebuild fields.
- Reset Interpreter state when rebuilding the field skeleton.
- Clear stale saved status immediately before newly generated transcript data is inserted.
- Keep the Interpreter button enabled and clickable after auto-run or completion so users can explicitly regenerate. Rebinding removes the previous listener.
- When adding to Obsidian, wait for processing, reuse an existing completed Interpreter result without another hidden LLM call, and retry interpretation only when the previous attempt is not marked done.
- Clarify the sent status text in English and Simplified Chinese so another click means saving the updated note.

## Evidence
- Production Chrome build passed (`npm --prefix extension run build:chrome`) with the project's known bundle-size warnings; no build errors.
- Both `extension/dist/popup.html` and `extension/dist/side-panel.html` contain `<meta charset="UTF-8">`.
- All six Transcript Generator control IDs are present exactly once in each entry HTML.
- Source/dist garbled-character scan found no matches.
- `git diff --check` passed.
- No automated WebExtension storage-event/browser-panel test harness exists in this repository.

## Manual Regression Checklist
1. Open a video page, keep the clipper panel open, edit its matched template's note content in Settings, and return to the panel.
2. Confirm the note preview follows the updated template rather than showing the old cached format.
3. Generate once, click Interpret again, confirm the LLM call runs while processing, and then add to Obsidian twice without the second add silently invoking another LLM call.

## Status
DONE_WITH_CONCERNS: static/build checks pass, but real browser verification of cross-context storage events must be performed in Chrome.