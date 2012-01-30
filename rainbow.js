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
	var b = new Buffer(6);
	b[0] = 0x42;
	b[1] = 0xF0 | i;
	var rgbw = phaseToColor(phase + i);
	for(var j = 0; j < 4; j++)
	    b[2 + j] = Math.floor(rgbw[j] * 255);
	console.log(b);
	serialPort.write(b);
    }
}, 1);
