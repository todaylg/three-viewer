varying vec3 vViewNormal;

void main() {
    vViewNormal = normalMatrix * normal;
    gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
}
