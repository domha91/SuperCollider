// ============================================================
// rig_launchpad.scd
// Launchpad Mini MK3: many pages of 8x8 patterns + LED feedback
// File location: ~/.config/SuperCollider/rig_launchpad.scd  (next to startup.scd)
//
// Loaded from startup.scd (see the RIG EXTENSIONS block). It runs inside
// s.waitForBoot, after Section 3d has created ~lpOut, ~lpSrcID, ~lpSetMode etc.
// It REPLACES the handlers \launchpadOn and \launchpadPage from Section 3d
// (same names, so the later definition wins) and works with
// rig_launchpad.hs on the Tidal side (Tidal listens on port 57161).
//
// WHAT THE LAUNCHPAD DOES NOW
//   8x8 pads ....... row 1 (top) = d1 ... row 8 (bottom) = d8, column = slot 1-8,
//                    exactly as before. Press = start that pattern on that orbit,
//                    press the lit pad again = stop that orbit.
//   Right column ... the 8 round buttons jump straight to page 1-8 of the current
//                    block of 8 pages (top button = first page of the block).
//                    Lit: white = this page, amber = something is playing from that
//                    page, dim = page exists, dark = no such page.
//   Top row ........ left/right arrows (CC 93/94) step one page back/forward and wrap
//                    round; up/down arrows (CC 91/92) jump a whole block of 8 pages.
//                    Lit only when there is somewhere to go. The other four top-row
//                    buttons (CC 95-98) are left alone.
//   LEDs on a page . dark = empty slot (a pad that does nothing),
//                    dim colour = pattern available, bright colour = playing.
//   There is no fixed number of pages: Tidal tells SuperCollider how many exist.
//
// SC 3.11 HARD RULES apply here too (see the header of startup.scd): no var
// after statements, no var inside if-branches, no ^ early return in MIDI callbacks.
// ============================================================


// ── 1. SETTINGS (edit, save, reboot SC) ──────────────────────
// Colours are Launchpad palette numbers 0-127. 0 = off, 1 = dim, 9 = amber are
// the ones your rig already used. Set ~lpPaletteTest to 1 (or 2) to see what
// every number looks like on your unit (see the guide).
~lpTidalPort      = 57161;                // Tidal side: rig_launchpad.hs
~lpColEmpty       = 0;                    // slot has no pattern
~lpColFilled      = Array.fill(8, { 1 }); // pattern available    (one number per row d1..d8)
~lpColActive      = Array.fill(8, { 9 }); // pattern playing      (one number per row d1..d8)
~lpChanActive     = 0;                    // playing pad: 0 steady, 2 pulsing, 1 flashing
~lpColPageCurrent = 3;                    // page button: the page you are on
~lpColPagePlaying = 9;                    // page button: something plays from that page
~lpColPageOther   = 1;                    // page button: page exists
~lpColNav         = 1;                    // arrow buttons when they can be used
~lpArrowLock      = 0.2;                  // seconds. After an arrow button (CC 91-94) has acted, further messages from
                                          // the same button are ignored for this long. A tap can send a message on press
                                          // AND on release; this makes one tap = one step. If one tap ever moves two
                                          // pages, raise it (0.35); if quick taps get lost, lower it (0.1).
~lpPaletteTest    = 0;                    // 0 off | 1 show colours 0-63 | 2 show 64-127 (pads show them for 20 s, starting 2.5 s after boot)


// ── 2. STATE ─────────────────────────────────────────────────
~lpTidalNet    = NetAddr("127.0.0.1", ~lpTidalPort);
~lpPage        = 0;                       // page showing now (0 = page 1)
~lpPageCount   = 1;                       // how many pages exist (Tidal reports this)
~lpGrid        = nil;                     // one 64-character string per page: "1" = pattern, "0" = empty
~lpActive      = Array.fill(8, { nil });  // per orbit d1..d8: nil or [page, slot]
~lpActiveAt    = Array.fill(8, { 0.0 });  // when each orbit was last started (seconds)
~lpNoteLastTime = Dictionary.new;
~lpPageLastTime = Dictionary.new;

// Latency 0 so LEDs follow your finger (the default 0.2 s delay is noticeable).
if(~lpOut.notNil, { ~lpOut.latency = 0 });


// ── 3. HELPERS ───────────────────────────────────────────────

// True for messages from the Launchpad (its two MIDI ports are ~lpSrcID and +1).
// The short-circuit && keeps this safe when no Launchpad was found at boot.
~lpIsSrc = { |src|
    ~lpSrcID.notNil && { (src == ~lpSrcID) || (src == (~lpSrcID + 1)) }
};

