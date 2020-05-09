const path = require('path');

module.exports = {
	publicPath: '/three-viewer',
	chainWebpack: config => {
		config.module
			.rule('raw')
			.test(/\.(glsl|fs|vs|frag|vert)$/)
			.use('raw-loader')
			.loader('raw-loader')
			.end();
		config.module
			.rule('hdr')
			.test(/\.hdr$/)
			.use('url-loader')
			.loader('url-loader')
			.end();
	},
	configureWebpack: config => {
		config.resolve = {
			extensions: [
				'.glsl',
				'.fs',
				'.vs',
				'.js',
				'.vue',
				'.css',
				'.png',
				'.jpg',
				'.jpeg',
				'.hdr',
			],
			alias: {
				'@': path.resolve(__dirname, './src'),
				JS: path.resolve(__dirname, './src/js'),
				LIB: path.resolve(__dirname, './src/libs'),
				MODULES: path.resolve(__dirname, './src/modules'),
			}
		};
	}
};
