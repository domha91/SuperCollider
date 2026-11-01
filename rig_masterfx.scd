// ============================================================
// rig_masterfx.scd
// Master FX on everything that reaches the speakers, driven by the 18 MPD218 knobs
// File location: ~/.config/SuperCollider/rig_masterfx.scd  (next to startup.scd)
//
// Loaded from startup.scd (RIG EXTENSIONS block), inside s.waitForBoot, after
// Section 3g has created ~gainGroup and Section 3e has registered the MPD218 knobs.
// It REPLACES the 18 knob handlers \mpd_k_a1 ... \mpd_k_c6 of Section 3e (same names,
// so the later definition wins). They still update ~mpdA1 ... ~mpdC6 exactly as before.
//
// WHAT IT DOES
//   One synth, \masterFx, is placed AFTER ~gainGroup, which is after every other synth
//   in the rig: the SuperDirt orbits with their reverb and gain, the mic monitor, the
//   Microkorg pass-through and the MPD218 one-shot samples. It reads the output bus
//   (speakers 1+2), runs your FX chain, and writes the result back over the same bus.
//   As delivered the chain is EMPTY, so the sound is untouched (checked bit for bit).
//
//   The 18 knobs (A1-A6, B1-B6, C1-C6) reach your chain as an array k of 18 numbers
//   between 0 and 1:   k[0] = A1 ... k[5] = A6,  k[6] = B1 ... k[11] = B6,
//                      k[12] = C1 ... k[17] = C6.
//
// WHERE TO PUT YOUR FX: ~mfxChain in section 2 below. Nothing else needs touching.
// If the chain has an error, SuperCollider says so in the post window and the master
// FX simply does not start: your sound carries on unprocessed.
//
// SC 3.11 HARD RULES apply here too (see the header of startup.scd): no var after
// statements, no var inside if-branches, no ^ early return in MIDI callbacks.
// ============================================================


// ── 1. SETTINGS (edit, save, reboot SC) ──────────────────────
~mfxEnable    = 1;                          // 0 = leave Section 3e's knob handlers alone, no master FX
~mfxBus       = 0;                          // first of the two output channels to process (0 = speakers 1+2)
~mfxCCs       = Array.series(18, 0, 1);     // CC numbers of knobs A1-A6, B1-B6, C1-C6 (the numbers Section 3e uses)
~mfxChan      = 9;                          // MIDI channel of the knobs, counted from 0 (9 = "channel 10")
~mfxStartVals = Array.fill(18, { 0.0 });    // where each knob starts (0 to 1) until you move it
~mfxPickup    = 0;                          // 1 = a knob does nothing until you turn it through the value it holds
~mfxSmooth    = 0.05;                       // seconds of smoothing on knob moves (stops zipper noise)
~mfxLimiter   = 0;                          // 1 = brick-wall limiter at the very end (delays EVERYTHING by 10 ms, mic monitor too)
~mfxPost      = 0;                          // 1 = print every knob move in the post window
~mfxLogCC     = 0;                          // 1 = print every CC the MPD218 sends (to check your knob numbers)


// ── 2. YOUR FX CHAIN ─────────────────────────────────────────
// in = the stereo signal that is about to reach the speakers (in[0] left, in[1] right)
// k  = the 18 knob values, 0 to 1, already smoothed: k[0] = A1 ... k[17] = C6
// The function ends with the stereo signal you want to hear. Ready-made examples are
// in EXTENDING_THE_RIG.md. Every knob you do not use is simply ignored.
~mfxChain = { |in, k|
    var sig;
    sig = in;
    // ---- your effects go between here ...

    // ---- ... and here
    sig
};


// ── 3. PLUMBING (no need to edit below this line) ────────────
~mfxNames     = Array.fill(18, { |i| ("k" ++ (i + 1)).asSymbol });
~mfxKnobNames = ["A1", "A2", "A3", "A4", "A5", "A6", "B1", "B2", "B3", "B4", "B5", "B6", "C1", "C2", "C3", "C4", "C5", "C6"];
~mfxPos       = Array.fill(18, { |i| ~mfxStartVals[i] ? 0.0 });   // value each knob holds now
~mfxCaught    = Array.fill(18, { true });                          // pickup: has this knob caught its value?
~mfxPotLast   = Array.fill(6, { nil });                            // pickup: last reading of each of the 6 physical knobs
~mfxPotOwner  = Array.fill(6, { nil });                            // pickup: which FX knob that physical knob last drove
~mfxSynth     = nil;

