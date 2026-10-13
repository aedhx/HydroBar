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
      return { ...common, settings: {
        tabs: [['General', 'gear'], ['Hydration', 'drop'], ['Reminders', 'bell'], ['Days', 'calendar'],
          ['Keyboard Shortcuts', 'keyboard'], ['Data', 'drive'], ['Integrations', 'puzzle']]
          .map(([key, icon]) => ({ label: t(key), icon, selected: key === 'Days' })),
        title: t('Days'),
        daysOff: t('DAYS OFF'),
        enable: t('Different settings on days off'),
        enableHelp: t('Your usual settings describe a work day. Days off can start later, remind you less often and have their own goal.'),
        today: t('TODAY'), work: t('Work Day'), off: t('Day Off'),
        todayHelp: t('Only for today. Tomorrow follows your week again.'),
        myDays: t('MY DAYS OFF'), weekdays,
        onDaysOff: t('ON DAYS OFF'),
        activeHours: t('Active hours'), from: time(at(10)), to: t('to'), until: time(at(22)),
        reminders: t('Reminders on days off'),
        remindMe: t('Remind me'), interval: t('Every %@', NINETY_MINUTES[locale]),
        ownGoal: t('Own goal'), goal: fmt(s.offGoal).split(' ')[0], unit: fmt(s.offGoal).split(' ')[1],
        timeOff: t('TIME OFF'),
        leave: t('Days off until %@', new Intl.DateTimeFormat(intl, { weekday: 'long', day: 'numeric', month: 'long' }).format(new Date(2026, 9, 23))),
        end: t('End'),
      } };
    }
    case 'stats': {
      const avg = s.target * 0.96;
      const months = [0.78, 0.82, 0.8, 0.88, 0.91, 0.86, 0.95, 1.02, 0.97, 1.04, 0.99, 0.96];
      return { ...common, stats: {
        kpis: [[t('Average'), fmt(avg)], [t('Weekly Total'), fmt(avg * 7)]],
        thisMonth: t('This Month'),
        month: new Intl.DateTimeFormat(intl, { month: 'long', year: 'numeric' }).format(at(12)),
        average: fmt(avg),
        aDay: t('a day on average'),
        goalDays: t('Goal reached %lld of %lld days', 9, 12),
        bestDay: t('Best day: %@, %@', new Intl.DateTimeFormat(intl, { day: 'numeric', month: 'short' }).format(new Date(2026, 9, 7)), fmt(s.target * 1.24)),
        streak: t('Current streak: %lld days.', 9),
        share: t('Share'), copy: t('Copy Image'),
        year: t('Your Year'),
        months: months.map((v, i) => ({
          value: v,
          label: new Intl.DateTimeFormat(intl, { month: 'narrow' }).format(new Date(2025, 10 + i, 1)),
        })),
        streakBig: t('Current streak: %lld days 🔥', 9),
        unstoppable: t("You're unstoppable!"),
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
        version: `${t('Version')} 2.0`,
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
