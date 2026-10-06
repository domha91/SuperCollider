// ============================================================
// startup.scd
// Renaissance Counterpoint Live Performance System
// SuperCollider 3.11.2 / SuperDirt 1.7.2 / TidalCycles 1.9.5
// JACK 48000 Hz / Rubix24 interface (4 in, 4 out)
// File location: ~/.config/SuperCollider/startup.scd
//
// EZ-CREATOR FADE — STRIPPED TO SINGLE-BANK OPERATION (this version):
//   The 4-bank virtual-banking system (bank SysEx tracking, ~ezBank-routed
//   knobs, the bank-2/3 CC18-26 mute firmware workaround) has been removed
//   entirely. It never reliably worked and isn't needed to perform.
//   ALL EZ-Creator CCs stay on 0–17 regardless of which physical bank the
//   hardware is on (confirmed hardware fact — CCs never shift), so this
//   simplified handler set just always treats incoming CCs/notes as bank-1
//   meanings. Practical implication: leave the hardware on bank 1 (or 4 —
//   both send mutes as NoteOn). If the physical bank button is pressed to
//   bank 2/3, mutes go quiet (they'd arrive as CC 18-26, unhandled here)
//   until switched back — everything else (faders/knobs) is unaffected
//   either way, since those CCs are identical across all banks.
//
// CC MAP (single bank only):
//   CC 0–7  : Faders 1–8  → orbit gain d1–d8
//   CC 8    : V Fader     → live gain (mic + Microkorg), starts at 0
//   CC 9–16 : Knobs 1–8   → orbit reverb mix d1–d8
//   CC 17   : V Knob      → V channel (mic+Microkorg) reverb mix
//   Notes 36–44 : Mute buttons d1–d8 + V (NoteOn, debounced — see below)
//
// Orbit-level reverb size/damp and mic/Microkorg size/damp/tremolo
// (formerly bank 2/3/4 knobs) are no longer hardware-controlled. They
// keep the fixed defaults set where the synths are created below. Change
// the default and reboot if you want a different fixed value.
//
// MUTE DEBOUNCE: hardware fires 3 MIDI messages per physical mute press
// (confirmed via diagnostic, not bank-specific). ~ezMuteTime + a 300ms
// window per button absorbs the burst without needing bank tracking.
//
// SC 3.11 HARD RULES (never violate):
//   - No var declarations after any statement in a function body.
//   - No var declarations inside if/else branch blocks { } — SC 3.11
//     hoists ALL vars to the enclosing function frame regardless of
//     which branch they appear in. Multiple var sz/r/d across branches
//     collapse and corrupt each other. Always declare at top of the
//     outer function, before any statements.
//   - MIDIdef.noteOn in SC 3.11 catches NoteOff vel:0 as well as genuine
//     NoteOn. Always add a vel > 63 guard: { |vel| if(vel > 63, { ... }) }
//     to prevent double-firing on press+release.
//   - No doWithIndex — use do with manual counter.
//   - Integer division: .div(n) not // (// is a line comment).
//   - MIDIOut requires .connect before .sysex.
//   - NO SystemClock.sched inside SysEx callbacks — crashes silently.
//   - NO ^nil (or any ^ early return) inside ANY MIDI callback -- noteOn,
//     cc, SysEx, all of them. A `^` unwinds the whole dispatch call for
//     that event with no error printed, silently skipping every handler
//     registered after it. This once left every MPD218 handler dead:
//     the Launchpad's all-devices handlers used `if(src != ..., { ^nil })`.
//     Use a positive if(cond, { ... }) guard instead.
//   - Everything inside s.waitForBoot({ ... }).
// ============================================================


// ============================================================
// 1. SERVER OPTIONS
// ============================================================
s = Server.default;

s.options.device               = "SuperCollider";
s.options.sampleRate           = 48000;
s.options.blockSize            = 256;
s.options.numOutputBusChannels = 4;
// Was 4. Only SoundIn(0) (Microkorg) and SoundIn(1) (mic) are used anywhere
// in this file -- confirmed by searching the whole DSP code for SoundIn.ar
// calls. The unused in_3/in_4 ports were being auto-connected by JACK to
// Rubix24 Analogue Surround 4.0's monitor_FL/FR outputs on every boot
// (visible in the JackDriver lines at the very top of the post window,
// re-established fresh every single boot -- this is SC's own automatic
// connection behavior, not a PipeWire session-persistence quirk, which is
// why disconnecting it manually in qpwgraph didn't hold across a reboot).
// A hardware monitor tap feeding back into SC's own input was the reported
// feedback loop. With only 2 input channels requested, in_3/in_4 simply
// won't exist for anything to auto-connect to.
s.options.numInputBusChannels  = 2;
s.options.numBuffers           = 4096;
s.options.memSize              = 256 * 1024;
s.options.maxNodes             = 2048;
s.options.maxSynthDefs         = 4096;
s.options.numWireBufs          = 128;


// ============================================================
// Diagnostic tool, left off. Confirmed the real /dirt/play message
// structure directly during the \midiMirror investigation (Section 3f) --
// showed OSC string arguments decode as Symbols, not Strings, which was
// the actual bug (~parseDirtParams was searching for the wrong type).
// Flip back to true if something upstream of SC ever needs checking again.
OSCFunc.trace(false);
// ============================================================


// ============================================================
// 2. SUPERDIRT BOOT + FULL POST-BOOT SETUP
// ============================================================

