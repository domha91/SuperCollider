

s.options.numBuffers = 1024 * 256; // increase this if you need to load more samples

s.options.memSize = 8192 * 16; // increase this if you get "alloc failed" messages

s.options.maxNodes = 1024 * 32; // increase this if you are getting drop outs and the message "too many nodes"

s.options.numWireBufs = 64 * 2; // increase this if you get "exceeded number of interconnect buffers" messages

s.options.numOutputBusChannels = 2; // set this to your hardware output channel size, if necessary

s.options.numInputBusChannels = 2; // set this to your hardware output channel size, if necessary

// s.options.maxLogins = 8;

s.options.memSize = 200536;


(

s.waitForBoot {

~dirt = SuperDirt(2, s); // two output channels per orbit´

//lazy-load samples
/*~dirt.doNotReadYet = true;*/

//Add your own samples here:
~dirt.loadSoundFiles("/home/domha91/.local/share/SuperCollider/downloaded-quarks/Dirt-Samples/*");

~dirt.loadSoundFiles("/home/domha91/.local/share/SuperCollider/downloaded-quarks/samples-extra/*");

s.sync; // wait for supercollider to finish booting up

//Start SuperDirt listening to OSC from same machine
//~dirt.start(57120, [0, 0, 0, 0, 0, 0, 0, 0 ]); // start Superdirt, listening on port 57120, orbits summed to one hardware out

//~dirt.start(57120, [0, 2, 4, 6, 8, 10, 12, 14 ]); // start superdirt, listening on port 57120,  Separate Hardware Outs

//Start SuperDirt listening to External OSC e.g. from Laptop
~dirt.start(57120, [0, 0, 0, 0, 0, 0, 0, 0 ], NetAddr("0.0.0.0"));

//~dirt.start(57120, [0, 2, 4, 6, 8, 10, 12, 14 ], NetAddr("0.0.0.0")); // start superdirt, listening on port 57120,  Separate Hardware Outs

// Start MIDI client

MIDIClient.init;


//Midi to Midihub

~midiOut = MIDIOut.newByName("Rubix24", "Rubix24 MIDI 1");   //substitute your own device here


~dirt.soundLibrary.addMIDI(\midi, ~midiOut);


// ~midiOut.latency = 0;


//Audio from Microkorg


~microKorg = {SoundIn.ar([0,0])}.play;


//Audio from Mic


~mic = {SoundIn.ar([1,1])}.play;


//TODO: CREATE SOME SYNTHDEFS IN C:\Users\domha\AppData\Local\SuperCollider\downloaded-quarks\SuperDirt\classes\..\synths\try-load-extra-synths.scd

//SYNTHS

//EFFECTS

//TUNINGS
// https://github.com/musikinformatik/SuperDirt/blob/develop/hacks/pitch-model-from-tidal.scd


// if we want to pick scales and tunings by name
// this works only when synths use \freq as argument
(
~dirt.orbits.do { |x|
	var event = x.defaultParentEvent;
	var pitchEvent = Event.partialEvents.pitchEvent.copy;
	var scale, tuning;
	pitchEvent.use {
		~freq = {
			if(~n != 0) { ~note = ~n }; // interpret n as note (might be also degree)
			~scaleName !? {
				scale = Scale.at(~scaleName);
				scale !? {
					~scale = scale;
					~tuningName !? {
						tuning = Tuning.at(~tuningName);
						tuning !? { ~scale = ~scale.copy; ~scale.tuning = tuning };
					}
				}
			};
			(~midinote.value + ~ctranspose).midicps * ~harmonic;
		};

		[\freq, \midinote, \octave].do(event.removeAt(_));

		event.parent = pitchEvent;
	}
};
)

};

);