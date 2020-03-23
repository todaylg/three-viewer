varying vec3 vViewNormal;

void main() {
    vViewNormal = position;
    vec4 pos = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
    pos.z = 1.;
    gl_Position = pos;
}
