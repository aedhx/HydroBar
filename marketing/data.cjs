// Contenu de chaque écran, dans une langue : textes de l'app (catalogue),
// quantités formatées comme dans l'app, dates et heures de la locale.
const { LOCALES, translator, amount } = require('./strings.cjs');
const captions = require('./captions.json');

const SCREENS = ['today', 'notification', 'days', 'stats', 'bottle', 'everywhere'];

// « Options » est un libellé système des notifications macOS, absent du
// catalogue de l'app.
const OPTIONS = {
  'en-US': 'Options', 'fr-FR': 'Options', 'de-DE': 'Optionen', 'es-ES': 'Opciones', it: 'Opzioni',
  ja: 'オプション', 'nl-NL': 'Opties', 'pt-BR': 'Opções', 'zh-Hans': '选项',
};
// Durée « 1 h 30 min », comme DateComponentsFormatter en style court.
const NINETY_MINUTES = {
  'en-US': '1 hr, 30 min', 'fr-FR': '1 h 30 min', 'de-DE': '1 Std., 30 Min.', 'es-ES': '1 h y 30 min',
  it: '1 h e 30 min', ja: '1時間30分', 'nl-NL': '1 uur, 30 min.', 'pt-BR': '1 h e 30 min', 'zh-Hans': '1小时30分钟',
};

// Quantités de démonstration. En onces, des valeurs rondes : 8, 16 et 24 oz.
function sample(locale) {
  const oz = LOCALES[locale].unit === 'oz';
  const o = 29.5735295625;
  return oz
    ? { presets: [8 * o, 16 * o, 24 * o], target: 64 * o, current: 44 * o, offGoal: 48 * o, bottle: 24 * o }
    : { presets: [200, 500, 750], target: 2000, current: 1375, offGoal: 1500, bottle: 750 };
}

