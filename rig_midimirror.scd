// ============================================================
// rig_midimirror.scd
// Timing fix for the Microkorg MIDI sender of startup.scd Section 3f (\midiMirror)
// File location: ~/.config/SuperCollider/rig_midimirror.scd  (next to startup.scd)
//
// Loaded from startup.scd (RIG EXTENSIONS block), inside s.waitForBoot, after Section 3f.
// It REPLACES the OSCdef \midiMirror of Section 3f (same name, so the later definition
// wins). Same notes, same channel, same velocity, same note length; only WHEN the note
// goes out changes.
//
// WHY: Tidal sends every note to SuperDirt about 0.1 s BEFORE the note is due (the message
// carries the time it should sound; the gap was 100 to 138 ms in tests, depending on where in
// Tidal's 50 ms frame the note falls). Section 3f sent the MIDI note the moment the message
// arrived, so the Microkorg played that much EARLIER than the SuperDirt voices in the same
// pattern group. This version waits until the note is due, using the same timestamp SuperDirt
// uses to schedule its own sound.
//
// SC 3.11 HARD RULES apply here too (see the header of startup.scd).
// ============================================================

// ── 1. SETTINGS (edit, save, reboot SC) ──────────────────────
~midiOffset = 0.0;     // seconds. + = Microkorg later, - = earlier. The Microkorg's sound travels MIDI out ->
                       // synth -> audio in -> JACK -> SuperCollider -> speakers, which takes longer than a
                       // SuperDirt voice, so a small NEGATIVE value should line it up. How small depends on
                       // your JACK buffer size: try -0.010, then adjust by ear or against a recording.

// ── 2. THE SENDER ────────────────────────────────────────────
OSCdef(\midiMirror, { |msg, time, addr|
    var params, midiNote, midiVel, midiChan, dur, sName, wait;
    params = ~parseDirtParams.(msg);
    sName  = (params[\s] ?? { "" }).asString;
    if((sName == "microkorg") || (sName == "external") || (sName == "midihub"), {
        if(~midiOutPort.notNil, {
            midiNote = (params[\note] ?? { 0 }).asInteger + 60;
            midiVel  = ((params[\amp] ?? { 0.7 }) * 127).clip(1,127).asInteger;
            midiChan = (params[\midichan] ?? { 0 }).asInteger;
            dur      = (params[\sustain] ?? { 0.25 }).asFloat;
            midiNote = midiNote.clip(0,127);
            // how long until this note is due (the same sum SuperDirt does), then the offset
            wait = ((time - thisThread.seconds) + ~midiOffset).clip(0.0, 2.0);
            SystemClock.sched(wait, {
                ~midiOutPort.noteOn(midiChan, midiNote, midiVel);
                ("MIDI out -> ch:" ++ midiChan ++ " note:" ++ midiNote ++ " vel:" ++ midiVel ++ " dur:" ++ dur.round(0.01)).postln;
                SystemClock.sched(dur, { ~midiOutPort.noteOff(midiChan, midiNote, 0); nil });
                nil
            });
        }, {
            "WARNING: midiMirror fired but ~midiOutPort is nil (Midihub never connected).".postln;
        });
    });
}, '/dirt/play');

"MIDI mirror: Microkorg notes are now sent when each note is due (offset ".post;
~midiOffset.post;
" s).".postln;
