import { createServer } from 'node:http';
import { readdir, readFile } from 'node:fs/promises';
import { resolve, join, relative } from 'node:path';

export async function staticSite(basePath = '/CalorieCut/') {
  const directory = resolve('dist'), files = new Map();
  async function walk(path) {
    for (const item of await readdir(path, { withFileTypes: true })) {
      const file = join(path, item.name);
      if (item.isDirectory()) await walk(file);
      else files.set(relative(directory, file).replaceAll('\\', '/'), await readFile(file));
    }
  }
  await walk(directory);
  let version = 1, connected = true;
  const types = { html: 'text/html', js: 'text/javascript', css: 'text/css', svg: 'image/svg+xml', png: 'image/png', webmanifest: 'application/manifest+json' };
  const server = createServer((request, response) => {
    if (!connected) { request.socket.destroy(); return; }
    let path = new URL(request.url, 'http://localhost').pathname;
    if (!path.startsWith(basePath)) { response.writeHead(404).end(); return; }
    path = path.slice(basePath.length) || 'index.html';
    if (!files.has(path)) { response.writeHead(404).end(); return; }
    let body = files.get(path);
    if (path === 'index.html') body = Buffer.from(body.toString().replace('</head>', `<meta name="site-version" content="${version}"></head>`));
    if (path === 'sw.js') body = Buffer.from(body.toString().replace(/const CACHE = .+;/, `const CACHE = PREFIX + 'update-test-v${version}';`));
    response.writeHead(200, { 'Content-Type': types[path.split('.').at(-1)] || 'application/octet-stream', 'Cache-Control': 'no-store' });
    response.end(body);
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  return { url: `http://127.0.0.1:${server.address().port}${basePath}`, upgrade: () => version++, disconnect: () => { connected = false; server.closeAllConnections(); }, close: () => { server.closeAllConnections(); return new Promise(resolve => server.close(resolve)); } };
}
