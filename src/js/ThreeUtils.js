import * as THREE from 'three';

function adjustCameraByBox(camera, object, controls, factor = 1.){
	let box = new THREE.Box3().setFromObject(object);
	let size = box.getSize(new THREE.Vector3());
	const maxSize = Math.max( size.x, size.y, size.z );
	const fitHeightDistance = maxSize / ( 2 * Math.atan( Math.PI * camera.fov / 360 ) );
	const fitWidthDistance = fitHeightDistance / camera.aspect;
	const distance = factor * Math.max( fitHeightDistance, fitWidthDistance );

	camera.near = distance / 100;
	camera.far = distance * 100;
	camera.position.set(0, distance/4, distance);
	camera.updateProjectionMatrix();
	if(controls){
		controls.maxDistance = distance * 20;
		controls.update();
	}
	return distance;
}

function adjustSunLightByBox(light, scene, object, debug){
	let box = new THREE.Box3().setFromObject(object);
	light.shadow.mapSize.width = 1024;
	light.shadow.mapSize.height = 1024;
	// Shadow Camera
	let lightCamera = light.shadow.camera;
	lightCamera.position.copy(light.position);
	// Trasnlate => Rotation
	lightCamera.lookAt(new THREE.Vector3(0, 0, 0));
	lightCamera.position.set(0, 0, 0);
	lightCamera.updateMatrixWorld(true);

	// Box(near\far\top...boundingBox) from world space to lightCamera view space
	let cameraInverseMatrix = new THREE.Matrix4();
	cameraInverseMatrix.getInverse(lightCamera.matrixWorld);
	box.applyMatrix4(cameraInverseMatrix);

	lightCamera.left = box.min.x - 0.01;
	lightCamera.right = box.max.x + 0.01;
	lightCamera.top = box.min.y - 0.01;
	lightCamera.bottom = box.max.y + 0.01;
	lightCamera.near = -box.max.z - 0.01;
	lightCamera.far = -box.min.z + 0.01;
	lightCamera.updateProjectionMatrix();
	// Todo: Dynamic compute
	light.shadow.bias = -0.01;

	// Helper
	if(debug){
		let helper = new THREE.DirectionalLightHelper( light, 5, 0xffffff );
		scene.add( helper );
		let helper1 = new THREE.CameraHelper( lightCamera );
		scene.add( helper1 );
	}
}

export { adjustCameraByBox, adjustSunLightByBox };
