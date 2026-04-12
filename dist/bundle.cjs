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
  const fsStub = '{readFileSync:function(){throw new Error("fs not available in browser")},readFile:function(){throw new Error("fs.readFile not available")},existsSync:function(){return!1},statSync:function(){throw new Error("fs.statSync not available")},stat:function(a,b){b&&b(new Error("fs.stat not available"))},readdirSync:function(){return[]},readdir:function(a,b){b&&b(null,[])},realpathSync:function(a){return a},accessSync:function(){},lstatSync:function(){throw new Error("fs.lstatSync not available")},readlinkSync:function(){throw new Error("fs.readlinkSync not available")},writeFileSync:function(){},writeFile:function(a,b,c){c&&c()},mkdirSync:function(){},mkdir:function(a,b){b&&b()},unlinkSync:function(){},unlink:function(a,b){b&&b()},rmdirSync:function(){},rmdir:function(a,b){b&&b()},renameSync:function(){},rename:function(a,b,c){c&&c()},truncateSync:function(){},truncate:function(a,b){b&&b()},chmodSync:function(){},chmod:function(a,b,c){c&&c()},openSync:function(){return-1},open:function(a,b,c){c&&c(null,-1)},closeSync:function(){},close:function(a,b){b&&b()},createReadStream:function(){},createWriteStream:function(){},constants:{O_RDONLY:0,O_WRONLY:1,O_RDWR:2,O_CREAT:64,O_TRUNC:512,O_APPEND:1024,O_EXCL:128},F_OK:0,R_OK:4,W_OK:2,X_OK:1}';

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
    'assert': '{ok:function(){},strictEqual:function(){},deepStrictEqual:function(){},fail:function(){throw new Error("assertion failed")}}',
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
  };

  // Replace all nt("module") and require("module") calls with stubs
  for (var mod in stubs) {
    var stub = stubs[mod];
    var re1 = new RegExp('nt\\("' + mod + '"\\)', 'g');
    var re2 = new RegExp("nt\\('" + mod + "'\\)", 'g');
    var re3 = new RegExp('require\\("' + mod + '"\\)', 'g');
    var re4 = new RegExp("require\\('" + mod + "'\\)", 'g');
    code = code.replace(re1, stub);
    code = code.replace(re2, stub);
    code = code.replace(re3, stub);
    code = code.replace(re4, stub);
  }

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