s.waitForBoot({

    if(~renaissanceBooted == true, { "Already booted, skipping.".postln; ^nil });
    ~renaissanceBooted = true;

    ~dirt = SuperDirt(2, s);
    ~orbitBuses = Array.fill(8, { Bus.audio(s, 2) });
    ~dirt.start(57120, ~orbitBuses.collect { |b| b.index });
    s.sync;

    ~dirt.loadSoundFiles("/media/projects/Audio/Samples/loops-drone/*");
    ~dirt.loadSoundFiles("/media/projects/Audio/Samples/loops-rhythmic/*");
    ~dirt.loadSoundFiles("/media/projects/Audio/Samples/loops-melodic/*");
    ~dirt.loadSoundFiles("/media/projects/Audio/Samples/loops-ambient/*");
    ~dirt.loadSoundFiles("/media/projects/Audio/Samples/prepared/*");
    // Release-promo loop bank — orbit d8. Empty folder for now; drop audio
    // files in here (any SuperDirt-readable format) and reboot SC to pick
    // them up. SuperDirt indexes files alphabetically within the folder as
    // "release-current":0, "release-current":1, etc. See renaissance.tidal
    // SECTION 13 (loop bank / d8) for the slot patterns that play from it.
    ~dirt.loadSoundFiles("/media/projects/Audio/Samples/release-current/*");


    // ── 3a. MIDI INITIALISATION ──────────────────────────────────

    MIDIClient.init;
    MIDIIn.connectAll;

    "".postln;
    "=== MIDI SOURCES ===".postln;
    MIDIClient.sources.do({ |src, i|
        ("  [" ++ i ++ "] " ++ src.name ++ " — " ++ src.device).postln;
    });
    "=== MIDI DESTINATIONS ===".postln;
    MIDIClient.destinations.do({ |dst, i|
        ("  [" ++ i ++ "] " ++ dst.name ++ " — " ++ dst.device).postln;
    });
    "".postln;

    ~lpSrcID = nil;
    MIDIClient.sources.do({ |src|
        if(~lpSrcID.isNil && (
            src.name.containsi("launchpad") ||
            src.device.containsi("launchpad")
        ), {
            ~lpSrcID = src.uid;
            ("Launchpad source UID: " ++ src.uid).postln;
        });
    });
    if(~lpSrcID.isNil, { "WARNING: Launchpad source not found.".postln });

    ~ezSrcID = nil;
    MIDIClient.sources.do({ |src|
        if(~ezSrcID.isNil && (
            src.name.containsi("EZ") ||
            src.device.containsi("EZ")
        ), {
            ~ezSrcID = src.uid;
            ("EZ-Creator source UID: " ++ src.uid).postln;
        });
    });
    if(~ezSrcID.isNil, { "WARNING: EZ-Creator source not found.".postln });

    ~mpdSrcID = nil;
    MIDIClient.sources.do({ |src|
        if(~mpdSrcID.isNil && (
            src.name.containsi("MPD") ||
            src.device.containsi("MPD")
        ), {
            ~mpdSrcID = src.uid;
            ("MPD218 source UID: " ++ src.uid).postln;
        });
    });
    if(~mpdSrcID.isNil, { "WARNING: MPD218 source not found.".postln });

    // Auto-print source UIDs at boot so they appear in the post window.
    "--- MIDI source diagnostic ---".postln;
    ("  ~ezSrcID  = " ++ ~ezSrcID  ++ if(~ezSrcID.notNil,  { " OK" }, { " WARNING: nil" })).postln;
    ("  ~mpdSrcID = " ++ ~mpdSrcID ++ if(~mpdSrcID.notNil, { " OK" }, { " WARNING: nil" })).postln;
    "--- end MIDI source diagnostic ---".postln;

    ~tidalNet = NetAddr("127.0.0.1", 57160);
    ~dirtAddr = NetAddr("127.0.0.1", 57120);


    // ── 3b. SUPERDIRT ORBIT STATE + MIX HELPERS ──────────────────

    ~orbitGain  = Array.fill(8, { 0.0 });
    ~orbitPan   = Array.fill(8, { 0.5 });
    ~orbitMute  = Array.fill(8, { false });
    ~xfadeScale = Array.fill(8, { 1.0 });
    ~liveGain   = 0.0;
    ~liveMute   = false;

    // Gates all three ~visualNet.sendMsg calls in Section 3h (OSC VISUAL
    // SENDER) below -- toggled from Tidal via a hotkey, see renaissance.tidal
    // SECTION 11B and tidal.lua for the keybindings.
    ~visualsEnabled = true;

    ~orbitReverbMix = Array.fill(8, { 0.0 });
    // Fixed orbit reverb size/damp — no longer hardware-controlled (was
    // bank 2/3 knobs). Same value for all 8 orbits; edit and reboot to
    // change the room character.
    ~orbitReverbSize = 0.7;
    ~orbitReverbDamp = 0.4;

    ~liveReverbMix    = 0.25;
    ~micReverbSize    = 0.85;
    ~micReverbDamp    = 0.5;
    ~mkorgReverbSize  = 0.7;
    ~mkorgReverbDamp  = 0.4;
    ~liveTremoloRate  = 1.0;
    ~liveTremoloDepth = 0.0;

    ~applyReverbMix = {
        if(~reverbSynths.notNil, {
            8.do({ |i| ~reverbSynths[i].set(\mix, ~orbitReverbMix[i]) });
        });
    };

    ~applyLiveCharacter = {
        if(~micSynth.notNil, {
            ~micSynth.set(\mix,          ~liveReverbMix);
            ~micSynth.set(\size,         ~micReverbSize);
            ~micSynth.set(\damp,         ~micReverbDamp);
            ~micSynth.set(\tremoloRate,  ~liveTremoloRate);
            ~micSynth.set(\tremoloDepth, ~liveTremoloDepth);
        });
        if(~mkorgSynth.notNil, {
            ~mkorgSynth.set(\mix,          ~liveReverbMix);
            ~mkorgSynth.set(\size,         ~mkorgReverbSize);
            ~mkorgSynth.set(\damp,         ~mkorgReverbDamp);
            ~mkorgSynth.set(\tremoloRate,  ~liveTremoloRate);
            ~mkorgSynth.set(\tremoloDepth, ~liveTremoloDepth);
        });
    };

    ~printReverbState = {
        "--- REVERB STATE ---".postln;
        8.do({ |i|
            var g = ~orbitGain[i].round(0.01);
            var m = ~orbitReverbMix[i].round(0.01);
            var mu = ~orbitMute[i];
            ("  d" ++ (i+1) ++ " gain:" ++ g ++ " mix:" ++ m
                ++ if(mu,{" MUTED"},{""})
                ++ if((g>0)&&(m>0)&&mu.not,{" ←"},{""}) ).postln;
        });
        ("  orbit reverb size:"++ ~orbitReverbSize.round(0.01) ++" damp:"++ ~orbitReverbDamp.round(0.01) ++" (fixed, edit+reboot to change)").postln;
        ("  V mix:"++ ~liveReverbMix.round(0.01) ++ if(~liveMute,{" MUTED"},{""})
            ++" mic sz:"++ ~micReverbSize.round(0.01) ++" dp:"++ ~micReverbDamp.round(0.01)
            ++" mkorg sz:"++ ~mkorgReverbSize.round(0.01) ++" dp:"++ ~mkorgReverbDamp.round(0.01)).postln;
        ("  trem rate:"++ ~liveTremoloRate.round(0.01) ++" depth:"++ ~liveTremoloDepth.round(0.01)).postln;
        "--- END ---".postln;
    };

    ~applyOrbitMix = { |i|
        var gain = ~orbitMute[i].if({ 0.0 }, { ~orbitGain[i] * ~xfadeScale[i] });
        if(~gainControlSynths.notNil && ~gainControlSynths[i].notNil, {
            ~gainControlSynths[i].set(\gain, gain);
        });
    };

    ~applyLiveGain = {
        var gain = ~liveMute.if({ 0.0 }, { ~liveGain });
        if(~micSynth.notNil,   { ~micSynth.set(\amp,   gain * 0.7) });
        if(~mkorgSynth.notNil, { ~mkorgSynth.set(\amp, gain * 1.0) });
    };


    // ── 3c. EZ-CREATOR FADE CONTROLLER ───────────────────────────

    // Faders CC 0–7
    MIDIdef.cc(\ezF1, { |val| ~orbitGain[0] = (val/127).squared; ~applyOrbitMix.(0) }, 0, nil, ~ezSrcID);
    MIDIdef.cc(\ezF2, { |val| ~orbitGain[1] = (val/127).squared; ~applyOrbitMix.(1) }, 1, nil, ~ezSrcID);
    MIDIdef.cc(\ezF3, { |val| ~orbitGain[2] = (val/127).squared; ~applyOrbitMix.(2) }, 2, nil, ~ezSrcID);
    MIDIdef.cc(\ezF4, { |val| ~orbitGain[3] = (val/127).squared; ~applyOrbitMix.(3) }, 3, nil, ~ezSrcID);
    MIDIdef.cc(\ezF5, { |val| ~orbitGain[4] = (val/127).squared; ~applyOrbitMix.(4) }, 4, nil, ~ezSrcID);
    MIDIdef.cc(\ezF6, { |val| ~orbitGain[5] = (val/127).squared; ~applyOrbitMix.(5) }, 5, nil, ~ezSrcID);
    MIDIdef.cc(\ezF7, { |val| ~orbitGain[6] = (val/127).squared; ~applyOrbitMix.(6) }, 6, nil, ~ezSrcID);
    MIDIdef.cc(\ezF8, { |val| ~orbitGain[7] = (val/127).squared; ~applyOrbitMix.(7) }, 7, nil, ~ezSrcID);

    // V Fader CC 8
    MIDIdef.cc(\ezVF, { |val| ~liveGain = (val/127).squared; ~applyLiveGain.() }, 8, nil, ~ezSrcID);

    // Knobs CC 9–16 — orbit reverb mix d1–d8. Single purpose, no bank check.
    MIDIdef.cc(\ezK1, { |val| ~orbitReverbMix[0] = val/127.0; if(~reverbSynths.notNil, { ~reverbSynths[0].set(\mix, ~orbitReverbMix[0]) }); }, 9,  nil, ~ezSrcID);
    MIDIdef.cc(\ezK2, { |val| ~orbitReverbMix[1] = val/127.0; if(~reverbSynths.notNil, { ~reverbSynths[1].set(\mix, ~orbitReverbMix[1]) }); }, 10, nil, ~ezSrcID);
    MIDIdef.cc(\ezK3, { |val| ~orbitReverbMix[2] = val/127.0; if(~reverbSynths.notNil, { ~reverbSynths[2].set(\mix, ~orbitReverbMix[2]) }); }, 11, nil, ~ezSrcID);
    MIDIdef.cc(\ezK4, { |val| ~orbitReverbMix[3] = val/127.0; if(~reverbSynths.notNil, { ~reverbSynths[3].set(\mix, ~orbitReverbMix[3]) }); }, 12, nil, ~ezSrcID);
    MIDIdef.cc(\ezK5, { |val| ~orbitReverbMix[4] = val/127.0; if(~reverbSynths.notNil, { ~reverbSynths[4].set(\mix, ~orbitReverbMix[4]) }); }, 13, nil, ~ezSrcID);
    MIDIdef.cc(\ezK6, { |val| ~orbitReverbMix[5] = val/127.0; if(~reverbSynths.notNil, { ~reverbSynths[5].set(\mix, ~orbitReverbMix[5]) }); }, 14, nil, ~ezSrcID);
    MIDIdef.cc(\ezK7, { |val| ~orbitReverbMix[6] = val/127.0; if(~reverbSynths.notNil, { ~reverbSynths[6].set(\mix, ~orbitReverbMix[6]) }); }, 15, nil, ~ezSrcID);
    MIDIdef.cc(\ezK8, { |val| ~orbitReverbMix[7] = val/127.0; if(~reverbSynths.notNil, { ~reverbSynths[7].set(\mix, ~orbitReverbMix[7]) }); }, 16, nil, ~ezSrcID);

    // V Knob CC 17 — live reverb mix
    MIDIdef.cc(\ezVK, { |val|
        var m = val/127.0;
        ~liveReverbMix = m;
        if(~micSynth.notNil,   { ~micSynth.set(\mix,   m) });
        if(~mkorgSynth.notNil, { ~mkorgSynth.set(\mix, m) });
    }, 17, nil, ~ezSrcID);

    // ── MUTE BUTTONS — notes 36–44, NoteOn, srcID filtered ───────
    // Hardware fires 3 MIDI messages per physical press (confirmed by
    // diagnostic, not bank-specific). ~ezMuteTime + a 300ms window per
    // button absorbs the burst: only the first message in any 300ms
    // window toggles state, the other two are ignored. 300ms is well
    // above the burst duration and below the fastest deliberate
    // double-press.
    ~ezMuteTime = Array.fill(9, { 0.0 });
    MIDIdef.noteOn(\ezMute1, { |val| if(val == 127 and: { (Main.elapsedTime - ~ezMuteTime[0]) > 0.3 }, { ~ezMuteTime[0] = Main.elapsedTime; ~orbitMute[0] = ~orbitMute[0].not; ~applyOrbitMix.(0); ("d1 mute:"++~orbitMute[0]).postln }) }, 36, nil, ~ezSrcID);
    MIDIdef.noteOn(\ezMute2, { |val| if(val == 127 and: { (Main.elapsedTime - ~ezMuteTime[1]) > 0.3 }, { ~ezMuteTime[1] = Main.elapsedTime; ~orbitMute[1] = ~orbitMute[1].not; ~applyOrbitMix.(1); ("d2 mute:"++~orbitMute[1]).postln }) }, 37, nil, ~ezSrcID);
    MIDIdef.noteOn(\ezMute3, { |val| if(val == 127 and: { (Main.elapsedTime - ~ezMuteTime[2]) > 0.3 }, { ~ezMuteTime[2] = Main.elapsedTime; ~orbitMute[2] = ~orbitMute[2].not; ~applyOrbitMix.(2); ("d3 mute:"++~orbitMute[2]).postln }) }, 38, nil, ~ezSrcID);
    MIDIdef.noteOn(\ezMute4, { |val| if(val == 127 and: { (Main.elapsedTime - ~ezMuteTime[3]) > 0.3 }, { ~ezMuteTime[3] = Main.elapsedTime; ~orbitMute[3] = ~orbitMute[3].not; ~applyOrbitMix.(3); ("d4 mute:"++~orbitMute[3]).postln }) }, 39, nil, ~ezSrcID);
    MIDIdef.noteOn(\ezMute5, { |val| if(val == 127 and: { (Main.elapsedTime - ~ezMuteTime[4]) > 0.3 }, { ~ezMuteTime[4] = Main.elapsedTime; ~orbitMute[4] = ~orbitMute[4].not; ~applyOrbitMix.(4); ("d5 mute:"++~orbitMute[4]).postln }) }, 40, nil, ~ezSrcID);
    MIDIdef.noteOn(\ezMute6, { |val| if(val == 127 and: { (Main.elapsedTime - ~ezMuteTime[5]) > 0.3 }, { ~ezMuteTime[5] = Main.elapsedTime; ~orbitMute[5] = ~orbitMute[5].not; ~applyOrbitMix.(5); ("d6 mute:"++~orbitMute[5]).postln }) }, 41, nil, ~ezSrcID);
    MIDIdef.noteOn(\ezMute7, { |val| if(val == 127 and: { (Main.elapsedTime - ~ezMuteTime[6]) > 0.3 }, { ~ezMuteTime[6] = Main.elapsedTime; ~orbitMute[6] = ~orbitMute[6].not; ~applyOrbitMix.(6); ("d7 mute:"++~orbitMute[6]).postln }) }, 42, nil, ~ezSrcID);
    MIDIdef.noteOn(\ezMute8, { |val| if(val == 127 and: { (Main.elapsedTime - ~ezMuteTime[7]) > 0.3 }, { ~ezMuteTime[7] = Main.elapsedTime; ~orbitMute[7] = ~orbitMute[7].not; ~applyOrbitMix.(7); ("d8 mute:"++~orbitMute[7]).postln }) }, 43, nil, ~ezSrcID);
    MIDIdef.noteOn(\ezVMute,  { |val| if(val == 127 and: { (Main.elapsedTime - ~ezMuteTime[8]) > 0.3 }, { ~ezMuteTime[8] = Main.elapsedTime; ~liveMute = ~liveMute.not; ~applyLiveGain.(); ("V mute:"++~liveMute).postln }) }, 44, nil, ~ezSrcID);

    // Crossfader SysEx — hardware 127=full left=A-side full
    MIDIdef.sysex(\ezCrossfade, { |msg, src|
        var raw, val, aScale, bScale;
        raw = -1;
        if((msg.size >= 6) && (msg[2].asInteger == 4) && (msg[3].asInteger == 1), {
            raw = msg[5].asInteger;
        });
        if((raw < 0) && (msg.size >= 7) && (msg[3].asInteger == 4) && (msg[4].asInteger == 1), {
            raw = msg[6].asInteger;
        });
        if(raw >= 0, {
            val    = (127 - raw).clip(0, 127);
            aScale = if(val <= 64, { 1.0 }, { (127 - val) / 63.0 });
            bScale = if(val >= 64, { 1.0 }, { val / 64.0 });
            4.do({ |i| ~xfadeScale[i] = aScale; ~applyOrbitMix.(i) });
            4.do({ |i| ~xfadeScale[i+4] = bScale; ~applyOrbitMix.(i+4) });
        });
    });

    // Bank SysEx: deliberately unhandled. The physical bank button still
    // sends F0 42 40 00 01 04 00 5F 4F XX F7 when pressed, but nothing
    // listens for it any more — leave the hardware on bank 1 (or 4; both
    // send mutes as NoteOn) and it never matters.

    "EZ-Creator: MIDI responders registered (single-bank).".postln;


    // ── 3d. LAUNCHPAD MINI MK3 ───────────────────────────────────

    ~lpActiveSlot  = Array.fill(8, { 0 });
    ~lpSysExHeader = Int8Array[0xF0, 0x00, 0x20, 0x29, 0x02, 0x0D];

    ~lpOut = nil;
    // Programmer-mode LED/light control needs the "MI" interface, not "DA"
    // (DA is the DAW-mode interface -- Novation's Programmer's Reference is
    // explicit that Programmer-mode lighting goes over MI). Prefer a match
    // naming both; fall back to any "launchpad" destination if that specific
    // one isn't found, so this degrades gracefully rather than silently
    // going quiet if the port name ever changes.
    MIDIClient.destinations.do({ |dst, i|
        if(~lpOut.isNil && (
            dst.name.containsi("launchpad") ||
            dst.device.containsi("launchpad")
        ) && dst.name.containsi("mk3 mi"), {
            var mOut = MIDIOut(i);
            mOut.connect;
            ~lpOut = mOut;
            ("Launchpad out: [" ++ i ++ "] " ++ dst.name).postln;
        });
    });
    if(~lpOut.isNil, {
        MIDIClient.destinations.do({ |dst, i|
            if(~lpOut.isNil && (
                dst.name.containsi("launchpad") ||
                dst.device.containsi("launchpad")
            ), {
                var mOut = MIDIOut(i);
                mOut.connect;
                ~lpOut = mOut;
                ("Launchpad out: [" ++ i ++ "] " ++ dst.name ++ " (MI-specific match not found -- using this, check LEDs)").postln;
            });
        });
    });
    if(~lpOut.isNil, { "WARNING: Launchpad MIDI out not found.".postln });

    ~lpSetMode = { |mode|
        if(~lpOut.notNil, {
            var sysex = ~lpSysExHeader ++ Int8Array[0x00, mode, 0xF7];
            ~lpOut.sysex(sysex);
        });
    };
    SystemClock.sched(2.0, { ~lpSetMode.(0x7F); nil });

    ~lpSetLED = { |noteNum, colourIdx|
        if(~lpOut.notNil, { ~lpOut.noteOn(0, noteNum, colourIdx) });
    };

    ~lpClearAll = {
        8.do({ |row|
            8.do({ |col|
                ~lpSetLED.(((8 - row) * 10) + (col + 1), 0);
            });
        });
    };
    ~lpClearAll.();

    ~lpRefreshGrid = {
        8.do({ |orbit|
            8.do({ |slot|
                var row     = 8 - orbit;
                var noteNum = (row * 10) + (slot + 1);
                var colour  = if(~lpActiveSlot[orbit] == (slot+1), { 9 }, { 1 });
                ~lpSetLED.(noteNum, colour);
            });
        });
    };

    // Per the SC 3.11 hard rule at the top of this file, this also receives
    // NoteOff as NoteOn vel:0, hence the vel > 63 guard below -- necessary,
    // but confirmed NOT sufficient on its own (single presses were still
    // toggling straight back off in testing). The actual cause is the same
    // one confirmed on the CC buttons: this handler accepts both ~lpSrcID
    // and ~lpSrcID + 1 (DA and MI), and the device delivers the same press
    // via both ports, so a single tap fires this handler twice, both times
    // with vel > 63 -- first copy turns the slot on, second copy a few ms
    // later reads it as already-active and immediately turns it back off.
    // Debounced by time per note number below, same technique as the page
    // buttons. NOTE: the row/orbit formula below (orbit = 9 - row) is
    // correct as written and does NOT need changing -- it matches
    // BootTidal.hs's own "row 8 at top = d1, row 1 at bottom = d8" mapping,
    // since here "orbit" is the 1-indexed d-number, not the 0-indexed
    // SuperDirt orbit (BootTidal.hs subtracts 1 itself on receipt).
    ~lpNoteLastTime = Dictionary.new;

    MIDIdef.noteOn(\launchpadOn, { |vel, noteNum, chan, src|
        var row, col, orbit, slot, prevSlotNote, now, last;
        // Source test is part of this condition, NOT an early `^nil`: see the
        // note in the header rules -- an early return here silently stopped
        // every handler registered after this one from seeing any event from
        // any other device.
        if(((src == ~lpSrcID) || (src == (~lpSrcID + 1))) && (vel > 63), {
            now  = SystemClock.seconds;
            last = ~lpNoteLastTime[noteNum];
            if(last.isNil, { last = -1 });
            if((last < 0) || ((now - last) > 0.05), {
                ~lpNoteLastTime[noteNum] = now;
                ("RAW noteNum: " ++ noteNum ++ " (vel " ++ vel ++ ")").postln;
                row  = noteNum.div(10);
                col  = noteNum % 10;
                if((row >= 1) && (row <= 8) && (col >= 1) && (col <= 8), {
                    orbit = 9 - row;
                    slot  = col;
                    if(~lpActiveSlot[orbit - 1] == slot, {
                        ("SENT /launchpad/off " ++ orbit ++ " to 127.0.0.1:57160").postln;
                        ~tidalNet.sendMsg("/launchpad/off", orbit);
                        ~lpSetLED.(noteNum, 1);
                        ~lpActiveSlot[orbit - 1] = 0;
                        ("LP off: orbit " ++ orbit).postln;
                    }, {
                        if(~lpActiveSlot[orbit - 1] > 0, {
                            prevSlotNote = ((9 - orbit) * 10) + ~lpActiveSlot[orbit - 1];
                            ~lpSetLED.(prevSlotNote, 1);
                        });
                        ("SENT /launchpad/on " ++ orbit ++ " " ++ slot ++ " to 127.0.0.1:57160").postln;
                        ~tidalNet.sendMsg("/launchpad/on", orbit, slot);
                        ~lpSetLED.(noteNum, 9);
                        ~lpActiveSlot[orbit - 1] = slot;
                        ("LP on: orbit " ++ orbit ++ " slot " ++ slot).postln;
                    });
                });
            });
        });
    }, nil, nil);

    MIDIdef.noteOff(\launchpadOff, { }, nil, nil);

    // ── 3d (cont). LAUNCHPAD TOP-ROW BUTTONS: PAGE SWITCHING ─────
    // Confirmed via hardware sweep: Page Left = CC 93, Page Right = CC 94
    // (Page Up=91, Page Down=92, Session=95, Drums=96, Keys=97, User=98
    // also confirmed, unused for now -- change the two lines below if
    // you'd rather use a different pair).
    //
    // These buttons report val 0 on BOTH press and release (unlike the
    // right-column Scene Launch buttons, which report 127 then 0), and
    // each physical press arrives twice -- so gating on value, like the
    // grid handler does, doesn't work here: every real press would need
    // to fire on val 0, but so does its own paired duplicate a moment
    // later. Debouncing by time instead: a repeat of the same CC within
    // 50ms is treated as the duplicate and ignored, which collapses it
    // to exactly one page-change per physical press regardless of what
    // value it carries.
    ~lpPagePrevCC   = 93;  // Page Left
    ~lpPageNextCC   = 94;  // Page Right
    ~lpPageLastTime = Dictionary.new;

    MIDIdef.cc(\launchpadPage, { |val, num, chan, src|
        var isPrev, isNext, now, last;
        isPrev = (num == ~lpPagePrevCC);
        isNext = (num == ~lpPageNextCC);
        // Source test is part of this condition, NOT an early `^nil` (see above).
        if((isPrev || isNext) && ((src == ~lpSrcID) || (src == (~lpSrcID + 1))), {
            now  = SystemClock.seconds;
            last = ~lpPageLastTime[num];
            if(last.isNil, { last = -1 });
            if((last < 0) || ((now - last) > 0.05), {
                ~lpPageLastTime[num] = now;
                if(isPrev, { ~tidalNet.sendMsg("/launchpad/page", -1) });
                if(isNext, { ~tidalNet.sendMsg("/launchpad/page", 1) });
            });
        });
    }, nil, nil);

    "Launchpad: MIDI responders registered.".postln;


    // ── 3e. AKAI MPD218 ONE-SHOT SAMPLE PADS ─────────────────────
    // All 48 pads (3 banks of 16) play one-shot samples with no SuperDirt
    // orbit involved at all: MIDI note on -> PlayBuf -> Out.ar(0, ...),
    // straight to the same hardware bus this server's own JACK connections
    // already carry to the Rubix24 outputs. No orbit, no /dirt/play
    // message, no soundLibrary -- about as few moving parts as this can
    // have, and nothing here depends on any of SuperDirt's own machinery.
    //
    // Pad = MIDI note 0-47 on channel 9 (unchanged from the previous synth
    // version): bank A = notes 0-15, B = 16-31, C = 32-47. One folder per
    // bank; files load alphabetically, so file 1 = pad 1, file 2 = pad 2,
    // etc. -- name files 01_, 02_, ... to control pad order.
    //
    // Matched on channel 9 alone, with no source-ID dependency, so it also
    // keeps working if the MPD218 re-enumerates under a different ALSA
    // client number mid-session. Nothing else on this rig plays notes 0-47
    // on channel 9 (the EZ-Creator's mute buttons arrive on channel 0).
    //
    // The MIDI handler is registered FIRST, below, before any sample is
    // loaded, so a problem loading samples can never stop it from existing.
    // ~mpdBufs starts nil and the handler checks for that, so a pad pressed
    // before loading finishes reports "still loading" instead of erroring.
    //
    // WHY THE LAUNCHPAD HANDLERS ABOVE WERE CHANGED: they used to start
    // with `if(src != ..., { ^nil })`. Registered for all notes/CCs from all
    // devices, that early return aborted the whole dispatch chain for every
    // non-Launchpad event, silently, so no handler registered after them
    // (these pads included) ever saw a single event from any other device.

    ~mpdBankPaths = [
        "/media/projects/Audio/Samples/mpd-a",
        "/media/projects/Audio/Samples/mpd-b",
        "/media/projects/Audio/Samples/mpd-c"
    ];
    ~mpdBufs = nil;
    ~mpdLastHit = Array.fill(48, 0);

    SynthDef(\mpdOneShotMono, { |buf, amp = 1, out = 0|
        var sig = PlayBuf.ar(1, buf, BufRateScale.kr(buf), doneAction: 2);
        Out.ar(out, (sig * amp) ! 2);
    }).add;
    SynthDef(\mpdOneShotStereo, { |buf, amp = 1, out = 0|
        var sig = PlayBuf.ar(2, buf, BufRateScale.kr(buf), doneAction: 2);
        Out.ar(out, sig * amp);
    }).add;

    MIDIdef.noteOn(\mpd_pads, { |vel, note, chan|
        var bank, n, letter, pair, now;
        now = SystemClock.seconds;
        if((chan.asInteger == 9) && (vel > 0) && (note >= 0) && (note <= 47), {
            // Ignore an identical hit repeated within 20ms. If the MPD218 is
            // patched to several SuperCollider input ports at once (qpwgraph),
            // ALSA delivers every press once per connection, which would
            // otherwise layer the same sample several times at once.
            if((now - ~mpdLastHit[note]) > 0.02, {
                ~mpdLastHit[note] = now;
                bank = note.div(16);
                n    = note % 16;
                letter = ["A", "B", "C"][bank];
                ("MPD218 pad " ++ letter ++ (n + 1) ++ "  vel=" ++ vel).postln;
                if(~mpdBufs.isNil, {
                    "  samples still loading -- try again in a moment".postln;
                }, {
                    if(n < ~mpdBufs[bank].size, {
                        pair = ~mpdBufs[bank][n];
                        Synth(if(pair.value >= 2, \mpdOneShotStereo, \mpdOneShotMono),
                            [\buf, pair.key.bufnum, \amp, (vel / 127.0), \out, 0]);
                    }, {
                        ("  nothing loaded on that pad (bank " ++ letter ++ " has "
                            ++ ~mpdBufs[bank].size ++ " files)").postln;
                    });
                });
            });
        });
    }, nil, nil, nil);
    "MPD218: MIDI responder registered.".postln;

    // NOW load every file in each bank folder, after the handler above is
    // already safely in place. Each entry is an Association, buffer -> that
    // file's channel count: read via SoundFile on the language side, so the
    // channel count is known immediately, with no async wait needed to pick
    // the mono or stereo SynthDef above.
    //
    // Each file loads inside its own try/catch: if SoundFile can't open one
    // particular file (unreadable, unexpected format, etc.), a thrown error
    // would otherwise abort the rest of this boot script silently. One bad
    // file now just prints a warning and is skipped; every other file still
    // loads, and -- since it's already registered above -- so does the
    // MIDI handler regardless.
    ~mpdBufs = ~mpdBankPaths.collect({ |path, bankIdx|
        var files = pathMatch(path.standardizePath +/+ "*").select({ |f|
            var ext = PathName(f).extension.toLower;
            ["wav", "aif", "aiff", "aifc"].any({ |e| e == ext })
        });
        var loaded = List.new;
        files.do({ |f|
            try {
                var sf = SoundFile.openRead(f);
                var chans = sf.numChannels;
                sf.close;
                loaded.add(Buffer.read(s, f) -> chans);
            } { |err|
                ("MPD218: couldn't load '" ++ f ++ "' -- skipping it ("
                    ++ err.errorString ++ ")").postln;
            };
        });
        loaded;
    });

    // Boot report: confirms what actually loaded, so a missing/empty folder
    // shows up here loudly instead of silently.
    ["A", "B", "C"].do({ |letter, i|
        var size = ~mpdBufs[i].size;
        ("MPD218 bank " ++ letter ++ ": " ++ size ++ " files loaded from "
            ++ ~mpdBankPaths[i]).postln;
        if(size == 0, {
            "  WARNING: folder missing or empty -- this bank's pads will be silent".postln;
        });
    });

    // All MPD218 knobs spare
    MIDIdef.cc(\mpd_k_a1, { |val| ~mpdA1 = val/127.0 },  0, 9, ~mpdSrcID);
    MIDIdef.cc(\mpd_k_a2, { |val| ~mpdA2 = val/127.0 },  1, 9, ~mpdSrcID);
    MIDIdef.cc(\mpd_k_a3, { |val| ~mpdA3 = val/127.0 },  2, 9, ~mpdSrcID);
    MIDIdef.cc(\mpd_k_a4, { |val| ~mpdA4 = val/127.0 },  3, 9, ~mpdSrcID);
    MIDIdef.cc(\mpd_k_a5, { |val| ~mpdA5 = val/127.0 },  4, 9, ~mpdSrcID);
    MIDIdef.cc(\mpd_k_a6, { |val| ~mpdA6 = val/127.0 },  5, 9, ~mpdSrcID);
    MIDIdef.cc(\mpd_k_b1, { |val| ~mpdB1 = val/127.0 },  6, 9, ~mpdSrcID);
    MIDIdef.cc(\mpd_k_b2, { |val| ~mpdB2 = val/127.0 },  7, 9, ~mpdSrcID);
    MIDIdef.cc(\mpd_k_b3, { |val| ~mpdB3 = val/127.0 },  8, 9, ~mpdSrcID);
    MIDIdef.cc(\mpd_k_b4, { |val| ~mpdB4 = val/127.0 },  9, 9, ~mpdSrcID);
    MIDIdef.cc(\mpd_k_b5, { |val| ~mpdB5 = val/127.0 }, 10, 9, ~mpdSrcID);
    MIDIdef.cc(\mpd_k_b6, { |val| ~mpdB6 = val/127.0 }, 11, 9, ~mpdSrcID);
    MIDIdef.cc(\mpd_k_c1, { |val| ~mpdC1 = val/127.0 }, 12, 9, ~mpdSrcID);
    MIDIdef.cc(\mpd_k_c2, { |val| ~mpdC2 = val/127.0 }, 13, 9, ~mpdSrcID);
    MIDIdef.cc(\mpd_k_c3, { |val| ~mpdC3 = val/127.0 }, 14, 9, ~mpdSrcID);
    MIDIdef.cc(\mpd_k_c4, { |val| ~mpdC4 = val/127.0 }, 15, 9, ~mpdSrcID);
    MIDIdef.cc(\mpd_k_c5, { |val| ~mpdC5 = val/127.0 }, 16, 9, ~mpdSrcID);
    MIDIdef.cc(\mpd_k_c6, { |val| ~mpdC6 = val/127.0 }, 17, 9, ~mpdSrcID);

    "MPD218: MIDI responders registered.".postln;


    // Shared by \midiMirror (3f) and \visualSender/\visualsToggle (3h).
    // Finds each key by name (msg.indexOf) rather than assuming a fixed
    // starting offset for the key/value pairs. Deliberately not the
    // faster fixed-offset scan those OSCdefs used before -- that scan
    // was built and tested against ~earCandy's own hand-built messages
    // (Section 3e), which insert an extra placeholder value right after
    // the address before the real key/value pairs begin. A genuine
    // Tidal-generated /dirt/play message very likely doesn't have that
    // placeholder -- its own event metadata (cps/delta/cycle) probably
    // starts immediately as key/value pairs -- which would shift every
    // single key by one position and silently misalign the whole parse
    // (no error, just params[\s] never matching anything, which is
    // exactly what was happening: no crash in the log, just the debug
    // line that should confirm a match never printing). indexOf finds
    // each named key wherever it actually sits, so this works the same
    // regardless of which format sent it. (~earCandy has since been replaced
    // by direct Buffer/PlayBuf playback in Section 3e, which sends no
    // /dirt/play message at all -- nothing for this parser to see there.)
    ~parseDirtParams = { |msg|
        var dict = Dictionary.new;
        var keys = [\s, \note, \n, \amp, \gain, \pan, \orbit, \sustain, \midichan, \scaleName, \cps];
        keys.do({ |k|
            // SuperCollider decodes OSC string-typed arguments as Symbols,
            // not Strings -- confirmed via \debug_midiMirror2: the OSCdef
            // fired correctly on every message, but indexOf(k.asString)
            // (searching for a String) never matched anything in an array
            // that actually holds Symbols, so every key came back nil,
            // for every message, regardless of content. Try the Symbol
            // form first (matches the real data), String as a fallback
            // in case a future SC/Tidal version ever sends it differently.
            var idx = msg.indexOf(k);
            if(idx.isNil, { idx = msg.indexOf(k.asString); });
            if(idx.notNil, { dict.put(k, msg[idx + 1]); });
        });
        dict;
    };


    // ── 3f. MIDI OUT (RUBIX24 -> cable -> MIDIHUB -> MICROKORG) ───
    // Was targeting "Midihub MH-1981PVP A" directly (its own USB-MIDI
    // ports) -- confirmed wrong. The actual signal chain: SC sends MIDI to
    // the Rubix24's MIDI-out (an audio interface with its own physical
    // DIN MIDI jack), which is cabled into one of the Midihub's inputs;
    // the Midihub runs its own microtonal pitch-bend pipe on what arrives
    // there (retuning against a loaded .scl file) before forwarding to the
    // Microkorg. Targeting the Midihub's USB ports directly bypasses the
    // Rubix24 entirely and never reaches this pipe -- consistent with the
    // original pre-existing code (which did exactly this) never having
    // actually worked, as far as anything in this whole thread has shown.
    //
    // MIDIOut(i) with i from MIDIClient.destinations.do was ALSO wrong on
    // Linux specifically, separately from the above -- confirmed against
    // SC's own documentation. On Linux, the port argument to MIDIOut.new
    // means "which of SuperCollider's own virtual output ports" (out0,
    // out1, ... as seen in the MIDI Sources listing above), and has NO
    // relation to MIDIClient.destinations at all -- unlike macOS/Windows,
    // where it does. MIDIOut.newByName(device, port) is SC's own
    // documented fix -- looks up the endpoint by name and handles the
    // Linux port/uid distinction internally, rather than assuming
    // index == destination.
    ~midiOutPort = MIDIOut.newByName("Rubix24", "Rubix24 MIDI 1", false);
    if(~midiOutPort.notNil, {
        ~midiOutPort.connect;
        ~midiOutPort.latency = 0.0;
        "Rubix24 MIDI out: Rubix24 MIDI 1 (newByName)".postln;
        ("  actual port/uid -> port:" ++ ~midiOutPort.tryPerform(\port) ++ " uid:" ++ ~midiOutPort.tryPerform(\uid)).postln;
    }, {
        "Warning: Rubix24 MIDI out not found by name. Falling back to first available destination.".postln;
        if(MIDIClient.destinations.size > 0, {
            var d = MIDIClient.destinations[0];
            ~midiOutPort = MIDIOut.newByName(d.device, d.name, false);
            if(~midiOutPort.notNil, {
                ~midiOutPort.connect;
                ~midiOutPort.latency = 0.0;
                ("  fallback actual port/uid -> port:" ++ ~midiOutPort.tryPerform(\port) ++ " uid:" ++ ~midiOutPort.tryPerform(\uid)).postln;
            });
        });
    });
    if(~midiOutPort.notNil, {
        ~dirt.soundLibrary.addMIDI(\midi, ~midiOutPort);
        "SuperDirt MIDI output ready.".postln;
    });

    OSCdef(\midiMirror, { |msg, time, addr|
        var params, midiNote, midiVel, midiChan, dur, sName;
        params = ~parseDirtParams.(msg);
        sName  = (params[\s] ?? { "" }).asString;
        if((sName == "microkorg") || (sName == "external") || (sName == "midihub"), {
            if(~midiOutPort.notNil, {
                midiNote = (params[\note] ?? { 0 }).asInteger + 60;
                midiVel  = ((params[\amp] ?? { 0.7 }) * 127).clip(1,127).asInteger;
                midiChan = (params[\midichan] ?? { 0 }).asInteger;
                dur      = (params[\sustain] ?? { 0.25 }).asFloat;
                midiNote = midiNote.clip(0,127);
                ~midiOutPort.noteOn(midiChan, midiNote, midiVel);
                ("MIDI out -> ch:" ++ midiChan ++ " note:" ++ midiNote ++ " vel:" ++ midiVel ++ " dur:" ++ dur.round(0.01)).postln;
                // If this ever shows the same note repeating across a
                // multi-note pattern again: that's not a bug here, it's
                // almost certainly # written with s "microkorg" BEFORE the
                // note pattern instead of after. See renaissance.tidal
                // SECTION 11B for the full explanation -- # takes its
                // event structure from whatever's on its left, and
                // s "microkorg" is a single unsubdivided value, so putting
                // it first silently collapses everything after it to one
                // sample per cycle. Confirmed via a raw-message dump added
                // temporarily inside this OSCdef: the message Tidal sent
                // genuinely contained the same note value every time --
                // this code was correctly reporting exactly what arrived.
                SystemClock.sched(dur, { ~midiOutPort.noteOff(midiChan, midiNote, 0); nil });
            }, {
                "WARNING: midiMirror fired but ~midiOutPort is nil (Midihub never connected).".postln;
            });
        });
    }, '/dirt/play');


    // ── 3g. MIC + MICROKORG ──────────────────────────────────────

    SynthDef(\micMonitor, {
        arg amp = 0.0, mix = 0.25, size = 0.85, damp = 0.5,
            hpFreq = 100, tremoloRate = 1.0, tremoloDepth = 0.0, out = 0;
        var mic, hp, revL, revR, outL, outR, trem;
        mic  = SoundIn.ar(1);
        hp   = HPF.ar(mic, hpFreq);
        # revL, revR = FreeVerb2.ar(hp, hp, 1.0, size, damp);
        outL = (hp * (1.0 - mix)) + (revL * mix);
        outR = (hp * (1.0 - mix)) + (revR * mix);
        trem = SinOsc.kr(tremoloRate, 0, tremoloDepth, 1.0 - tremoloDepth);
        Out.ar(out, [outL, outR] * amp * trem);
    }).add;

    SynthDef(\mkorgPassthrough, {
        arg amp = 0.0, mix = 0.25, size = 0.7, damp = 0.4,
            tremoloRate = 1.0, tremoloDepth = 0.0, out = 0;
        var mono, revL, revR, outL, outR, trem;
        mono = SoundIn.ar(0);
        # revL, revR = FreeVerb2.ar(mono, mono, 1.0, size, damp);
        outL = (mono * (1.0 - mix)) + (revL * mix);
        outR = (mono * (1.0 - mix)) + (revR * mix);
        trem = SinOsc.kr(tremoloRate, 0, tremoloDepth, 1.0 - tremoloDepth);
        Out.ar(out, [outL, outR] * amp * trem);
    }).add;

    SynthDef(\micPitchDetect, {
        arg threshold = 0.05;
        var mic, freq, hasFreq;
        mic = SoundIn.ar(1);
        # freq, hasFreq = Pitch.kr(mic, initFreq: 220, minFreq: 60,
                                    maxFreq: 1200, ampThreshold: threshold, median: 7);
        SendReply.kr(Impulse.kr(1), '/mic/pitch', [freq, hasFreq]);
    }).add;

    SynthDef(\orbitReverb, { |inBus = 0, outBus = 0, mix = 0.0, size = 0.7, damp = 0.4|
        var sig, revL, revR, outL, outR;
        sig = In.ar(inBus, 2);
        # revL, revR = FreeVerb2.ar(sig[0], sig[1], 1.0, size, damp);
        outL = (sig[0] * (1.0 - mix)) + (revL * mix);
        outR = (sig[1] * (1.0 - mix)) + (revR * mix);
        Out.ar(outBus, [outL, outR]);
    }).add;

    SynthDef(\orbitGainControl, { |inBus = 0, outBus = 0, gain = 1.0|
        Out.ar(outBus, In.ar(inBus, 2) * gain);
    }).add;

    s.sync;

    ~micSynth = Synth.tail(s, \micMonitor, [
        \amp, 0.0, \mix, 0.25, \size, 0.85, \damp, 0.5,
        \hpFreq, 100, \tremoloRate, 1.0, \tremoloDepth, 0.0, \out, 0
    ]);
    ~mkorgSynth = Synth.tail(s, \mkorgPassthrough, [
        \amp, 0.0, \mix, 0.25, \size, 0.7, \damp, 0.4,
        \tremoloRate, 1.0, \tremoloDepth, 0.0, \out, 0
    ]);
    ~pitchSynth = Synth.tail(s, \micPitchDetect, [\threshold, 0.05]);

    "Mic + Microkorg synths running (amp=0.0 — pull V fader to hear).".postln;

    ~gainGroup       = Group.after(s.defaultGroup);
    ~postReverbBuses = Array.fill(8, { Bus.audio(s, 2) });

    ~reverbSynths = ~orbitBuses.collect { |bus, idx|
        Synth.head(~gainGroup, \orbitReverb,
            [\inBus, bus.index, \outBus, ~postReverbBuses[idx].index,
             \mix, 0.0, \size, ~orbitReverbSize, \damp, ~orbitReverbDamp]);
    };

    ~gainControlSynths = ~postReverbBuses.collect { |bus, idx|
        Synth.tail(~gainGroup, \orbitGainControl,
            [\inBus, bus.index, \outBus, 0, \gain, 0.0]);
    };
    "Orbit gain control synths running.".postln;

    OSCdef(\micPitchReceiver, { |msg|
        var freq, hasFreq, midiNote, noteName, octave;
        freq    = msg[3].asFloat;
        hasFreq = msg[4].asFloat;
        if((hasFreq > 0.5) && ~visualsEnabled, {
            midiNote = (12 * log2(freq / 440.0) + 69).round.asInteger.clip(0,127);
            noteName = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"].at(midiNote % 12);
            octave   = (midiNote.div(12)) - 1;
            ~visualNet.sendMsg("/mic/pitch", freq, midiNote, noteName ++ octave);
        });
    }, '/mic/pitch');


    // ── 3h. OSC VISUAL SENDER ────────────────────────────────────

    ~visualPort = 57200;
    ~visualNet  = NetAddr("127.0.0.1", ~visualPort);

    OSCdef(\visualSender, { |msg, time, addr|
        var params, instrument, note, gain, pan, orbit, scaleName, cps;
        params = ~parseDirtParams.(msg);
        instrument = (params[\s]         ?? { "unknown" }).asString;
        note       = (params[\note]      ?? { 0 }).asInteger;
        gain       = (params[\gain]      ?? { 0.5 }).asFloat;
        pan        = (params[\pan]       ?? { 0.5 }).asFloat;
        orbit      = (params[\orbit]     ?? { 0 }).asInteger;
        scaleName  = (params[\scaleName] ?? { "" }).asString;
        cps        = (params[\cps]       ?? { 0.0 }).asFloat;
        if((gain > 0.01) && ~visualsEnabled, {
            ~visualNet.sendMsg("/tidal/note", instrument, note, 0.0, gain, pan, orbit, scaleName, cps);
        });
    }, '/dirt/play');

    OSCdef(\beatSender, { |msg, time, addr|
        if((msg[1] < 0.05) && ~visualsEnabled, {
            ~visualNet.sendMsg("/tidal/beat", msg[4].asInteger, msg[2].asFloat);
        });
    }, '/clock', NetAddr("127.0.0.1", nil));

    // Toggle for the three sends above -- mirrors /dirt/play the same way
    // \midiMirror does for the Microkorg, watching for two dedicated sound
    // names rather than a real instrument. Triggered from Tidal with
    // `once visualsOff` / `once visualsOn` (see renaissance.tidal SECTION
    // 11B) -- bound to a hotkey in tidal.lua. SuperDirt will separately
    // warn "instrument not found" for both names, same as microkorg --
    // expected, harmless, same reason.
    OSCdef(\visualsToggle, { |msg, time, addr|
        var params, sName;
        params = ~parseDirtParams.(msg);
        sName  = (params[\s] ?? { "" }).asString;
        if(sName == "visualsoff", {
            ~visualsEnabled = false;
            "Visuals OSC: OFF".postln;
        });
        if(sName == "visualson", {
            ~visualsEnabled = true;
            "Visuals OSC: ON".postln;
        });
    }, '/dirt/play');


    // ── 3i. BOOT VERIFICATION ────────────────────────────────────

    s.sync;

    "".postln;
    "================================================================".postln;
    " Renaissance Counterpoint — SuperCollider / SuperDirt READY".postln;
    "================================================================".postln;
    ("  " ++ s.name ++ " @ " ++ s.sampleRate ++ " Hz  blockSize: " ++ s.options.blockSize).postln;
    "  SuperDirt: port 57120, 8 orbits d1–d8".postln;
    "".postln;
    "  EZ-Creator: single bank only (see header for why).".postln;
    "    CC 0–7  faders d1–d8  |  CC 8 V fader (amp starts at 0)".postln;
    "    CC 9–16 knobs → orbit reverb mix d1–d8  |  CC 17 V knob (reverb mix)".postln;
    "    Notes 36–44 + V mute (debounced)".postln;
    "    Crossfader: LEFT=d1–d4  CENTRE=both  RIGHT=d5–d8".postln;
    "  V CHANNEL: physical inputs only. Tidal→orbit chains not V channel.".postln;
    "  MPD218: 48 sample pads (3 banks x 16), direct PlayBuf, no orbit  all knobs spare".postln;
    "  Helpers: ~printReverbState.()  ~applyReverbMix.()".postln;
    "           ~applyLiveCharacter.()  ~verifyTuning.()  ~lpRefreshGrid.()".postln;
    "================================================================".postln;
    "".postln;

    ~verifyTuning = {
        "--- TUNING VERIFICATION ---".postln;
        if(t.notNil, {
            [
                ["meanquar",        60, 261.626, "C4 meantone"],
                ["A_JI_Aeolian",    60, 440.0,   "A4 JI Aeolian"],
                ["A_JI_Aeolian",    61, 495.0,   "B4 JI Aeolian"],
                ["B_JI_Dorian",     60, 493.88,  "B4 JI Dorian"],
                ["C_JI_Ionian",     60, 261.626, "C4 JI Ionian"],
                ["D_JI_Dorian",     60, 293.66,  "D4 JI Dorian"],
                ["G_JI_Mixolydian", 60, 392.0,   "G4 JI Mixolydian"],
            ].do({ |check|
                var tbl = t[check[0]];
                if(tbl.notNil, {
                    var actual = tbl[check[1]];
                    var status = if((actual - check[2]).abs < 1.0, {"OK  "}, {"FAIL"});
                    (status ++ " " ++ check[0] ++ " [" ++ check[1] ++ "]: "
                        ++ actual.round(0.001) ++ " Hz  " ++ check[3]).postln;
                }, { ("MISS " ++ check[0]).postln });
            });
        }, { "ERROR: t is nil.".postln });
        "--- END ---".postln;
    };

}); // end s.waitForBoot


