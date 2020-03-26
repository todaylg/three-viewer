import requestFile from './requestFile.js';

let mimeTypes = new Map();

var isString = function(str) {
	return typeof str === 'string' || str instanceof String;
};

var isBlobURL = function(str) {
	return str.substr(0, 9) === 'blob:http';
};

var isHttpURL = function(str) {
	return str.substr(0, 7) === 'http://' || str.substr(0, 8) === 'https://';
};

var isURL = function(str) {
	if (!isString(str)) return false;

	return isBlobURL(str) || isHttpURL(str);
};

var createImageFromURL = function(url) {
	return new Promise(function(resolve, reject) {
		var img = new Image();
		img.onerror = function() {
			reject(img);
		};

		img.onload = function() {
			resolve(img);
		};
		img.src = url;
	});
};

var createImageFromBlob = function(blob) {
	var privateURL = window.URL.createObjectURL(blob);
	var promise = createImageFromURL(privateURL);

	promise.finally(function() {
		window.URL.revokeObjectURL(privateURL);
	});
	return promise;
};

var createArrayBufferFromBlob = function(blob) {
	return new Promise(function(resolve, reject) {
		var fr = new FileReader();

		fr.onerror = function() {
			reject(fr);
		};

		fr.onload = function() {
			resolve(this.result);
		};
		fr.readAsArrayBuffer(blob);
	});
};

var createArrayBufferFromURL = function(url) {
	return requestFile(url, {
		responseType: 'arraybuffer'
	});
};

var createJSONFromURL = function(url) {
	return requestFile(url).then(function(string) {
		return JSON.parse(string);
	});
};

var createJSONFromString = function(str) {
	var obj = JSON.parse(str);
	return Promise.resolve(obj);
};

var fileHelper = {
	createJSONFromURL: createJSONFromURL,
	createArrayBufferFromURL: createArrayBufferFromURL,
	createArrayBufferFromBlob: createArrayBufferFromBlob,
	createImageFromBlob: createImageFromBlob,
	createImageFromURL: createImageFromURL,

	requestURI: requestFile,
	requestResource: function(uri, options) {
		var extension = fileHelper.getExtension(uri);
		var mimetype = fileHelper.getMimeType(extension);

		var responseType = options && options.responseType ? options.responseType.toLowerCase() : undefined;
		if (responseType) return requestFile(uri, options);

		if (mimetype) {
			if (mimetype.match('image')) return createImageFromURL(uri);
			else if (mimetype.match('binary')) return createArrayBufferFromURL(uri);
			else if (mimetype.match('json')) return createJSONFromURL(uri);
			else if (mimetype.match('text')) return requestFile(uri);
		}

		return requestFile(uri);
	},

	//     file.png :  url          -> fetch/createImage            ->   Image
	//     file.png :  blob         -> createImage                  ->   Image
	//     file.png :  Image        -> passthroug                   ->   Image
	//     file.txt :  blob         -> FileReader                   ->   String
	//     file.txt :  string       -> passthroug                   ->   String
	//     file.txt :  url          -> fetch                        ->   String
	//     file.json:  string       -> JSON.parse                   ->   Object
	//     file.json:  url          -> fetch/JSON.parse             ->   Object
	//     file.json:  blob         -> FileReader/JSON.parse        ->   Object
	//     file.bin :  blob         -> FileReader/readAsArrayBuffer ->   arrayBuffer
	//     file.bin :  url          -> fetch as arra yBuffer        ->   arrayBuffer
	//     file.bin :  arrayBuffer  -> passthroug                   ->   arrayBuffer
	resolveData: function(uri, data) {
		var extension = fileHelper.getExtension(uri);
		var mimetype = fileHelper.getMimeType(extension);
		var createData;

		if (mimetype) {
			if (mimetype.match('image')) {
				if (isString(data)) createData = createImageFromURL;
				else if (data instanceof Blob) createData = createImageFromBlob;
			} else if (mimetype.match('json')) {
				if (isURL(data)) createData = createJSONFromURL;
				else createData = createJSONFromString;
			} else if (mimetype.match('binary')) {
				if (isString(data)) createData = createArrayBufferFromURL;
				else if (data instanceof Blob) createData = createArrayBufferFromBlob;
			}
		}

		var promise;
		if (createData) {
			promise = createData(data);
		} else {
			promise = Promise.resolve(data);
		}
		return promise;
	},

	resolveFilesMap: function(filesMap) {
		var promises = [];

		for (var filename in filesMap) {
			var data = filesMap[filename];
			var promise = fileHelper.resolveData(filename, data).then(
				function(fname, dataResolved) {
					this[fname] = dataResolved;
				}.bind(filesMap, filename)
			);
			promises.push(promise);
		}

		return Promise.all(promises).then(function() {
			return filesMap;
		});
	},

	getMimeType: function(extension) {
		return mimeTypes.get(extension);
	},

	getExtension: function(url) {
		return url.substr(url.lastIndexOf('.') + 1);
	},

	addMimeTypeForExtension: function(extension, mimeType) {
		if (mimeTypes.has(extension) !== undefined) {
			console.warn("the '" + extension + "' already has a mimetype: " + mimeTypes.get(extension));
		}
		mimeTypes.set(extension, mimeType);
	}
};

mimeTypes.set('bin', 'application/octet-binary');
mimeTypes.set('b3dm', 'application/octet-binary');
mimeTypes.set('glb', 'application/octet-binary');
mimeTypes.set('zip', 'application/octet-binary');
mimeTypes.set('gz', 'application/octet-binary');
// Image
mimeTypes.set('png', 'image/png');
mimeTypes.set('jpg', 'image/jpeg');
mimeTypes.set('jpeg', 'image/jpeg');
mimeTypes.set('gif', 'image/gif');
// Text
mimeTypes.set('json', 'application/json');
mimeTypes.set('gltf', 'application/json');
mimeTypes.set('osgjs', 'application/json');
mimeTypes.set('txt', 'text/plain');
mimeTypes.set('glsl', 'text/plain');

export default fileHelper;
