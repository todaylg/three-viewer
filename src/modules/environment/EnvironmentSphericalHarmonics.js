export default class EnvironmentSphericalHarmonics {
	constructor(file) {
		this._file = file;
		this.initSHCoef(file);
	}

	initSHCoef(sphCoef) {
		// use spherical harmonics with 9 coef
		this._sphCoef = sphCoef.slice(0, 9 * 3);

		let coef0 = 1.0 / (2.0 * Math.sqrt(Math.PI));
		let coef1 = -(Math.sqrt(3.0 / Math.PI) * 0.5);
		let coef2 = -coef1;
		let coef3 = coef1;
		let coef4 = Math.sqrt(15.0 / Math.PI) * 0.5;
		let coef5 = -coef4;
		let coef6 = Math.sqrt(5.0 / Math.PI) * 0.25;
		let coef7 = coef5;
		let coef8 = Math.sqrt(15.0 / Math.PI) * 0.25;

		let coef = [
			coef0,
			coef0,
			coef0,
			coef1,
			coef1,
			coef1,
			coef2,
			coef2,
			coef2,
			coef3,
			coef3,
			coef3,
			coef4,
			coef4,
			coef4,
			coef5,
			coef5,
			coef5,
			coef6,
			coef6,
			coef6,
			coef7,
			coef7,
			coef7,
			coef8,
			coef8,
			coef8
		];
		
		this._sphCoef = coef.map((value, index) => {
			return value * this._sphCoef[index];
		});
		this._uniformSpherical = new Float32Array(3 * 9);
		for (let i = 0; i < 9; i++) {
			this._uniformSpherical[i * 3] = this._sphCoef[i * 3];
			this._uniformSpherical[i * 3 + 1] = this._sphCoef[i * 3 + 1];
			this._uniformSpherical[i * 3 + 2] = this._sphCoef[i * 3 + 2];
		}
	}
}
