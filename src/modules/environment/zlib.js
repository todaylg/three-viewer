const zlib = window.Zlib;

function isGunzipBuffer(arrayBuffer) {
	let typedArray = new Uint8Array(arrayBuffer);
	return typedArray[0] === 0x1f && typedArray[1] === 0x8b;
}

function gunzip(arrayBuffer) {
	let typedArray = new Uint8Array(arrayBuffer);
	if (!zlib) {
		console.error(
			'Lack of necessary dependencies: gunzip.min.js.\n You can add this vendors to enable this feature or get it at https://github.com/imaya/zlib.js/blob/master/bin/gunzip.min.js'
		);
		return;
	}
	let zdec = new zlib.Gunzip(typedArray);
	let result = zdec.decompress();
	return result.buffer;
}

export {
	isGunzipBuffer,
	gunzip
};