// The synth definition. The chain from section 2 is called while the definition is built.
~mfxMakeDef = {
    SynthDef(\masterFx, { |bus = 0, bypass = 0, smooth = 0.05,
            k1 = 0, k2 = 0, k3 = 0, k4 = 0, k5 = 0, k6 = 0,
            k7 = 0, k8 = 0, k9 = 0, k10 = 0, k11 = 0, k12 = 0,
            k13 = 0, k14 = 0, k15 = 0, k16 = 0, k17 = 0, k18 = 0|
        var in, k, sig, byp;
        in  = In.ar(bus, 2);
        k   = Lag.kr([k1, k2, k3, k4, k5, k6, k7, k8, k9, k10, k11, k12, k13, k14, k15, k16, k17, k18], smooth);
        sig = ~mfxChain.value(in, k);
        if(~mfxLimiter == 1, { sig = Limiter.ar(sig, 0.95, 0.01) });
        byp = Lag.kr(bypass, 0.02);
        sig = (sig * (1 - byp)) + (in * byp);          // bypass 0 = your chain, 1 = the untouched signal
        ReplaceOut.ar(bus, Sanitize.ar(sig));          // Sanitize turns NaN / infinity into silence
    }).add;
};

// Send a knob value to the synth (and print it if ~mfxPost is on).
~mfxApply = { |i, x|
    if(~mfxSynth.notNil, { ~mfxSynth.set(~mfxNames[i], x) });
    if(~mfxPost == 1, { ("FX knob " ++ ~mfxKnobNames[i] ++ " = " ++ x.round(0.01)).postln });
};

// A knob moved: i = which of the 18 (0-17), x = its position 0 to 1.
// With pickup on, a knob is ignored until it reaches (or crosses) the value that FX knob holds.
// The MPD218 has only 6 physical knobs shared by its 3 banks, so when the same physical knob
// starts driving a different FX knob (you changed bank), the new one has to be caught again.
~mfxKnob = { |i, x|
    var p, prev, pos, hit;
    p    = i % 6;
    prev = ~mfxPotLast[p];
    pos  = ~mfxPos[i];
    if(~mfxPickup == 1, {
        if(~mfxPotOwner[p] != i, { ~mfxCaught[i] = false });
        if(~mfxCaught[i].not, {
            hit = ((x - pos).abs <= 0.02);
            if(hit.not && prev.notNil, { hit = (((x - pos) * (prev - pos)) <= 0) });
            if(hit, { ~mfxCaught[i] = true });
        });
    }, {
        ~mfxCaught[i] = true;
    });
    ~mfxPotOwner[p] = i;
    ~mfxPotLast[p]  = x;
    if(~mfxCaught[i], {
        ~mfxPos[i] = x;
        ~mfxApply.(i, x);
    });
};

// Build the definition and start the synth right after ~gainGroup (or at the very end of the
// node tree if there is no ~gainGroup). Must run inside a routine (it waits for the server).
// Calling it again replaces the running synth, which is how a changed ~mfxChain is picked up.
~mfxStart = {
    try {
        ~mfxMakeDef.value;
        s.sync;
        if(~mfxSynth.notNil, { ~mfxSynth.free; ~mfxSynth = nil });
        ~mfxArgs = [\bus, ~mfxBus, \smooth, ~mfxSmooth] ++ ~mfxNames.collect({ |n, i| [n, ~mfxPos[i]] }).flat;
        if(~gainGroup.notNil, {
            ~mfxSynth = Synth.after(~gainGroup, \masterFx, ~mfxArgs);
        }, {
            ~mfxSynth = Synth.tail(RootNode(s), \masterFx, ~mfxArgs);
        });
        ~mfxSynth.register;
        s.sync;
        if(~mfxSynth.isPlaying, {
            ("Master FX: running " ++ if(~gainGroup.notNil, { "after the gain group" }, { "at the end of the node tree" })
                ++ " on output " ++ (~mfxBus + 1) ++ "+" ++ (~mfxBus + 2)
                ++ ", knobs on CC " ++ ~mfxCCs.first ++ "-" ++ ~mfxCCs.last ++ " channel " ++ ~mfxChan
                ++ (if(~mfxPickup == 1, { ", pickup on" }, { "" }))).postln;
        }, {
            "Master FX: the synth did NOT start. Your sound is unaffected. Look above for the reason.".postln;
            ~mfxSynth = nil;
        });
    } { |err|
        ("Master FX: NOT started, your sound is unaffected. Reason: " ++ err.errorString).postln;
        ~mfxSynth = nil;
    };
};