// Does this page/orbit/slot hold a pattern? (orbit and slot are 1-8.)
// Until Tidal has reported its grid, every pad counts as filled.
~lpFilledAt = { |page, orbit, slot|
    var mask;
    if(~lpGrid.isNil, { true }, {
        mask = ~lpGrid[page];
        if(mask.isNil, { true }, { mask[((orbit - 1) * 8) + (slot - 1)] == $1 });
    });
};

// Redraw every LED: 64 pads, the page buttons, the arrows.
~lpPaint = {
    var pagePlaying, act, note, col, chan, isAct, bank, pg, banks, nav;
    if(~lpOut.notNil, {
        pagePlaying = Array.fill(max(~lpPageCount, 1), { false });
        8.do({ |oi|
            act = ~lpActive[oi];
            if(act.notNil, {
                if(act[0] < pagePlaying.size, { pagePlaying[act[0]] = true });
            });
        });

        // pads
        8.do({ |oi|
            act = ~lpActive[oi];
            8.do({ |si|
                note  = ((8 - oi) * 10) + (si + 1);
                isAct = act.notNil && { (act[0] == ~lpPage) && (act[1] == (si + 1)) };
                col = if(isAct, { ~lpColActive[oi] }, {
                    if(~lpFilledAt.(~lpPage, oi + 1, si + 1), { ~lpColFilled[oi] }, { ~lpColEmpty });
                });
                chan = if(isAct, { ~lpChanActive }, { 0 });
                ~lpOut.noteOn(chan, note, col);
            });
        });

        // right-hand column: page buttons for the block of 8 pages you are in
        bank = ~lpPage.div(8);
        8.do({ |k|
            pg  = (bank * 8) + k;
            col = if(pg >= ~lpPageCount, { 0 }, {
                if(pg == ~lpPage, { ~lpColPageCurrent }, {
                    if(pagePlaying[pg], { ~lpColPagePlaying }, { ~lpColPageOther });
                });
            });
            ~lpOut.control(0, 89 - (k * 10), col);
        });

        // top row: arrows
        banks = (~lpPageCount + 7).div(8);
        nav = if(~lpPageCount > 1, { ~lpColNav }, { 0 });
        ~lpOut.control(0, 93, nav);
        ~lpOut.control(0, 94, nav);
        nav = if(banks > 1, { ~lpColNav }, { 0 });
        ~lpOut.control(0, 91, nav);
        ~lpOut.control(0, 92, nav);
    });
};
~lpRefreshGrid = { ~lpPaint.() };    // the old Section 3d name keeps working

~lpGoto = { |target|
    if((target >= 0) && (target < ~lpPageCount), {
        ~lpPage = target;
        ("Launchpad page " ++ (target + 1) ++ " of " ++ ~lpPageCount).postln;
        ~lpPaint.();
    });
};
~lpStep = { |delta| ~lpGoto.((~lpPage + delta).mod(~lpPageCount)) };
~lpHop  = { |delta|     // a whole block of 8 pages, same position in the block
    var banks, bank, target;
    banks  = (~lpPageCount + 7).div(8);
    bank   = (~lpPage.div(8) + delta).mod(banks);
    target = ((bank * 8) + (~lpPage % 8)).min(~lpPageCount - 1);
    ~lpGoto.(target);
};

// Palette test: pad colour number = start + 8 x (rows up from the bottom) + (columns across from the left)
~lpShowPalette = { |start|
    8.do({ |r|
        8.do({ |c|
            ~lpOut.noteOn(0, ((r + 1) * 10) + (c + 1), start + (r * 8) + c);
        });
    });
};


// ── 4. PADS ──────────────────────────────────────────────────
// Same debounce as before (the device delivers every press on two ports).
MIDIdef.noteOn(\launchpadOn, { |vel, noteNum, chan, src|
    var row, col, orbit, slot, now, last, act;
    if(~lpIsSrc.(src) && (vel > 63), {
        now  = SystemClock.seconds;
        last = ~lpNoteLastTime[noteNum];
        if(last.isNil, { last = -1 });
        if((last < 0) || ((now - last) > 0.05), {
            ~lpNoteLastTime[noteNum] = now;
            row = noteNum.div(10);
            col = noteNum % 10;
            if((row >= 1) && (row <= 8) && (col >= 1) && (col <= 8), {
                orbit = 9 - row;
                slot  = col;
                act   = ~lpActive[orbit - 1];
                if(act.notNil && { (act[0] == ~lpPage) && (act[1] == slot) }, {
                    // the pad that is playing: stop that orbit
                    ~lpTidalNet.sendMsg("/lp/off", orbit);
                    ~lpActive[orbit - 1] = nil;
                    ("LP off: d" ++ orbit).postln;
                    ~lpPaint.();
                }, {
                    if(~lpFilledAt.(~lpPage, orbit, slot), {
                        ~lpTidalNet.sendMsg("/lp/on", orbit, slot, ~lpPage);
                        ~lpActive[orbit - 1] = [~lpPage, slot];
                        ~lpActiveAt[orbit - 1] = now;
                        ("LP on: d" ++ orbit ++ " page " ++ (~lpPage + 1) ++ " slot " ++ slot).postln;
                        ~lpPaint.();
                    }, {
                        ("LP: d" ++ orbit ++ " slot " ++ slot ++ " is empty on page " ++ (~lpPage + 1)).postln;
                    });
                });
            });
        });
    });
}, nil, nil);