// ============================================================
// DEBUG RESPONDERS — evaluate in SC IDE individually
// ============================================================
// Generic catch-alls, useful for any future hardware troubleshooting.
// Not bank-specific — the single-bank setup above doesn't need routine
// diagnostics, these are just kept handy.
//
// -- RAW CC CATCH-ALL --
//
// MIDIdef.cc(\debug_cc, { |val, cc, chan, src|
//     ("CC " ++ cc ++ " val " ++ val ++ " ch " ++ chan
//         ++ " src " ++ src
//         ++ if(src == ~ezSrcID, { " [EZ]" }, { " [OTHER src - NOT ~ezSrcID]" })
//     ).postln;
// }, nil, nil);
// MIDIdef(\debug_cc).free;
//
// -- RAW NOTE CATCH-ALL --
// MIDIdef.noteOn(\debug_note, { |vel, note, chan, src|
//     ("Note " ++ note ++ " vel " ++ vel ++ " ch " ++ chan
//         ++ " src " ++ src
//         ++ if(src == ~ezSrcID, { " [EZ]" }, { " [OTHER src]" })
//     ).postln;
// }, nil, nil);
// MIDIdef(\debug_note).free;
//
// -- RAW /dirt/play MESSAGE DUMP --
// A live, active version of this (filtered to microkorg-tagged messages
// only) is already running in Section 3f, right after ~parseDirtParams --
// no need to add it here too. This spot kept for a future equivalent if
// a different message/address ever needs the same treatment.
//
// MIDIdef.sysex(\debug_sysex, { |msg, src|
//     ("SysEx src:" ++ src ++ " [" ++ msg.size ++ "]: "
//         ++ msg.asArray.collect({ |b| b.asInteger.asHexString(2) }).join(" ")
//     ).postln;
// });
// MIDIdef(\debug_sysex).free;
//
// -- TIMED FULL DIAGNOSTIC (CC + NoteOn + NoteOff, 60 seconds) --
// Add this block inside s.waitForBoot({ ... }) just before ~verifyTuning.
// Shows all MIDI from EZ, tagged by source. Removes itself after 60s.
//
// MIDIdef.cc(\diagCC, { |val, cc, chan, src|
//     if(src == ~ezSrcID, {
//         ("DIAG CC:" ++ cc ++ " val:" ++ val ++ " ch:" ++ chan ++ " [EZ]").postln;
//     });
// }, nil, nil);
// MIDIdef.noteOn(\diagNote, { |vel, note, chan, src|
//     if(src == ~ezSrcID, {
//         ("DIAG NOTEON:" ++ note ++ " vel:" ++ vel ++ " ch:" ++ chan ++ " [EZ]").postln;
//     });
// }, nil, nil);
// MIDIdef.noteOff(\diagNoteOff, { |vel, note, chan, src|
//     if(src == ~ezSrcID, {
//         ("DIAG NOTEOFF:" ++ note ++ " vel:" ++ vel ++ " ch:" ++ chan ++ " [EZ]").postln;
//     });
// }, nil, nil);
// SystemClock.sched(60.0, {
//     MIDIdef(\diagCC).free; MIDIdef(\diagNote).free; MIDIdef(\diagNoteOff).free;
//     "*** DIAGNOSTIC ended ***".postln; nil;
// });