if(~mfxEnable == 1, {

    if(~mpdSrcID.notNil, {

        // The 18 knob handlers: same names as Section 3e, so they replace the old ones.
        MIDIdef.cc(\mpd_k_a1, { |val| ~mpdA1 = val / 127.0; ~mfxKnob.(0,  val / 127.0) }, ~mfxCCs[0],  ~mfxChan, ~mpdSrcID);
        MIDIdef.cc(\mpd_k_a2, { |val| ~mpdA2 = val / 127.0; ~mfxKnob.(1,  val / 127.0) }, ~mfxCCs[1],  ~mfxChan, ~mpdSrcID);
        MIDIdef.cc(\mpd_k_a3, { |val| ~mpdA3 = val / 127.0; ~mfxKnob.(2,  val / 127.0) }, ~mfxCCs[2],  ~mfxChan, ~mpdSrcID);
        MIDIdef.cc(\mpd_k_a4, { |val| ~mpdA4 = val / 127.0; ~mfxKnob.(3,  val / 127.0) }, ~mfxCCs[3],  ~mfxChan, ~mpdSrcID);
        MIDIdef.cc(\mpd_k_a5, { |val| ~mpdA5 = val / 127.0; ~mfxKnob.(4,  val / 127.0) }, ~mfxCCs[4],  ~mfxChan, ~mpdSrcID);
        MIDIdef.cc(\mpd_k_a6, { |val| ~mpdA6 = val / 127.0; ~mfxKnob.(5,  val / 127.0) }, ~mfxCCs[5],  ~mfxChan, ~mpdSrcID);
        MIDIdef.cc(\mpd_k_b1, { |val| ~mpdB1 = val / 127.0; ~mfxKnob.(6,  val / 127.0) }, ~mfxCCs[6],  ~mfxChan, ~mpdSrcID);
        MIDIdef.cc(\mpd_k_b2, { |val| ~mpdB2 = val / 127.0; ~mfxKnob.(7,  val / 127.0) }, ~mfxCCs[7],  ~mfxChan, ~mpdSrcID);
        MIDIdef.cc(\mpd_k_b3, { |val| ~mpdB3 = val / 127.0; ~mfxKnob.(8,  val / 127.0) }, ~mfxCCs[8],  ~mfxChan, ~mpdSrcID);
        MIDIdef.cc(\mpd_k_b4, { |val| ~mpdB4 = val / 127.0; ~mfxKnob.(9,  val / 127.0) }, ~mfxCCs[9],  ~mfxChan, ~mpdSrcID);
        MIDIdef.cc(\mpd_k_b5, { |val| ~mpdB5 = val / 127.0; ~mfxKnob.(10, val / 127.0) }, ~mfxCCs[10], ~mfxChan, ~mpdSrcID);
        MIDIdef.cc(\mpd_k_b6, { |val| ~mpdB6 = val / 127.0; ~mfxKnob.(11, val / 127.0) }, ~mfxCCs[11], ~mfxChan, ~mpdSrcID);
        MIDIdef.cc(\mpd_k_c1, { |val| ~mpdC1 = val / 127.0; ~mfxKnob.(12, val / 127.0) }, ~mfxCCs[12], ~mfxChan, ~mpdSrcID);
        MIDIdef.cc(\mpd_k_c2, { |val| ~mpdC2 = val / 127.0; ~mfxKnob.(13, val / 127.0) }, ~mfxCCs[13], ~mfxChan, ~mpdSrcID);
        MIDIdef.cc(\mpd_k_c3, { |val| ~mpdC3 = val / 127.0; ~mfxKnob.(14, val / 127.0) }, ~mfxCCs[14], ~mfxChan, ~mpdSrcID);
        MIDIdef.cc(\mpd_k_c4, { |val| ~mpdC4 = val / 127.0; ~mfxKnob.(15, val / 127.0) }, ~mfxCCs[15], ~mfxChan, ~mpdSrcID);
        MIDIdef.cc(\mpd_k_c5, { |val| ~mpdC5 = val / 127.0; ~mfxKnob.(16, val / 127.0) }, ~mfxCCs[16], ~mfxChan, ~mpdSrcID);
        MIDIdef.cc(\mpd_k_c6, { |val| ~mpdC6 = val / 127.0; ~mfxKnob.(17, val / 127.0) }, ~mfxCCs[17], ~mfxChan, ~mpdSrcID);

        if(~mfxLogCC == 1, {
            MIDIdef.cc(\mfx_log, { |val, num, chan|
                ("MPD218 CC  number=" ++ num ++ "  channel=" ++ chan ++ "  value=" ++ val).postln;
            }, nil, nil, ~mpdSrcID);
            "Master FX: ~mfxLogCC is on, every CC from the MPD218 is printed (turn a knob to see its number).".postln;
        });

    }, {
        // Without a source id these handlers would answer ANY device that sends these CC numbers on
        // this channel, and the EZ-Creator's bank 1 does exactly that. So they are left out.
        "Master FX: MPD218 not found at boot (~mpdSrcID is nil), so its knob handlers are NOT registered and the FX stay at their start values. Connect the MPD218 and reboot SC.".postln;
    });

    // Start it in its own routine so that waiting for the server (s.sync) works whichever
    // thread loaded this file.
    fork { ~mfxStart.value };

}, {
    "Master FX: disabled (~mfxEnable = 0), Section 3e's knob handlers are untouched.".postln;
});
