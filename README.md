# three-viewer

PBR rendering experiment of a single model, convenient comparison of rendering equations, based on Threejs and [Envtools](https://github.com/todaylg/envTools)

[Online Demo](https://todaylg.github.io/three-viewer/)

![image](https://github.com/todaylg/three-viewer/blob/master/intro/intro.png)

### Feature

- [x] Select rendering equation(shader reload)
  
- [x] Envtools-based IBL (Spherical Harmonics Lighting/Blur Background/Cube Envmap/Sunlight)

- [x] Environment rotation

- [x] Direction/Spot/Point Light and Shadow

- [x] Camera/ShadowCamera Adaptation model

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

- [ ] Anisotropy(GGX)

- [ ] Clearcoat

- [ ] Sheen

- [ ] Specular gloss

- [ ] MorphTarget/Skin Animation

- [ ] Post-processing(SSS、TAA)

- [ ] Ground Shadow

- [ ] Shadow Jitter
