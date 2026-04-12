const esbuild = require('esbuild');

esbuild.build({
  entryPoints: ['dist/luolita.browser.js'],
  bundle: true,
  outfile: 'dist/luolita.browser.bundle.js',
  format: 'iife',
  globalName: 'LuolitaBundle',
  platform: 'node',
  minify: true,
}).then(() => {
  const fs = require('fs');
  let code = fs.readFileSync('dist/luolita.browser.bundle.js', 'utf8');

  // Stub fs: replace require("fs") with an inline stub object
  // Read actual stylus library files and embed as base64 to avoid escaping issues
  const stylusLibDir = require('path').resolve(__dirname, '..', 'node_modules', '.pnpm', 'stylus@0.63.0', 'node_modules', 'stylus', 'lib');
  const stylusFuncsPath = require('path').join(stylusLibDir, 'functions', 'index.styl');
  let stylusFuncsB64 = '';
  try {
    const content = fs.readFileSync(stylusFuncsPath, 'utf-8');
    stylusFuncsB64 = Buffer.from(content).toString('base64');
  } catch(e) {
    console.warn('Warning: could not read stylus functions file');
  }

  const fsStub = '{readFileSync:function(p){if(/functions[\\\\/]index\\.styl$/.test(p))return atob("'+stylusFuncsB64+'");return""},readFile:function(){throw new Error("fs.readFile not available")},existsSync:function(){return!1},statSync:function(){throw new Error("fs.statSync not available")},stat:function(a,b){b&&b(new Error("fs.stat not available"))},readdirSync:function(){return[]},readdir:function(a,b){b&&b(null,[])},realpathSync:function(a){return a},accessSync:function(){},lstatSync:function(){throw new Error("fs.lstatSync not available")},readlinkSync:function(){throw new Error("fs.readlinkSync not available")},writeFileSync:function(){},writeFile:function(a,b,c){c&&c()},mkdirSync:function(){},mkdir:function(a,b){b&&b()},unlinkSync:function(){},unlink:function(a,b){b&&b()},rmdirSync:function(){},rmdir:function(a,b){b&&b()},renameSync:function(){},rename:function(a,b,c){c&&c()},truncateSync:function(){},truncate:function(a,b){b&&b()},chmodSync:function(){},chmod:function(a,b,c){c&&c()},openSync:function(){return-1},open:function(a,b,c){c&&c(null,-1)},closeSync:function(){},close:function(a,b){b&&b()},createReadStream:function(){},createWriteStream:function(){},constants:{O_RDONLY:0,O_WRONLY:1,O_RDWR:2,O_CREAT:64,O_TRUNC:512,O_APPEND:1024,O_EXCL:128},F_OK:0,R_OK:4,W_OK:2,X_OK:1}';

  // Stub pug-runtime
  const pugRuntimeStub = '{}';

  // Stub all Node.js built-in modules that CoffeeScript/pug/stylus try to load
  // CoffeeScript needs vm for eval, pug needs assert, stylus needs many others
  const vmStub = '{runInThisContext:function(c,o){return eval(c)},runInNewContext:function(c){return eval(c)},Script:function(){},createScript:function(){throw new Error("vm not available")}}';
  const osStub = '{platform:function(){return"browser"},arch:function(){return"x64"},homedir:function(){return""},type:function(){return"Browser"},release:function(){return""},cpus:function(){return[]},freemem:function(){return 0},totalmem:function(){return 0},tmpdir:function(){return"/tmp"},EOL:"\\n"}';
  const stubs = {
    'fs': fsStub,
    'vm': vmStub,
    'os': osStub,
    'assert': 'function(){if(!arguments[0])throw new Error("assertion failed"+(arguments[1]?": "+arguments[1]:""))}',
    'path': '{join:function(){return Array.prototype.join.call(arguments,"/")},resolve:function(){return Array.prototype.join.call(arguments,"/")},dirname:function(p){return p.split("/").slice(0,-1).join("/")||"."},basename:function(p,e){var n=p.split("/").pop();return e&&n.endsWith(e)?n.slice(0,-e.length):n},extname:function(p){var i=p.lastIndexOf(".");return i>0?p.slice(i):""},normalize:function(p){return p},relative:function(){return""},isAbsolute:function(p){return p.startsWith("/")},separator:"/",delimiter:":"}',
    'url': '{parse:function(u){return{pathname:u}},format:function(){return""},resolve:function(){return""}}',
    'crypto': '{createHash:function(){return{update:function(){return this},digest:function(){return""}}},randomBytes:function(n,cb){var b=new Uint8Array(n);if(cb){cb(null,b);return}return b},createCipheriv:function(){throw new Error("crypto not available")},createDecipheriv:function(){throw new Error("crypto not available")}}',
    'child_process': '{execSync:function(){return""},exec:function(){},spawn:function(){throw new Error("child_process not available")},spawnSync:function(){return{status:0,output:[]}}}',
    'stream': '{Readable:function(){},Writable:function(){},Transform:function(){},Duplex:function(){},PassThrough:function(){},pipeline:function(){},finished:function(){}}',
    'events': '{EventEmitter:function(){this._events={};this.listeners=function(){return[]};this.on=function(){};this.emit=function(){};this.once=function(){};this.off=function(){}}}',
    'util': '{inherits:function(){},inspect:function(o){return JSON.stringify(o)},format:function(){return""},isBuffer:function(){return!1},promisify:function(){}}',
    'tty': '{isatty:function(){return!1},ReadStream:function(){},WriteStream:function(){}}',
    'string_decoder': '{StringDecoder:function(){return{text:""}}}',
    'buffer': '{Buffer:typeof Buffer!=="undefined"?Buffer:function(){return{toString:function(){return""}}}}',
    'module': '{createRequire:function(){throw new Error("module.createRequire not available")}}',
    'pug-runtime': pugRuntimeStub,
    'domain': '{create:function(){return{on:function(){},enter:function(){},exit:function(){},run:function(fn){fn()}}},active:null}',
    'babel-core': '{}',
    '@babel/core': '{}',
    'supports-color': '{level:0,hasBasic:false,has256:false,has16m:false,stdout:{isTTY:!1},stderr:{isTTY:!1}}',
  };

  // Detect the minified require function name from the IIFE body
  // esbuild uses patterns like: var ot=(r=>typeof require<"u"?require:...)
  // The parameter name may vary (r, t, e, etc.)
  const requireFnMatch = code.match(/var\s+([a-zA-Z_$][a-zA-Z0-9_$]*)=\([a-zA-Z_$]=>typeof require<"u"\?require/);
  const requireFn = requireFnMatch ? requireFnMatch[1] : null;
  console.log('Minified require function name:', requireFn);

  // Replace all require calls with stubs
  for (var mod in stubs) {
    var stub = stubs[mod];
    // Replace the minified require function calls: ot("module")
    if (requireFn) {
      code = code.replace(new RegExp(requireFn.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '\\("' + mod + '"\\)', 'g'), stub);
      code = code.replace(new RegExp(requireFn.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + "\\('" + mod + "'\\)", 'g'), stub);
    }
    // Also catch raw require calls
    var re3 = new RegExp('require\\("' + mod + '"\\)', 'g');
    var re4 = new RegExp("require\\('" + mod + "'\\)", 'g');
    code = code.replace(re3, stub);
    code = code.replace(re4, stub);
  }

  fs.writeFileSync('dist/luolita.browser.bundle.js', code);

  // Inject process and global shims at the top of the IIFE
  const processStub = 'var __dirname="/",__filename="/index.js",process={env:{},argv:[],execArgv:[],cwd:function(){return"/"},nextTick:function(f){setTimeout(f,0)},browser:!0,version:"browser",versions:{node:"0.0.0",v8:"0.0",uv:"0",zlib:"0"},platform:"browser",stdout:{},stderr:{},stdin:{},umask:function(){return 0},getuid:function(){return 0},getgid:function(){return 0},type:function(){return"Browser"},release:{},domain:null,throwDeprecation:!1,noDeprecation:!0,traceDeprecation:!1,__nwjs:!1};if(typeof window!=="undefined"&&!window.process)window.process=process;if(typeof globalThis!=="undefined"&&!globalThis.process)globalThis.process=process;var global=typeof globalThis!=="undefined"?globalThis:window;';

  // Find the opening of the IIFE body and inject after it
  // The bundle starts with: var LuolitaBundle=(()=>{
  code = code.replace(/var LuolitaBundle=\(\(\)=>\{/,'var LuolitaBundle=(()=>{' + processStub);

  fs.writeFileSync('dist/luolita.browser.bundle.js', code);

  // Verify
  const final = fs.readFileSync('dist/luolita.browser.bundle.js', 'utf8');
  const m = final.match(/require\(['"]([^'"]+)['"]\)/g) || [];
  const uniq = [...new Set(m)];
  console.log('External requires after stub:', uniq.length ? uniq.join(', ') : 'none');

  const size = (Buffer.byteLength(final) / 1024).toFixed(1);
  console.log('Bundle size: ' + size + ' KB');
}).catch((e) => {
  console.error(e);
  process.exit(1);
});
