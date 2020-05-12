export default class Signal {
	constructor() {
		this._listeners = [];
		this._lookUp = new Map();
	}

	bind(event, self) {
		this._lookUp.set(event, this._listeners.length);
		let resFun = self ? event.bind(self) : event;
		this._listeners.push(resFun);
	}

	unbind(key) {
		let pos = this._lookUp.get(key);
		// Delete
		this._listeners.splice(pos, 1);
		this._lookUp.delete(key);
	}

	dispatch(key) {
		for (let len = this._listeners.length, i = 0; i < len; i++) this._listeners[i](key);
	}

	get hasListeners() {
		return this._listeners.length > 0;
	}
}
