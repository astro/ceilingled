var SerialPort = require("serialport").SerialPort;
var serialPort = new SerialPort("/dev/ttyUSB0", { baudrate: 500000 });
var Buffer = require('buffer').Buffer;

var PHASE_MAX = 4;

function phaseToColor(phase) {
    phase %= PHASE_MAX;
    if (phase < 1) {
	return [phase, 0, 0, 1 - phase];
    } else if (phase < 2) {
	return [2 - phase, phase - 1, 0, 0];
    } else if (phase < 3) {
	return [0, 3 - phase, phase - 2, 0, 0];
    } else if (phase < 4) {
	return [0, 0, 4 - phase, phase - 3];
    }
    throw 'Invalid phase';
}

var phase = 0;
setInterval(function() {
    phase += 0.1;

    for(var i = 0; i < 4; i++) {
	var b = "\x42" +
	    String.fromCharCode(0xF0 | i);
	var rgbw = phaseToColor(phase + i);
	for(var j = 0; j < 4; j++) {
	    var v = Math.floor(rgbw[j] * 255);
	    var esc = [35,66,101,102].indexOf(v);
	    var s;
	    if (esc >= 0)
		s = "\x65" + String.fromCharCode(esc + 1);
	    else
		s = String.fromCharCode(v);
	    b += s;
	}
	console.log(new Buffer(b, 'ascii'));
	serialPort.write(b);
    }
}, 100);
