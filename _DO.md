# Flux Development Task List

## Setup & Environment
[X] Verify Xcode is installed and configured
[X] Build and run app locally to test current state
[ ] Ensure all bundle IDs, project files, and internal references use Flux branding
[ ] Confirm documents directory is consistently ~/Documents/Flux

## Phase 1 - Critical Performance Fixes
[ ] Implement debounced auto-save (eliminate save-on-every-keystroke)
[ ] Create static DateFormatter cache
[ ] Remove redundant file read in saveEntry()
[ ] Test Phase 1 changes

## Phase 2 - High Value Optimizations
[ ] Implement partial file reading for previews (first 200 bytes only)
[ ] Replace regex with direct string parsing for filename parsing
[ ] Test Phase 2 changes

## Phase 3 - Polish & Refinements
[ ] Optimize preview generation (single-pass algorithm)
[ ] Add entry dictionary for O(1) lookup instead of linear search
[ ] Test Phase 3 changes

## Final
[ ] Full integration test of all optimizations
[ ] Performance validation and benchmarking