function build(locale, screen) {
  const t = translator(locale);
  const intl = LOCALES[locale].intl;
  const fmt = (ml) => amount(locale, ml);
  const s = sample(locale);
  const at = (h, m = 0) => new Date(2026, 9, 13, h, m); // mardi 13 octobre 2026
  const time = (d) => new Intl.DateTimeFormat(intl, { hour: 'numeric', minute: '2-digit' }).format(d);
  const pct = Math.floor((s.current / s.target) * 100);

  const common = {
    locale, screen, lang: LOCALES[locale].app,
    caption: captions[locale][screen],
    clock: new Intl.DateTimeFormat(intl, { weekday: 'short', hour: 'numeric', minute: '2-digit' }).format(at(15, 20)),
    popover: {
      title: t('Today'),
      statsTitle: t('Statistics'),
      percent: `${pct}%`,
      progress: s.current / s.target,
      pace: (15 + 20 / 60 - 8) / 14,
      amounts: `${fmt(s.current)} / ${fmt(s.target)}`,
      paceCaption: t('On track'),
      chip: `${t('Work Day')} · ${time(at(8))}–${time(at(22))}`,
      presets: s.presets.map(fmt),
      hold: t('Hold to Add'),
      log: t("Today's log (%lld)", 6),
      reset: t('Reset my day'),
    },
  };

  switch (screen) {
    case 'notification': {
      const current = s.target * 0.625;
      return { ...common, notification: {
        app: 'HydroBar',
        title: 'HydroBar',
        body: t('%@ of %@ · %@ to go by %@.', fmt(current), fmt(s.target), fmt(s.target - current), time(at(22))),
        when: new Intl.RelativeTimeFormat(intl, { numeric: 'auto' }).format(0, 'second'),
        options: OPTIONS[locale],
        actions: [...s.presets.map((p) => '+' + fmt(p)), t('Other Amount…'), t('Snooze 1 Hour')],
      } };
    }
    case 'days': {
      const weekdays = [1, 2, 3, 4, 5, 6, 0].map((d) => ({
        label: new Intl.DateTimeFormat(intl, { weekday: 'short' }).format(new Date(2026, 9, 11 + d)),
        off: d === 0 || d === 6,
      }));
      // Réglages › Rappels, tel qu'il s'ouvre dans la version du Mac App Store :
      // la frise des deux types de journée, puis les cartes, jusqu'aux jours off.
      const minutes = (n) => new Intl.NumberFormat(intl, { style: 'unit', unit: 'minute', unitDisplay: 'short' }).format(n);
      const hour = (h) => new Intl.DateTimeFormat(intl, { hour: 'numeric' }).format(at(h));
      return { ...common, settings: {
        tabs: [['General', 'gear'], ['Hydration', 'drop'], ['Reminders', 'bell'], ['Shortcuts', 'keyboard']]
          .map(([key, icon]) => ({ label: t(key), icon, selected: key === 'Reminders' })),
        title: t('Reminders'),
        timeline: {
          hours: [0, 6, 12, 18].map((h) => ({ at: h, label: hour(h) })),
          work: { label: t('Work Day'), start: 8, end: 22, every: 45 },
          off: { label: t('Day Off'), start: 10, end: 22, every: 90 },
        },
        enableReminders: t('Enable reminders'), cadence: minutes(45),
        activeHours: t('Active hours'), from: time(at(8)), to: t('to'), until: time(at(22)),
        adapt: t('Adapt to my pace'),
        adaptHelp: t("Reminders follow your active hours, stop once your goal is reached, and come a bit more often when you're behind."),
        lastCall: t('Last call'), lastCallHelp: t("One hour before your day ends, if your goal isn't reached yet."),
        calls: t('Hold during calls'), weekly: t('Weekly summary'),
        pause: t('Pause reminders'), pauseMenu: t('Pause…'),
        dnd: t('Do Not Disturb Mode'),
        focusLink: t('Choose per Focus in System Settings › Focus › Focus Filters'),
        enable: t('Different settings on days off'),
        today: t('Today'), work: t('Work Day'), off: t('Day Off'),
        myDays: t('My days off'), weekdays,
      } };
    }
    case 'stats': {
      // Le haut de la vue Statistiques, dans l'ordre de l'app : tuiles, semaine,
      // heures, régularité. Mardi 13 octobre est « aujourd'hui ».
      const avg = s.target * 0.96;
      const [value, unit] = fmt(avg).split(' ');
      const [weekValue] = fmt(avg * 7).split(' ');
      const weekday = (d) => new Intl.DateTimeFormat(intl, { weekday: 'short' }).format(d);
      const week = [0.92, 1.05, 0.8, 0.75, 1.1, 0.97, 0.68].map((v, i) => ({ value: v, label: weekday(new Date(2026, 9, 7 + i)), today: i === 6 }));
      const hours = [0, 0, 0, 0, 0, 0, 0, 0.12, 1, 0.34, 0.5, 0.62, 0.7, 0.38, 0.3, 0.46, 0.58, 0.4, 0.52, 0.36, 0.44, 0.3, 0.12, 0];
      // Régularité : trente jours jusqu'à aujourd'hui, en colonnes de jours de la
      // semaine, la semaine commençant comme dans la locale.
      const loc = new Intl.Locale(intl);
      const firstDay = ((loc.getWeekInfo ? loc.getWeekInfo() : loc.weekInfo) || { firstDay: 1 }).firstDay % 7; // 0 = dimanche
      const levels = [0.65, 1, 0.4, 1, 1, 0.65, 0.4, 1, 1, 0.65, 1, 0, 1, 0.4, 1, 0.65, 1, 1, 0.4, 1, 1, 0.65, 1, 1, 0.18, 1, 0.65, 1, 1, 0.4];
      const start = new Date(2026, 8, 14);
      const lead = (start.getDay() - firstDay + 7) % 7;
      const header = Array.from({ length: 7 }, (_, i) => new Intl.DateTimeFormat(intl, { weekday: 'narrow' }).format(new Date(2026, 8, 6 + firstDay + i)));
      return { ...common, stats: {
        kpis: [[t('Average'), value, unit, 'trend'], [t('Weekly Total'), weekValue, unit, 'drop']],
        thisWeek: t('This Week'), week,
        whenYouDrink: t('When You Drink (30 days)'), hours,
        hourTicks: [0, 6, 12, 18].map((h) => ({ at: h, label: time(at(h)) })),
        consistency: t('Consistency (30 days)'), header, lead, levels,
        less: t('Less'), more: t('More'),
      } };
    }
    case 'bottle': {
      const drunk = s.bottle / 2;
      return { ...common, bottle: {
        status: t('%@ left in your bottle', fmt(s.bottle - drunk)),
        marks: ['¼', '½', '¾', t('Done')],
        reached: 2,
        fraction: 0.5,
      } };
    }
    case 'everywhere':
      return { ...common, menu: {
        version: `${t('Version')} 2.0.1`,
        add: s.presets.map((p) => t('Add %@', fmt(p))),
        undo: t('Undo'),
        dayOff: t('Today Is a Day Off'),
        pause: t('Pause Reminders'),
        shortcuts: t('Keyboard Shortcuts'),
        settings: t('Settings…'),
        about: t('About'),
        repo: t('View Repository'),
        quit: t('Quit'),
      }, widget: {
        title: t('Today'),
        presets: s.presets.slice(0, 2).map((p) => '+' + fmt(p)),
      } };
    default:
      return common;
  }
}

module.exports = { SCREENS, build };
