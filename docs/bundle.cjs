const esbuild = require('esbuild');
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');

async function build() {
  await esbuild.build({
    entryPoints: [path.resolve(root, 'dist/luolita.browser.js')],
    bundle: true,
    outfile: path.resolve(root, 'dist/luolita.browser.bundle.js'),
    format: 'iife',
    globalName: 'LuolitaBundle',
    platform: 'node',
    minify: true,
  });
  console.log('esbuild done');

  let code = fs.readFileSync(path.resolve(root, 'dist/luolita.browser.bundle.js'), 'utf8');

  var shimCode = [
    'var process={env:{},argv:[],execArgv:[],cwd:function(){return"/"},nextTick:function(f){setTimeout(f,0)},browser:!0,version:"browser",versions:{node:"0.0.0"},platform:"browser",stdout:{},stderr:{},stdin:{},umask:function(){return 0},getuid:function(){return 0},getgid:function(){return 0},type:function(){return"Browser"},release:{},throwDeprecation:!1,noDeprecation:!0,traceDeprecation:!1};',
    'if(typeof window!=="undefined"&&!window.process)window.process=process;',
    'if(typeof globalThis!=="undefined"&&!globalThis.process)globalThis.process=process;',
    'var global=typeof globalThis!=="undefined"?globalThis:(typeof window!=="undefined"?window:{});',
  ].join('');
  code = shimCode + code;
  console.log('Injected shims');

  var stubs = {
    'fs': '{readFileSync:function(){throw new Error("fs not available in browser")},readFile:function(a,b){if(b)b(new Error("fs.readFile not available"))},existsSync:function(){return!1},statSync:function(){throw new Error("fs.statSync not available")},readdirSync:function(){return[]},realpathSync:function(a){return a},accessSync:function(){},writeFileSync:function(){},mkdirSync:function(){},unlinkSync:function(){},rmdirSync:function(){},renameSync:function(){}}',
    'vm': '{runInThisContext:function(c){return eval(c)},runInNewContext:function(c){return eval(c)},Script:function(){},createScript:function(){throw new Error("vm not available")}}',
    'os': '{platform:function(){return"browser"},arch:function(){return"x64"},homedir:function(){return""},type:function(){return"Browser"},release:function(){return""},cpus:function(){return[]},freemem:function(){return 0},totalmem:function(){return 0},tmpdir:function(){return"/tmp"},EOL:"\\n"}',
    'assert': 'Object.assign(function(){},{ok:function(){},strictEqual:function(){},deepStrictEqual:function(){},fail:function(){throw new Error("assertion failed")}})',
    'path': '{join:function(){return Array.prototype.join.call(arguments,"/")},resolve:function(){return Array.prototype.join.call(arguments,"/")},dirname:function(p){return p.split("/").slice(0,-1).join("/")||"."},basename:function(p,e){var n=p.split("/").pop();return e&&n.endsWith(e)?n.slice(0,-e.length):n},extname:function(p){var i=p.lastIndexOf(".");return i>0?p.slice(i):""},normalize:function(p){return p},relative:function(){return""},isAbsolute:function(p){return p.startsWith("/")},separator:"/",delimiter:":"}',
    'url': '{parse:function(u){return{pathname:u}},format:function(){return""},resolve:function(){return""}}',
    'crypto': '{createHash:function(){return{update:function(){return this},digest:function(){return""}}},randomBytes:function(n,cb){var b=new Uint8Array(n);if(cb){cb(null,b);return}return b}}',
    'child_process': '{execSync:function(){return""},exec:function(){},spawn:function(){throw new Error("child_process not available")}}',
    'stream': '{Readable:function(){},Writable:function(){},Transform:function(){},Duplex:function(){},PassThrough:function(){},pipeline:function(){},finished:function(){}}',
    'events': '{EventEmitter:function(){this._events={};this.listeners=function(){return[]};this.on=function(){};this.emit=function(){};this.once=function(){};this.off=function(){}}}',
    'util': '{inherits:function(){},inspect:function(o){return JSON.stringify(o)},format:function(){return""},isBuffer:function(){return!1},promisify:function(){}}',
    'tty': '{isatty:function(){return!1},ReadStream:function(){},WriteStream:function(){}}',
    'string_decoder': '{StringDecoder:function(){return{text:""}}}',
    'buffer': '{Buffer:typeof Buffer!=="undefined"?Buffer:function(){return{toString:function(){return""}}}}',
    'module': '{createRequire:function(){throw new Error("module.createRequire not available")}}',
    'pug-runtime': '{}',
    'domain': '{create:function(){return{on:function(){},enter:function(){},exit:function(){},run:function(fn){fn()}}},active:null}',
  };

  var match = code.match(/throw Error\([^)]*Dynamic require[^)]*\)/);
  if (match) {
    var searchStr = match[0];
    var stubObj = '{' + Object.keys(stubs).map(function(m) {
      return '"' + m + '":' + stubs[m];
    }).join(',') + '}';
    var replaceStr = 'var s=' + stubObj + ';if(s[e])return s[e];' + searchStr;
    code = code.split(searchStr).join(replaceStr);
    console.log('Replaced dynamic require interceptor');
  } else {
    console.warn('Dynamic require pattern NOT found!');
  }

  for (var mod in stubs) {
    var stub = stubs[mod];
    var patterns = [
      'zt("' + mod + '")',
      "zt('" + mod + "')",
      'require("' + mod + '")',
      "require('" + mod + "')",
      'nt("' + mod + '")',
      "nt('" + mod + "')",
    ];
    for (var i = 0; i < patterns.length; i++) {
      var count = code.split(patterns[i]).length - 1;
      if (count > 0) {
        code = code.split(patterns[i]).join(stub);
        console.log('  Replaced "' + patterns[i] + '" x' + count);
      }
    }
  }

  fs.writeFileSync(path.resolve(root, 'dist/luolita.browser.bundle.js'), code);

  const final = fs.readFileSync(path.resolve(root, 'dist/luolita.browser.bundle.js'), 'utf8');
  const size = (Buffer.byteLength(final) / 1024).toFixed(1);
  console.log('Bundle size:', size, 'KB');

  fs.copyFileSync(path.resolve(root, 'dist/luolita.browser.bundle.js'), path.resolve(root, 'docs/luolita.browser.bundle.js'));
  console.log('Copied to docs/');
}

build().catch(err => {
  console.error(err);
  process.exit(1);
});
