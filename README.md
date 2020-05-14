# three-viewer

PBR rendering experiment of a single model, convenient comparison of rendering equations, based on Threejs and [Envtools](https://github.com/todaylg/envTools)

[Online Demo](https://todaylg.github.io/three-viewer/)

![image](https://github.com/todaylg/three-viewer/blob/master/intro/zelda.png)

![image](https://github.com/todaylg/three-viewer/blob/master/intro/abyss.png)

### Feature

- [x] Select rendering equation(reload shader)
  
- [x] Envtools-based IBL (Spherical Harmonics Lighting/Blur Background/Cube Envmap/Sunlight)

- [x] Environment Rotation

- [x] Direction light And shadow

- [x] Camera/ShadowCamera Adaptation Model

## Usage

1. Install the necessary node modules.

```
npm i
```

2. Run the npm script `dev` to start development.

```
npm run dev
```

3. When finishing development, run the npm script `build` to make the compressed files.

```
npm run build
```

### Source

* [OSG.js](https://github.com/cedricpinson/osgjs)
* [Filament](https://google.github.io/filament/Filament.html)
* UE4

### Todo

- [x] Specular Glossiness Material

- [x] Panorama EnvMap(For the devices that dont support lod)

- [x] Fix energy loss in specular reflectance
  
- [x] Anisotropy(GGX)
  
- [x] Clearcoat

- [ ] Sheen

- [ ] Spot/Point Light and Shadow

- [ ] Post-processing(WIP)

- [ ] Ground Shadow

- [ ] Shadow Jitter
