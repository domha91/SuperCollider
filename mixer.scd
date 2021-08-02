

/*
you can record multichannel too. if you have multiple orbits, lets say 8, you can do:
*/
/*
this will write an .aiff with 16 mono channels inside

*/

s.recChannels = 16;
s.prepareForRecord;
s.record;
// after
s.stopRecording


s.meter;
FreqScope.new;
/*
s.makeWindow;

s.scope;

s.plotTree;
*/

//http://www.dewdrop-world.net/sc3/tutorials/index.php?id=1
//https:/hexler.net/products/touchosc

// TODO: Send fader OSC to Processing?
// TODO: make a mixer for the orbits, using dB scaling
// TODO: hook up mpd218 for effects and samples
// https://tidalcycles.org/Playback_Controllers


(
//Send OSC to TidalCycles
var osc;
osc = NetAddr.new("192.168.1.2", 6010);


//OSC

// OSCFunc.trace(true);


// Collect OSC for faders
~dirt.orbits.collect ({ |x, i |
	var faderPath = '/1/fader' ++ (i + 1);
	OSCdef(faderPath.asSymbol, { |msg| x.set(\amp, msg[1]); }, faderPath);
});

//touchOSC
n = NetAddr("192.168.0.50");


//Faders

OSCdef.new(
	\fader1,
	{

		arg msg, time, addr, port;
		"fader1:".postln;
		msg[1].postln;

    },
	'/1/fader1',
	n,
	8000
);


OSCdef.new(
	\fader2,
	{

		arg msg, time, addr, port;
		"fader2:".postln;
		msg[1].postln;

    },
	'/1/fader2',
	n,
	8000
);


OSCdef.new(
	\fader3,
	{

		arg msg, time, addr, port;

		"fader3:".postln;
		msg[1].postln;

    },
	'/1/fader3',
	n,
	8000
);

OSCdef.new(
	\fader4,
	{

		arg msg, time, addr, port;

		"fader4:".postln;
		msg[1].postln;

    },
	'/1/fader4',
	n,
	8000
);

OSCdef.new(
	\fader5,
	{

		arg msg, time, addr, port;
		"fader5:".postln;
		msg[1].postln;
    },
	'/1/fader5',
	n,
	8000
);

OSCdef.new(
	\fader6,
	{

		arg msg, time, addr, port;

		"fader6:".postln;
		msg[1].postln;

    },
	'/1/fader6',
	n,
	8000
);

OSCdef.new(
	\fader7,
	{

		arg msg, time, addr, port;

		"fader7:".postln;
		msg[1].postln;

	},
	'/1/fader7',
	n,
	8000
);

OSCdef.new(
	\fader8,
	{

		arg msg, time, addr, port;

		"fader8:".postln;
		msg[1].postln;

	},
	'/1/fader8',
	n,
	8000
);


// Mutes

OSCdef.new(
	\muteAll,
	{

		arg msg, time, addr, port;
		"muteAll:".postln;
		msg[1].postln;
		if (msg[1] > 0, {osc.sendMsg("/muteAll")}, {osc.sendMsg("/unmuteAll")})
    },
	'/1/muteAll',
	n,
	8000
);


OSCdef.new(
	\mute1,
	{
		arg msg, time, addr, port;
		"mute1:".postln;
		msg[1].postln;
		if (msg[1] > 0, {osc.sendMsg("/mute 1")}, {osc.sendMsg("/unmute 1")})
    },
	'/1/mute1',
	n,
	8000
);

OSCdef.new(
	\mute2,
	{

		arg msg, time, addr, port;
		"mute2:".postln;
		msg[1].postln;
		if (msg[1] > 0, {osc.sendMsg("/mute 2")}, {osc.sendMsg("/unmute 2")})
    },
	'/1/mute2',
	n,
	8000
);

OSCdef.new(
	\mute3,
	{

		arg msg, time, addr, port;
		"mute3:".postln;
		msg[1].postln;
		if (msg[1] > 0, {osc.sendMsg("/mute 3")}, {osc.sendMsg("/unmute 3")})
    },
	'/1/mute3',
	n,
	8000
);

OSCdef.new(
	\mute4,
	{

		arg msg, time, addr, port;
		"mute4:".postln;
		msg[1].postln;
		if (msg[1] > 0, {osc.sendMsg("/mute 4")}, {osc.sendMsg("/unmute 4")})
    },
	'/1/mute4',
	n,
	8000
);

OSCdef.new(
	\mute5,
	{

		arg msg, time, addr, port;
		"mute5:".postln;
		msg[1].postln;
		if (msg[1] > 0, {osc.sendMsg("/mute 5")}, {osc.sendMsg("/unmute 5")})
    },
	'/1/mute5',
	n,
	8000
);

OSCdef.new(
	\mute6,
	{

		arg msg, time, addr, port;
		"mute6:".postln;
		msg[1].postln;
		if (msg[1] > 0, {osc.sendMsg("/mute 6")}, {osc.sendMsg("/unmute 6")})
    },
	'/1/mute6',
	n,
	8000
);

OSCdef.new(
	\mute7,
	{

		arg msg, time, addr, port;
		"mute7:".postln;
		msg[1].postln;
		if (msg[1] > 0, {osc.sendMsg("/mute 7")}, {osc.sendMsg("/unmute 7")})
    },
	'/1/mute7',
	n,
	8000
);

OSCdef.new(
	\mute8,
	{

		arg msg, time, addr, port;
		"mute8:".postln;
		msg[1].postln;
		if (msg[1] > 0, {osc.sendMsg("/mute 8")}, {osc.sendMsg("/unmute 8")})
    },
	'/1/mute8',
	n,
	8000
);

// Solos

OSCdef.new(
	\soloAll,
	{

		arg msg, time, addr, port;
		"soloAll:".postln;
		msg[1].postln;
		if (msg[1] > 0, {osc.sendMsg("/soloAll")}, {osc.sendMsg("/unsoloAll")})
    },
	'/1/soloAll',
	n,
	8000
);

OSCdef.new(
	\solo1,
	{

		arg msg, time, addr, port;
		"solo1:".postln;
		msg[1].postln;
		if (msg[1] > 0, {osc.sendMsg("/solo 1")}, {osc.sendMsg("/unsolo 1")})
    },
	'/1/solo1',
	n,
	8000
);

OSCdef.new(
	\solo2,
	{

		arg msg, time, addr, port;
		"solo2:".postln;
		msg[1].postln;
		if (msg[1] > 0, {osc.sendMsg("/solo 2")}, {osc.sendMsg("/unsolo 2")})
    },
	'/1/solo2',
	n,
	8000
);

OSCdef.new(
	\solo3,
	{

		arg msg, time, addr, port;
		"solo3:".postln;
		msg[1].postln;
		if (msg[1] > 0, {osc.sendMsg("/solo 3")}, {osc.sendMsg("/unsolo 3")})
    },
	'/1/solo3',
	n,
	8000
);

OSCdef.new(
	\solo4,
	{

		arg msg, time, addr, port;
		"solo4:".postln;
		msg[1].postln;
		if (msg[1] > 0, {osc.sendMsg("/solo 4")}, {osc.sendMsg("/unsolo 4")})
    },
	'/1/solo4',
	n,
	8000
);

OSCdef.new(
	\solo5,
	{

		arg msg, time, addr, port;
		"solo5:".postln;
		msg[1].postln;
		if (msg[1] > 0, {osc.sendMsg("/solo 5")}, {osc.sendMsg("/unsolo 5")})
    },
	'/1/solo5',
	n,
	8000
);

OSCdef.new(
	\solo6,
	{

		arg msg, time, addr, port;
		"solo6:".postln;
		msg[1].postln;
		if (msg[1] > 0, {osc.sendMsg("/solo 6")}, {osc.sendMsg("/unsolo 6")})
    },
	'/1/solo6',
	n,
	8000
);

OSCdef.new(
	\solo7,
	{

		arg msg, time, addr, port;
		"solo7:".postln;
		msg[1].postln;
		if (msg[1] > 0, {osc.sendMsg("/solo 7")}, {osc.sendMsg("/unsolo 7")})
    },
	'/1/solo7',
	n,
	8000
);

OSCdef.new(
	\solo8,
	{

		arg msg, time, addr, port;
		"solo8:".postln;
		msg[1].postln;
		if (msg[1] > 0, {osc.sendMsg("/solo 8")}, {osc.sendMsg("/unsolo 8")})
    },
	'/1/solo8',
	n,
	8000
);
)

/*ROUTING AND EFFECTS*/

//https://github.com/musikinformatik/SuperDirt/blob/master/hacks/adding-effects.scd

//TODO: LOOK UP ORBIT EFFECTS IN SUPERDIRT DOCS

//https://github.com/musikinformatik/SuperDirt/blob/master/hacks/filtering-dirt-output.scd

//EFFECT DEFS

//TODO: WRITE SOME EFFECTS IN LOCAL FILES

/*SynthDef(\template,

{

arg inBuss, outBuss, amp = 1,

atk=0.02, rel=0.1, crv= -2, gate=1;

var source, sig, env;

env = EnvGen.ar( Env.asr(atk,1,rel,crv), gate);

source = In.ar(inBuss);

sig = FX(source);

Out.ar(outBuss, sig*amp*env);

}).add;*/

