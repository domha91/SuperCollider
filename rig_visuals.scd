// ============================================================
// rig_visuals.scd
// Timing fix for the SuperCollider -> visuals relay of startup.scd Section 3h
// File location: ~/.config/SuperCollider/rig_visuals.scd  (next to startup.scd)
//
// Loaded from startup.scd (RIG EXTENSIONS block), inside s.waitForBoot, after Section 3h.
// It REPLACES the OSCdef \visualSender of Section 3h (same name, so the later definition
// wins). It sends exactly the same /tidal/note message to the same place; only WHEN it
// is sent changes.
//
// WHY: Tidal sends every note to SuperDirt about 0.1 s BEFORE the note sounds (the
// message carries the time it is due; the gap was 100 to 138 ms in tests, depending on
// where in Tidal's 50 ms frame the note falls). Section 3h forwarded each note to the
// visuals the moment it arrived, so the visuals reacted that much ahead of the sound.
// This version waits until the note is due, using the same timestamp SuperDirt uses to
// schedule the sound itself.
//
// SC 3.11 HARD RULES apply here too (see the header of startup.scd): no var after
// statements, no var inside if-branches, no ^ early return in callbacks.
// ============================================================

// ── 1. SETTINGS (edit, save, reboot SC) ──────────────────────
~visualOffset = 0.0;       // seconds. + = visuals later than the sound, - = earlier.
                           // (Your visuals software may need a few ms of its own to draw a frame, and the
                           // sound leaves the speakers a little after the moment SuperCollider plays it.
                           // A small positive value, 0.01 to 0.03, may line the picture up better.)
~visualNotes  = 0;         // 1 = send /tidal/note (as today).  0 = do not send it at all, for when your visuals
                           // listen to /tidal/vis from rig_visuals.hs instead and would otherwise get every
                           // note twice. /mic/pitch is not affected either way.

// ── 2. THE RELAY ─────────────────────────────────────────────
OSCdef(\visualSender, { |msg, time, addr|
    var params, instrument, note, gain, pan, orbit, scaleName, cps, wait;
    params = ~parseDirtParams.(msg);
    instrument = (params[\s]         ?? { "unknown" }).asString;
    note       = (params[\note]      ?? { 0 }).asInteger;
    gain       = (params[\gain]      ?? { 0.5 }).asFloat;
    pan        = (params[\pan]       ?? { 0.5 }).asFloat;
    orbit      = (params[\orbit]     ?? { 0 }).asInteger;
    scaleName  = (params[\scaleName] ?? { "" }).asString;
    cps        = (params[\cps]       ?? { 0.0 }).asFloat;
    if(((gain > 0.01) && ~visualsEnabled) && (~visualNotes == 1), {
        // how long until this note sounds (the same sum SuperDirt does), then the offset
        wait = ((time - thisThread.seconds) + ~visualOffset).clip(0.0, 2.0);
        SystemClock.sched(wait, {
            ~visualNet.sendMsg("/tidal/note", instrument, note, 0.0, gain, pan, orbit, scaleName, cps);
            nil
        });
    });
}, '/dirt/play');

if(~visualNotes == 1, {
    "Visuals: /tidal/note is now sent when each note sounds (offset ".post;
    ~visualOffset.post;
    " s).".postln;
}, {
    "Visuals: /tidal/note is switched off (~visualNotes = 0). /mic/pitch is not affected.".postln;
});
