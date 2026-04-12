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
  // Note: no require() calls inside the stub to avoid new external deps
  const fsStub = '{readFileSync:function(){throw new Error("fs not available in browser")},readFile:function(){throw new Error("fs.readFile not available")},existsSync:function(){return!1},statSync:function(){throw new Error("fs.statSync not available")},stat:function(a,b){b&&b(new Error("fs.stat not available"))},readdirSync:function(){return[]},readdir:function(a,b){b&&b(null,[])},realpathSync:function(a){return a},accessSync:function(){},lstatSync:function(){throw new Error("fs.lstatSync not available")},readlinkSync:function(){throw new Error("fs.readlinkSync not available")},writeFileSync:function(){},writeFile:function(a,b,c){c&&c()},mkdirSync:function(){},mkdir:function(a,b){b&&b()},unlinkSync:function(){},unlink:function(a,b){b&&b()},rmdirSync:function(){},rmdir:function(a,b){b&&b()},renameSync:function(){},rename:function(a,b,c){c&&c()},truncateSync:function(){},truncate:function(a,b){b&&b()},chmodSync:function(){},chmod:function(a,b,c){c&&c()},openSync:function(){return-1},open:function(a,b,c){c&&c(null,-1)},closeSync:function(){},close:function(a,b){b&&b()},createReadStream:function(){},createWriteStream:function(){},constants:{O_RDONLY:0,O_WRONLY:1,O_RDWR:2,O_CREAT:64,O_TRUNC:512,O_APPEND:1024,O_EXCL:128},F_OK:0,R_OK:4,W_OK:2,X_OK:1}';

  // Stub pug-runtime
  const pugRuntimeStub = '{}';

  // Replace require calls in the bundle
  // esbuild minified output uses require("fs") or require('fs')
  code = code.replace(/require\("fs"\)/g, fsStub);
  code = code.replace(/require\('fs'\)/g, fsStub);
  code = code.replace(/require\("pug-runtime"\)/g, pugRuntimeStub);
  code = code.replace(/require\('pug-runtime'\)/g, pugRuntimeStub);

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
