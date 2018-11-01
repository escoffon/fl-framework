// Canonical path provides a consistent path (i.e. always forward slashes) across different OSes
var path = require('canonical-path');
var Package = require('dgeni').Package;

const STATE_ROOT = 'docs';
const URL_ROOT = '/docs';
const ENABLE_HTML5_MODE = 'no';
const DEFAULT_PATH = '/api/index';
const BRAND = 'Fl Framework';
const TITLE = 'Fl Framework Documentation';

module.exports = new Package('fl_framework_docs', [
    require('fl-dgeni/ngdoc')
])

// control debug dumps
    .config(function(templateEngine) {
	templateEngine.config.globals.debugDump = false;
    })

// use relative links
// this is probably not needed because the documentation uses the @sref inline tag instead
    .config(function(getLinkInfo) {
	getLinkInfo.relativeLinks = true;
    })

// register external links (links to home pages for external packages)
    .config(function(externalLinks) {
	const XLINKS = [
	    //		    { name: '', xlink: '' },

	    { name: 'Axios', xlink: 'https://github.com/axios/axios' },
	];

	externalLinks.register(XLINKS);
    })

// sources, output location
    .config(function(log, readFilesProcessor, writeFilesProcessor) {
	log.level = 'info';

	readFilesProcessor.basePath = path.resolve(__dirname, '../..');
	readFilesProcessor.sourceFiles = [
	    { include: 'app/assets/javascripts/fl/framework/*.js', basePath: 'app/assets/javascripts' },

	    { include: 'doc/dgeni/content/**/*.md', 
	      basePath: 'doc/dgeni/content', fileReader: 'ngdocFileReader' }
	];

	writeFilesProcessor.outputFolder  = 'public/doc/fl/framework/js';
    })

// index page configuration
    .config(function(indexPageProcessor) {
	indexPageProcessor.brand = BRAND;
	indexPageProcessor.navbar = [
	    { id: 'content.api.main', label: 'API Reference' },
	    { id: 'content.guide.main', label: 'Guide' }
	];
    })

// app roots and configuration
    .config(function(appModuleScriptProcessor, computeAngularStateProcessor, templateEngine) {
	computeAngularStateProcessor.state_root = STATE_ROOT;

	templateEngine.config.globals.state_root = STATE_ROOT;
	templateEngine.config.globals.url_root = URL_ROOT;
	templateEngine.config.globals.enable_html5_mode = ENABLE_HTML5_MODE;
	templateEngine.config.globals.default_path = DEFAULT_PATH;
	templateEngine.config.globals.brand = BRAND;
	templateEngine.config.globals.title = TITLE;
})

;
