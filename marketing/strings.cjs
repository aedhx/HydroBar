// Chaînes de l'app, lues dans le catalogue Localizable.xcstrings : les
// visuels affichent exactement les textes que l'app affiche.
const fs = require('fs');
const path = require('path');

const catalog = JSON.parse(fs.readFileSync(
  path.join(__dirname, '../src/HydroBar/HydroBar/Localizable.xcstrings'), 'utf8')).strings;

// Langue de la fiche App Store → langue de l'app, locale Intl, unité.
const LOCALES = {
  'en-US':   { app: 'en',      intl: 'en-US', unit: 'oz' },
  'fr-FR':   { app: 'fr',      intl: 'fr-FR', unit: 'cl' },
  'de-DE':   { app: 'de',      intl: 'de-DE', unit: 'cl' },
  'es-ES':   { app: 'es',      intl: 'es-ES', unit: 'cl' },
  'it':      { app: 'it',      intl: 'it-IT', unit: 'cl' },
  'ja':      { app: 'ja',      intl: 'ja-JP', unit: 'ml' },
  'nl-NL':   { app: 'nl',      intl: 'nl-NL', unit: 'cl' },
  'pt-BR':   { app: 'pt',      intl: 'pt-BR', unit: 'cl' },
  'zh-Hans': { app: 'zh-Hans', intl: 'zh-CN', unit: 'ml' },
};

/** Remplace %@, %lld, %1$@… comme String(format:). */
function format(template, args) {
  let next = 0;
  return template
    .replace(/%(\d+)\$(@|lld|d)/g, (_, n, __) => String(args[Number(n) - 1]))
    .replace(/%(@|lld|d)/g, () => String(args[next++]))
    .replace(/%%/g, '%');
}

function translator(locale) {
  const lang = LOCALES[locale].app;
  return (key, ...args) => {
    const entry = catalog[key];
    if (!entry && lang !== 'en') throw new Error(`Chaîne absente du catalogue : ${key}`);
    const unit = entry?.localizations?.[lang]?.stringUnit?.value
      ?? entry?.localizations?.en?.stringUnit?.value
      ?? key;
    return format(unit, args);
  };
}

// Mêmes règles que AppUnit.format : décimales selon l'unité, séparateur de la locale.
const ML_PER = { ml: 1, cl: 10, L: 1000, oz: 29.5735295625 };
function amount(locale, ml, unit = LOCALES[locale].unit) {
  const value = ml / ML_PER[unit];
  const digits = unit === 'ml' ? 0 : unit === 'L' ? (value < 1 ? 2 : 1) : 1;
  const text = new Intl.NumberFormat(LOCALES[locale].intl, { maximumFractionDigits: digits }).format(value);
  return `${text} ${unit}`;
}

module.exports = { LOCALES, translator, amount, ML_PER };
