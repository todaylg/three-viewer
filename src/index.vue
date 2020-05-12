<template>
	<div id="wrapper" class="isLoading">
		<div id="canvasContainer"></div>
		<p class="loadingText">Loading...</p>
		<main class="dropWrap" v-show="openImportPage">
			<div class="dropzone">
				<div class="innerArea">
					<div class="placeholder">
						<p>Please drag the glTF file or folder (zip supported) to this page</p>
					</div>
					<div class="btnArea">
						<div class="uploadBtn">
							<input type="file" name="file-input[]" id="file-input" multiple />
							<label for="file-input">
								<svg xmlns="http://www.w3.org/2000/svg" width="20" height="17" viewBox="0 0 20 17">
									<path
										d="M10 0l-5.2 4.9h3.3v5.1h3.8v-5.1h3.3l-5.2-4.9zm9.3 11.5l-3.2-2.1h-2l3.4 2.6h-3.5c-.1 0-.2.1-.2.1l-.8 2.3h-6l-.8-2.2c-.1-.1-.1-.2-.2-.2h-3.6l3.4-2.6h-2l-3.2 2.1c-.4.3-.7 1-.6 1.5l.6 3.1c.1.5.7.9 1.2.9h16.3c.6 0 1.1-.4 1.3-.9l.6-3.1c.1-.5-.2-1.2-.7-1.5z"
									/>
								</svg>
								<span>Upload</span>
							</label>
						</div>
						<div class="uploadBtn" @click='loadDefaultModel'>
							<span>Defalut(3.5MB)</span>
						</div>
					</div>
				</div>
			</div>
		</main>
	</div>
</template>

<script>
import MainScene from './MainScene';
import Loader from './js/Loader';
import { SimpleDropzone } from 'simple-dropzone';
export default {
	name: 'container',
	data() {
		return {
			openImportPage: true
		};
	},
	mounted() {
		this.initEvent();
		// Dev
		// document.querySelector("#wrapper").classList.remove("isLoading");
		// this.loadDefaultModel();
	},
	methods: {
		initScene(gltf) {
			let containerEle = document.querySelector('#canvasContainer');
			this.scene = new MainScene(containerEle, gltf, () => {
				document.querySelector("#wrapper").classList.remove("isLoading");
			});
		},
		initEvent() {
			let _this = this;
			let loader = new Loader();
			let inputEle = document.body.querySelector('#file-input');
			let dropEl = document.body.querySelector('.dropzone');
			const dropCtrl = new SimpleDropzone(dropEl, inputEle);
			dropCtrl.on('drop', ({ files }) =>
				loader.importGLTF(files).then(gltf => {
					this.initScene(gltf);
					_this.openImportPage = false;
				})
			);
		},
		loadDefaultModel(){
			let loader = new Loader();
			this.openImportPage = false;
			loader.loadGLTF('./assets/models/damagedHelmet/').then(gltf => {
				this.initScene(gltf);
			})
		}
	}
};
</script>

<style lang="less">
html,
body {
	margin: 0;
	padding: 0;
	box-sizing: border-box;
	background: #000;
}

*{
    -webkit-touch-callout:none;
    -webkit-user-select:none;
    -khtml-user-select:none;
    -moz-user-select:none;
    -ms-user-select:none;
    user-select:none;
}

#wrapper {
	font-family: 'Avenir', Helvetica, Arial, sans-serif;
	-webkit-font-smoothing: antialiased;
	-moz-osx-font-smoothing: grayscale;
}

#wrapper {
	width: 100vw;
	height: 100vh;
	position: relative;
	overflow: hidden;
}

#canvasContainer {
	width: 100%;
	height: 100%;
}

.loadingText {
    position: absolute;
    z-index: 1;
    width: 100%;
    top: calc(50% - 50px);
    text-align: center;
    letter-spacing: 11px;
    color: #fff;
    opacity: 0;
    transition: opacity .5s ease-out, letter-spacing .5s ease-out;
    pointer-events: none;
}

.isLoading .loadingText {
    letter-spacing: 10px;
    opacity: 1;
}

.dropWrap {
	position: absolute;
	top: 0;
	left: 0;
	right: 0;
	bottom: 0;
	z-index: 1;
	background: #ffffff;

	.dropzone {
		position: absolute;
		top: 5%;
		left: 5%;
		right: 5%;
		bottom: 5%;
		border: 3px dashed #e6e6e6;
		color: #cccccc;
		text-align: center;
	}
	.innerArea{
		width: 100%;
		height: 100%;
		display: flex;
		flex-grow: 1;
		flex-direction: column;
		justify-content: center;
		align-items: center;
	}

	.placeholder{
		font-size: 22px;
	}

	/* Upload Button */
	.uploadBtn {
		display: inline-block;
		font-size: 18px;
		background: #00b7ee;
		border-radius: 3px;
		line-height: 44px;
		padding: 0 30px;
		color: #fff;
		margin: 20px;
		cursor: pointer;
		box-shadow: 0 1px 1px rgba(0, 0, 0, 0.1);
		&:hover{
			background: #3bc8f2;
		}
	}

	.uploadBtn label{
		cursor: pointer;
	}

	.uploadBtn input {
		width: 0.1px;
		height: 0.1px;
		opacity: 0;
		overflow: hidden;
		position: absolute;
		z-index: -1;
	}

	.uploadBtn svg {
		width: 1em;
		height: 1em;
		vertical-align: middle;
		fill: currentColor;
		margin-top: -0.25em;
		margin-right: 0.25em;
	}
}
</style>
