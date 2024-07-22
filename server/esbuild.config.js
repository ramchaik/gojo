const esbuild = require('esbuild')

esbuild
  .build({
    entryPoints: ['src/server.ts'],
    bundle: true,
    platform: 'node',
    target: 'node20',
    outdir: 'dist',
    sourcemap: true,
    external: ['@prisma/client'],
  })
  .catch(() => process.exit(1))
