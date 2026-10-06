// =====================================================================
// MICROTONAL SCALE LOADING
// ─────────────────────────────────────────────────────────────────────
// Add this block to ~/.config/SuperCollider/startup.scd
// Place it AFTER ~dirt.start(...) and s.sync
// =====================================================================

// Load scales (runs after SuperDirt is ready)
(
s.sync;

"  Loading microtonal scales...".postln;

// ── Quarter-comma meantone (default) ─────────────────────────────────
~addTuning.("/media/projects/Audio/MIDI+Tunings/Microtonal/scala/meanquar.scl");

// ── JI Modal scales ───────────────────────────────────────────────────
// Each folder contains 12 root-transpositions of that mode.
// e.g. "A JI Aeolian", "B JI Aeolian", "C JI Aeolian" etc.
~addTuningFolder.("/media/projects/Audio/MIDI+Tunings/Just Intonation/Aeolian");
~addTuningFolder.("/media/projects/Audio/MIDI+Tunings/Just Intonation/Dorian");
~addTuningFolder.("/media/projects/Audio/MIDI+Tunings/Just Intonation/Ionian");
~addTuningFolder.("/media/projects/Audio/MIDI+Tunings/Just Intonation/Lydian");
~addTuningFolder.("/media/projects/Audio/MIDI+Tunings/Just Intonation/Mixolydian");
~addTuningFolder.("/media/projects/Audio/MIDI+Tunings/Just Intonation/Phrygian");
~addTuningFolder.("/media/projects/Audio/MIDI+Tunings/Just Intonation/Locrian");
~addTuningFolder.("/media/projects/Audio/MIDI+Tunings/Just Intonation/Chromatic");

// ── JI Scales subfolders ─────────────────────────────────────────────
// Add more subfolders inside Scales/ as needed
~addTuningFolder.("/media/projects/Audio/MIDI+Tunings/Just Intonation/Scales/5-limit");
~addTuningFolder.("/media/projects/Audio/MIDI+Tunings/Just Intonation/Scales/Avaha Raba");

// ── Apply to all SuperDirt orbits ────────────────────────────────────
~applyMicrotonal.();

// ── Post summary ─────────────────────────────────────────────────────
"".postln;
"  Run ~listTunings.() at any time to see all scale names.".postln;
"  Use # scaleName \"name\" in Tidal to select.".postln;
"  Default scale (no # scaleName): \"meanquar\"".postln;
"".postln;
)

// ── To change default scale during performance ────────────────────────
// Run in SuperCollider:
//   ~defaultScale = "A JI Aeolian";
// All orbits without an explicit # scaleName will now use that scale.