// ── 5. PAGE BUTTONS ──────────────────────────────────────────
// Right column CC 89, 79 ... 19 = pages 1-8 of this block (jumping to a page is
// harmless if the message arrives twice). Top row: 93 / 94 = back / forward one
// page, 91 / 92 = back / forward one block of 8. The device delivers every press on
// two ports and may also report the release, so each button is debounced: 50 ms for
// the right column, ~lpArrowLock (0.2 s) for the four arrows, which step relative to
// where you are and so must not act twice for one tap.
MIDIdef.cc(\launchpadPage, { |val, num, chan, src|
    var now, last, k, lock;
    if(~lpIsSrc.(src) && (((num >= 91) && (num <= 94)) || ((num % 10) == 9)), {
        now  = SystemClock.seconds;
        last = ~lpPageLastTime[num];
        if(last.isNil, { last = -1 });
        lock = if(num >= 91, { ~lpArrowLock }, { 0.05 });
        if((last < 0) || ((now - last) > lock), {
            ~lpPageLastTime[num] = now;
            if(num == 93, { ~lpStep.(-1) });
            if(num == 94, { ~lpStep.(1) });
            if(num == 91, { ~lpHop.(-1) });
            if(num == 92, { ~lpHop.(1) });
            if((num % 10) == 9, {
                k = (89 - num).div(10);
                ~lpGoto.((~lpPage.div(8) * 8) + k);
            });
        });
    });
}, nil, nil);


// ── 6. MESSAGES FROM TIDAL ───────────────────────────────────
// /lp/grid  <pageCount> <mask page 1> <mask page 2> ...
//     one 64-character "0"/"1" string per page (orbit d1..d8 x slot 1..8, row by row).
//     OSC strings arrive as Symbols, hence the .asString.
OSCdef(\lpGrid, { |msg|
    var count;
    count = msg[1].asInteger;
    if(count >= 1, {
        ~lpGrid      = Array.fill(count, { |i| msg[i + 2].asString });
        ~lpPageCount = count;
        if(~lpPage >= count, { ~lpPage = 0 });
        ("Launchpad: Tidal reports " ++ count ++ " page(s)").postln;
        ~lpPaint.();
    });
}, '/lp/grid');

// /lp/playing <8-character mask for d1..d8>: "1" = that orbit is making sound in Tidal.
// If you hush an orbit at the Tidal prompt, its pad goes dark. An orbit started less
// than 1.5 s ago is left alone, so a report that was already in flight cannot undo a press.
OSCdef(\lpPlaying, { |msg|
    var mask, now, changed;
    mask    = msg[1].asString;
    now     = SystemClock.seconds;
    changed = false;
    8.do({ |oi|
        if((mask[oi] == $0) && ~lpActive[oi].notNil && ((now - ~lpActiveAt[oi]) > 1.5), {
            ~lpActive[oi] = nil;
            changed = true;
        });
    });
    if(changed, { ~lpPaint.() });
}, '/lp/playing');


// ── 7. START-UP ──────────────────────────────────────────────
// After Section 3d has switched the device to Programmer mode (2.0 s), paint it
// and ask Tidal for its grid (if Tidal is not running yet, it reports when it loads).
SystemClock.sched(2.5, {
    if(~lpPaletteTest > 0, {
        ~lpShowPalette.((~lpPaletteTest - 1) * 64);
        "LP palette test: pad colour number = start + 8 x (rows up from the bottom) + (columns across from the left)".postln;
        ("  start = " ++ ((~lpPaletteTest - 1) * 64) ++ "; the normal display returns in 20 s").postln;
        SystemClock.sched(20.0, { ~lpPaint.(); nil });
    }, {
        ~lpPaint.();
    });
    ~lpTidalNet.sendMsg("/lp/request");
    nil
});

"Launchpad: multi-page LED extension loaded (Tidal side on port 57161).".postln;
