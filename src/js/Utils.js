function getEleWidth(element) {
	let res;
	if (element.currentStyle) {
		res = element.currentStyle.width; // For IE
	} else {
		res = getComputedStyle(element, false).width;
	}
	// Get number
	if (~res.indexOf('px')) res = res.slice(0, -2);
	return res;
}

function getEleHeight(element) {
	let res;
	if (element.currentStyle) {
		res = element.currentStyle.height;
	} else {
		res = getComputedStyle(element, false).height;
	}
	if (~res.indexOf('px')) res = res.slice(0, -2);
	return res;
}

function isMobile() {
	let e = /AppleWebKit/.test(navigator.userAgent) && /Mobile\/\w+/.test(navigator.userAgent);
	return e || /Android|webOS|BlackBerry|Opera Mini|Opera Mobi|IEMobile/i.test(navigator.userAgent);
}

export { getEleWidth, getEleHeight, isMobile };
