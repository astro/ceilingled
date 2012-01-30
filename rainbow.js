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
    phase += 0.001;

    for(var i = 0; i < 4; i++) {
	var b = new Buffer(10), bi = 0;
	b[bi++] = 0x42;
	b[bi++] = 0xF0 | i;
	var rgbw = phaseToColor(phase + i);
	for(var j = 0; j < 4; j++) {
	    var value = Math.floor(rgbw[j] * 255);
	    var escape = 0;
	    switch(value) {
		case 0x66:
		    escape++;
		case 0x65:
		    escape++;
		case 0x42:
		    escape++;
		case 0x23:
		    escape++;
		    b[bi++] = 0x65;
		    b[bi++] = escape;
		    break;
		default:
		    b[bi++] = value;
	    }
	}
	b = b.slice(0, bi);
	serialPort.write(b);
    }
}, 1);
