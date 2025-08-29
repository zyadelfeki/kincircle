// Renders assets/icon/kincircle_logo.svg to PNG sizes using sharp
// Requires: npm i sharp
const fs = require('fs');
const path = require('path');
let sharp;
try { sharp = require('sharp'); } catch (e) {
  console.error('Sharp is not installed. Run `npm install` in the repo root.');
  process.exit(1);
}

const SRC = path.resolve(__dirname, '..', 'assets', 'icon', 'kincircle_logo.svg');
const OUTDIR = path.resolve(__dirname, '..', 'assets', 'icon');
const sizes = [1024, 512, 384, 256, 192];

(async () => {
  try {
    if (!fs.existsSync(SRC)) throw new Error(`Source SVG not found: ${SRC}`);
    for (const s of sizes) {
      const outfile = path.join(OUTDIR, `kincircle_logo_${s}.png`);
      await sharp(SRC)
        .resize(s, s, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } })
        .png()
        .toFile(outfile);
      console.log(`Wrote ${outfile}`);
    }
    const flutterOut = path.join(OUTDIR, 'kincircle_icon_1024.png');
    await sharp(SRC)
      .resize(1024, 1024, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } })
      .png()
      .toFile(flutterOut);
    console.log(`Wrote ${flutterOut}`);
    console.log('All PNGs generated.');
  } catch (err) {
    console.error(err);
    process.exit(1);
  }
})();
