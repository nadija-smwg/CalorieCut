import { defineConfig } from 'vite';
import { readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { join, relative } from 'node:path';

export default defineConfig({
  base: './',
  plugins: [{
    name: 'offline-shell',
    apply: 'build',
    closeBundle() {
      const files = [];
      function walk(directory) {
        for (const entry of readdirSync(directory, { withFileTypes: true })) {
          const path = join(directory, entry.name);
          if (entry.isDirectory()) walk(path);
          else if (entry.name !== 'sw.js') files.push(relative('dist', path).replaceAll('\\', '/'));
        }
      }
      walk('dist');
      const version = createHash('sha256');
      version.update(readFileSync('public/sw.js'));
      files.sort().forEach(path => { version.update(path); version.update(readFileSync(join('dist', path))); });
      const worker = readFileSync('public/sw.js', 'utf8').replace('__VERSION__', version.digest('hex').slice(0, 16)).replace('/* __PRECACHE__ */ []', JSON.stringify(files));
      writeFileSync('dist/sw.js', worker);
    }
  }]
});
