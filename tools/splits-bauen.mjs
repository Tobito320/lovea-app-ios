// Baut Lovea/Sources/Health/GymNeu/splits.json. Quelle der Wahrheit für die fertigen Splits.
// Lauf: node tools/splits-bauen.mjs   (bricht ab, wenn eine Übung nicht im Katalog steht)
// Nur Struktur gängiger Splits (Tage, Übungen, Sätze, Wiederholungen), keine fremden Texte.
import fs from 'node:fs';

const wurzel = new URL('../Lovea/Sources/Health/', import.meta.url);
const katalog = new Set(JSON.parse(fs.readFileSync(new URL('uebungen.json', wurzel), 'utf8')).map(u => u.id));

// Kurzname -> Katalog-id (ExerciseDB).
const U = {
  bank: 'EIeI8Vf', schraegLH: '3TZduzM', schraegKH: 'ns0SIbU', bankKH: 'SpYC0Kp', bankEng: 'J6Dx1Mu', fliegende: 'yz9nUhF',
  kabelFly: 'xLYSdtg', butterfly: 'v3xmPAR', dipsBrust: '9WTm7dq', dipsTrizeps: 'X6C6i5Y', liegestuetz: 'I4hDWkc',
  ohp: 'kTbSH9h', ohpKH: 'znQUdHY', ohpStehendKH: 'A6wtbuL', arnold: 'Xy4jlWA', seitheben: 'DsgkuIt', seithebenKabel: 'goJ6ezq',
  reverseFly: 'myfUsKf', reverseFlyKH: 'EAs3xL9', aufrechtRudern: 'UDlhcO8', shrugs: 'dG7tG5y',
  pushdown: '3ZflifB', pushdownV: 'gAwDzB3', ueberkopfTrizeps: '2IxROQ1', skull: 'h8LFzo9', kickbackKH: 'W6PxUkg',
  klimmzug: 'lBDjFxJ', klimmzugHilfe: 'kiJ4Z2K', chinup: 'T2mxWqc', latzug: 'eYnzaCm', latzugV: '4c9BhzB',
  rudernKabel: 'fUBheHs', rudernMaschine: '7I6LNUG', rudernLH: 'eZyBC3j', rudernKH: 'BJ0Hz5L', ueberzug: '9XjtHvS',
  curlLH: '25GPyDY', curlSZ: '6TG6x2w', hammer: 'slDvUAU', curlSchraeg: 'ae9UoXQ', curlKabel: 'G08RZcQ', preacher: 'qOgPVf6', konzentration: 'gvsWLQw',
  kniebeuge: 'qXTaZnJ', frontKniebeuge: 'zG0zs85', kniebeugeMulti: 'jFtipLl', hack: 'Qa55kX1', goblet: 'yn8yg1r', beinpresse: '10Z2DXU',
  beinstrecker: 'my33uHU', beinbeugerLiegend: '17lJ1kr', beinbeugerSitzend: 'Zg3XY7P',
  kreuzheben: 'ila4NZS', sumoKreuzheben: 'KgI0tqW', rdl: 'wQ2c4XD', rdlKH: 'rR0LJzx', goodMorning: 'XlZ4lAC', hyper: 'zhMwOwE',
  ausfallKH: 'RRWFUcw', ausfallGehend: 'IZVHb27', ausfallLH: 't8iSghb', splitSquatKH: 'qx4fgX7', stepUp: 'aXtJhlg',
  gesaessbruecke: 'qKBpF7I', hueftheben: 'CqhoytW', pullThrough: 'OM46QHm', kickbackKabel: 'HEJ6DIX', abduktion: 'CHpahtl', adduktion: 'oHsrypV',
  wadenStehend: 'ykUOVze', wadenSitzend: 'bOOdeyc', wadenKH: 'dPmaUaU',
  beinheben: 'I3tsCnC', crunch: 'TFqbd8t', reverseCrunch: 'nCU1Ekp', russianTwist: 'XVDdcoj', bergsteiger: 'RJgzwny',
};

// [Kurzname, Sätze, Wdh von, Wdh bis]
const push = [['bank', 4, 6, 8], ['schraegKH', 3, 8, 12], ['ohpKH', 3, 8, 10], ['seitheben', 3, 12, 15], ['kabelFly', 3, 12, 15], ['pushdown', 3, 10, 12]];
const pushB = [['ohp', 4, 6, 8], ['schraegLH', 3, 8, 10], ['dipsBrust', 3, 8, 12], ['seithebenKabel', 3, 12, 15], ['butterfly', 3, 12, 15], ['ueberkopfTrizeps', 3, 10, 12]];
const pull = [['klimmzug', 4, 6, 10], ['rudernLH', 3, 8, 10], ['latzug', 3, 10, 12], ['rudernKabel', 3, 10, 12], ['reverseFly', 3, 12, 15], ['curlSZ', 3, 8, 12]];
const pullB = [['kreuzheben', 3, 5, 6], ['latzugV', 3, 8, 12], ['rudernMaschine', 3, 10, 12], ['ueberzug', 3, 12, 15], ['hammer', 3, 10, 12], ['curlSchraeg', 3, 10, 12]];
const beine = [['kniebeuge', 4, 5, 8], ['rdl', 3, 8, 10], ['beinpresse', 3, 10, 12], ['beinbeugerLiegend', 3, 10, 12], ['beinstrecker', 3, 12, 15], ['wadenStehend', 4, 12, 15]];
const beineB = [['frontKniebeuge', 4, 6, 8], ['hack', 3, 8, 12], ['ausfallKH', 3, 10, 12], ['beinbeugerSitzend', 3, 10, 12], ['wadenSitzend', 4, 12, 15], ['beinheben', 3, 10, 15]];
const oben = [['bank', 4, 6, 8], ['rudernLH', 4, 6, 8], ['ohpKH', 3, 8, 10], ['latzug', 3, 10, 12], ['curlLH', 3, 10, 12], ['pushdown', 3, 10, 12]];
const obenB = [['schraegKH', 4, 8, 12], ['rudernKabel', 4, 8, 12], ['seitheben', 3, 12, 15], ['klimmzug', 3, 6, 10], ['hammer', 3, 10, 12], ['skull', 3, 10, 12]];
const unten = [['kniebeuge', 4, 6, 8], ['rdl', 3, 8, 10], ['beinpresse', 3, 10, 12], ['beinbeugerLiegend', 3, 10, 12], ['wadenStehend', 4, 10, 15]];
const untenB = [['kreuzheben', 3, 5, 6], ['frontKniebeuge', 3, 8, 10], ['ausfallKH', 3, 10, 12], ['beinstrecker', 3, 12, 15], ['wadenSitzend', 4, 12, 15], ['beinheben', 3, 10, 15]];
const ganzA = [['kniebeuge', 3, 5, 8], ['bank', 3, 5, 8], ['rudernLH', 3, 6, 10], ['seitheben', 2, 12, 15], ['crunch', 3, 12, 15]];
const ganzB = [['kreuzheben', 3, 5, 6], ['ohp', 3, 6, 8], ['latzug', 3, 8, 12], ['ausfallKH', 2, 10, 12], ['beinheben', 3, 10, 15]];
// Frauen
const glutes = [['gesaessbruecke', 4, 8, 12], ['rdl', 3, 8, 10], ['kickbackKabel', 3, 12, 15], ['abduktion', 3, 15, 20], ['hyper', 3, 12, 15]];
const glutesB = [['hueftheben', 4, 10, 12], ['splitSquatKH', 3, 8, 10], ['pullThrough', 3, 12, 15], ['abduktion', 3, 15, 20], ['stepUp', 3, 10, 12]];
const quadsPo = [['kniebeugeMulti', 4, 8, 10], ['beinpresse', 3, 10, 12], ['ausfallGehend', 3, 10, 12], ['beinstrecker', 3, 12, 15], ['gesaessbruecke', 3, 10, 12], ['wadenStehend', 3, 12, 15]];
const poBeuger = [['gesaessbruecke', 4, 8, 12], ['rdlKH', 3, 10, 12], ['beinbeugerSitzend', 3, 10, 12], ['kickbackKabel', 3, 12, 15], ['abduktion', 3, 15, 20]];
const obenW = [['latzug', 3, 10, 12], ['ohpKH', 3, 10, 12], ['rudernKabel', 3, 10, 12], ['seitheben', 3, 12, 15], ['pushdown', 2, 12, 15], ['curlKabel', 2, 12, 15]];
const obenWB = [['klimmzugHilfe', 3, 6, 10], ['schraegKH', 3, 10, 12], ['rudernKH', 3, 10, 12], ['reverseFly', 3, 12, 15], ['seithebenKabel', 3, 12, 15], ['crunch', 3, 12, 15]];
const schulternRuecken = [['ohpKH', 4, 8, 10], ['latzug', 4, 10, 12], ['seitheben', 4, 12, 15], ['rudernKabel', 3, 10, 12], ['reverseFly', 3, 12, 15], ['russianTwist', 3, 15, 20]];
const ganzW = [['goblet', 3, 10, 12], ['gesaessbruecke', 3, 10, 12], ['latzug', 3, 10, 12], ['ohpKH', 3, 10, 12], ['crunch', 3, 12, 15]];
const ganzWB = [['beinpresse', 3, 10, 12], ['rdlKH', 3, 10, 12], ['rudernKabel', 3, 10, 12], ['liegestuetz', 3, 6, 10], ['reverseCrunch', 3, 12, 15]];
const core = [['beinheben', 3, 10, 15], ['russianTwist', 3, 15, 20], ['reverseCrunch', 3, 12, 15], ['bergsteiger', 3, 20, 30], ['hyper', 3, 12, 15]];
// Zuhause
const khA = [['goblet', 4, 10, 12], ['bankKH', 3, 8, 12], ['rudernKH', 3, 10, 12], ['ohpStehendKH', 3, 8, 12], ['hammer', 3, 10, 12]];
const khB = [['rdlKH', 4, 10, 12], ['ausfallKH', 3, 10, 12], ['schraegKH', 3, 8, 12], ['reverseFlyKH', 3, 12, 15], ['kickbackKH', 3, 12, 15]];
const khC = [['splitSquatKH', 3, 8, 10], ['arnold', 3, 8, 12], ['ueberzug', 3, 10, 12], ['seitheben', 3, 12, 15], ['wadenKH', 3, 15, 20], ['crunch', 3, 12, 15]];

const t = (name, wochentage, uebungen) => ({ name, wochentage, uebungen });
// [id, name, gruppe, level, ziel, geraet, einheiten]
const SPLITS = [
  ['m-ppl6', 'Push Pull Beine', 'm', 'fortgeschritten', 'muskeln', 'studio', [t('Push', [1, 4], push), t('Pull', [2, 5], pull), t('Beine', [3, 6], beine)]],
  ['m-ppl6ab', 'Push Pull Beine A/B', 'm', 'fortgeschritten', 'muskeln', 'studio', [t('Push A', [1], push), t('Pull A', [2], pull), t('Beine A', [3], beine), t('Push B', [4], pushB), t('Pull B', [5], pullB), t('Beine B', [6], beineB)]],
  ['m-ppl3', 'Push Pull Beine kurz', 'm', 'einsteiger', 'muskeln', 'studio', [t('Push', [1], push), t('Pull', [3], pull), t('Beine', [5], beine)]],
  ['m-ul4', 'Oberkörper / Unterkörper', 'm', 'mittel', 'muskeln', 'studio', [t('Oberkörper A', [1], oben), t('Unterkörper A', [2], unten), t('Oberkörper B', [4], obenB), t('Unterkörper B', [5], untenB)]],
  ['m-phul', 'Kraft und Masse', 'm', 'mittel', 'kraft', 'studio', [
    t('Oberkörper Kraft', [1], [['bank', 4, 3, 5], ['rudernLH', 4, 3, 5], ['ohp', 3, 5, 8], ['klimmzug', 3, 6, 10], ['curlLH', 3, 6, 10], ['skull', 3, 6, 10]]),
    t('Unterkörper Kraft', [2], [['kniebeuge', 4, 3, 5], ['kreuzheben', 3, 3, 5], ['beinpresse', 3, 10, 12], ['beinbeugerLiegend', 3, 6, 10], ['wadenStehend', 4, 6, 10]]),
    t('Oberkörper Masse', [4], obenB), t('Unterkörper Masse', [5], untenB)]],
  ['m-phat', 'Powerbuilding', 'm', 'fortgeschritten', 'kraft', 'studio', [
    t('Oberkörper Kraft', [1], [['rudernLH', 3, 3, 5], ['klimmzug', 2, 6, 10], ['bank', 3, 3, 5], ['dipsBrust', 2, 6, 10], ['ohpKH', 3, 6, 10], ['curlSZ', 3, 6, 10]]),
    t('Unterkörper Kraft', [2], [['kniebeuge', 3, 3, 5], ['hack', 2, 6, 10], ['beinstrecker', 2, 6, 10], ['rdl', 3, 5, 8], ['beinbeugerLiegend', 2, 6, 10], ['wadenStehend', 3, 6, 10]]),
    t('Rücken und Schultern', [4], [['rudernLH', 4, 8, 12], ['latzug', 3, 8, 12], ['rudernKabel', 3, 8, 12], ['ohpKH', 3, 8, 12], ['aufrechtRudern', 2, 12, 15], ['seitheben', 3, 12, 20]]),
    t('Beine', [5], beineB),
    t('Brust und Arme', [6], [['schraegKH', 4, 8, 12], ['kabelFly', 3, 12, 15], ['butterfly', 2, 15, 20], ['preacher', 3, 8, 12], ['konzentration', 2, 12, 15], ['ueberkopfTrizeps', 3, 8, 12], ['pushdown', 2, 12, 15]])]],
  ['m-arnold', 'Arnold Split', 'm', 'fortgeschritten', 'muskeln', 'studio', [
    t('Brust und Rücken', [1, 4], [['bank', 4, 8, 12], ['schraegKH', 3, 8, 12], ['fliegende', 3, 10, 12], ['klimmzug', 4, 6, 10], ['rudernLH', 3, 8, 12], ['ueberzug', 3, 10, 12]]),
    t('Schultern und Arme', [2, 5], [['ohp', 4, 8, 10], ['seitheben', 3, 10, 12], ['reverseFly', 3, 12, 15], ['curlLH', 3, 8, 12], ['curlSchraeg', 3, 10, 12], ['bankEng', 3, 8, 10], ['pushdown', 3, 10, 12]]),
    t('Beine', [3, 6], beine)]],
  ['m-bro5', 'Ein Muskel pro Tag', 'm', 'mittel', 'muskeln', 'studio', [
    t('Brust', [1], [['bank', 4, 6, 10], ['schraegKH', 4, 8, 12], ['dipsBrust', 3, 8, 12], ['kabelFly', 3, 12, 15], ['butterfly', 3, 12, 15]]),
    t('Rücken', [2], [['kreuzheben', 3, 5, 6], ['klimmzug', 4, 6, 10], ['rudernLH', 3, 8, 10], ['latzug', 3, 10, 12], ['rudernKabel', 3, 10, 12], ['shrugs', 3, 10, 12]]),
    t('Schultern', [3], [['ohp', 4, 6, 8], ['arnold', 3, 8, 12], ['seitheben', 4, 12, 15], ['reverseFly', 3, 12, 15], ['aufrechtRudern', 3, 10, 12]]),
    t('Beine', [4], beine),
    t('Arme', [5], [['curlLH', 4, 8, 10], ['bankEng', 4, 8, 10], ['hammer', 3, 10, 12], ['skull', 3, 10, 12], ['curlKabel', 3, 12, 15], ['pushdown', 3, 12, 15]])]],
  ['m-gk3', 'Ganzkörper', 'm', 'einsteiger', 'fit', 'studio', [t('Ganzkörper A', [1, 5], ganzA), t('Ganzkörper B', [3], ganzB)]],
  ['m-5x5', 'Grundkraft 5 × 5', 'm', 'einsteiger', 'kraft', 'studio', [
    t('Training A', [1, 5], [['kniebeuge', 5, 5, 5], ['bank', 5, 5, 5], ['rudernLH', 5, 5, 5]]),
    t('Training B', [3], [['kniebeuge', 5, 5, 5], ['ohp', 5, 5, 5], ['kreuzheben', 1, 5, 5]])]],
  ['m-hauptlift4', 'Ein Hauptlift pro Tag', 'm', 'fortgeschritten', 'kraft', 'studio', [
    t('Kniebeuge', [1], [['kniebeuge', 3, 3, 5], ['beinpresse', 4, 10, 12], ['beinbeugerLiegend', 4, 10, 12], ['beinheben', 3, 10, 15]]),
    t('Bankdrücken', [2], [['bank', 3, 3, 5], ['schraegKH', 4, 8, 12], ['rudernKH', 4, 10, 12], ['pushdown', 3, 10, 15]]),
    t('Kreuzheben', [4], [['kreuzheben', 3, 3, 5], ['goodMorning', 3, 8, 10], ['latzug', 4, 10, 12], ['crunch', 3, 12, 15]]),
    t('Überkopfdrücken', [5], [['ohp', 3, 3, 5], ['dipsTrizeps', 4, 8, 12], ['chinup', 4, 6, 10], ['seitheben', 3, 12, 15]])]],
  ['m-torso4', 'Rumpf / Arme und Beine', 'm', 'mittel', 'muskeln', 'studio', [
    t('Rumpf A', [1], [['bank', 4, 6, 8], ['rudernLH', 4, 6, 8], ['schraegKH', 3, 8, 12], ['latzug', 3, 10, 12], ['seitheben', 3, 12, 15]]),
    t('Arme und Beine A', [2], [['kniebeuge', 4, 6, 8], ['beinbeugerLiegend', 3, 10, 12], ['curlLH', 3, 8, 12], ['skull', 3, 8, 12], ['wadenStehend', 4, 12, 15]]),
    t('Rumpf B', [4], [['ohp', 4, 6, 8], ['klimmzug', 4, 6, 10], ['dipsBrust', 3, 8, 12], ['rudernKabel', 3, 10, 12], ['reverseFly', 3, 12, 15]]),
    t('Arme und Beine B', [5], [['rdl', 4, 8, 10], ['beinpresse', 3, 10, 12], ['hammer', 3, 10, 12], ['pushdown', 3, 10, 12], ['wadenSitzend', 4, 12, 15]])]],
  ['m-pplul5', 'Push Pull Beine plus Ober / Unter', 'm', 'fortgeschritten', 'muskeln', 'studio', [t('Push', [1], push), t('Pull', [2], pull), t('Beine', [3], beine), t('Oberkörper', [5], obenB), t('Unterkörper', [6], untenB)]],
  ['m-pp4', 'Push / Pull', 'm', 'mittel', 'muskeln', 'studio', [
    t('Push A', [1], [['bank', 4, 6, 8], ['kniebeuge', 4, 6, 8], ['ohpKH', 3, 8, 10], ['beinstrecker', 3, 12, 15], ['pushdown', 3, 10, 12]]),
    t('Pull A', [2], [['kreuzheben', 3, 5, 6], ['klimmzug', 4, 6, 10], ['rudernKabel', 3, 10, 12], ['beinbeugerLiegend', 3, 10, 12], ['curlSZ', 3, 8, 12]]),
    t('Push B', [4], pushB), t('Pull B', [5], [['rudernLH', 4, 6, 8], ['latzug', 3, 10, 12], ['rdl', 3, 8, 10], ['reverseFly', 3, 12, 15], ['hammer', 3, 10, 12]])]],
  ['m-kh3', 'Zuhause mit Kurzhanteln', 'm', 'einsteiger', 'fit', 'kurzhantel', [t('Tag A', [1], khA), t('Tag B', [3], khB), t('Tag C', [5], khC)]],
  ['m-kg3', 'Zuhause ohne Geräte', 'm', 'einsteiger', 'fit', 'zuhause', [
    t('Ganzkörper', [1, 3, 5], [['liegestuetz', 4, 8, 15], ['ausfallGehend', 3, 12, 20], ['dipsTrizeps', 3, 8, 12], ['hyper', 3, 12, 15], ['bergsteiger', 3, 20, 30], ['crunch', 3, 15, 20]])]],

  ['w-glutes3', 'Glutes 3 Tage', 'w', 'einsteiger', 'muskeln', 'studio', [t('Glutes A', [1], [...glutes, ['latzug', 3, 10, 12]]), t('Glutes B', [3], [...glutesB, ['ohpKH', 3, 10, 12]]), t('Glutes C', [5], [...poBeuger, ['rudernKabel', 3, 10, 12]])]],
  ['w-glutes4', 'Glutes Fokus', 'w', 'mittel', 'muskeln', 'studio', [t('Glutes schwer', [1], glutes), t('Oberkörper', [2], obenW), t('Beine', [4], quadsPo), t('Glutes leicht', [6], glutesB)]],
  ['w-lul3', 'Unten, Oben, Unten', 'w', 'einsteiger', 'muskeln', 'studio', [t('Unterkörper A', [1], quadsPo), t('Oberkörper', [3], obenW), t('Unterkörper B', [5], poBeuger)]],
  ['w-gk3', 'Ganzkörper', 'w', 'einsteiger', 'fit', 'studio', [t('Ganzkörper A', [1, 5], ganzW), t('Ganzkörper B', [3], ganzWB)]],
  ['w-3u2o', 'Drei Mal Beine, zwei Mal oben', 'w', 'fortgeschritten', 'muskeln', 'studio', [t('Quads', [1], quadsPo), t('Oberkörper A', [2], obenW), t('Po und Beinbeuger', [3], poBeuger), t('Oberkörper B', [5], obenWB), t('Glutes', [6], glutesB)]],
  ['w-pbq3', 'Po, Beine, Oberkörper', 'w', 'mittel', 'muskeln', 'studio', [t('Po und Beinbeuger', [1], poBeuger), t('Quads und Po', [3], quadsPo), t('Oberkörper', [5], obenW)]],
  ['w-sanduhr4', 'Sanduhr', 'w', 'mittel', 'definieren', 'studio', [t('Glutes', [1], glutes), t('Schultern und Rücken', [2], schulternRuecken), t('Beine', [4], quadsPo), t('Oberkörper', [5], obenWB)]],
  ['w-sanduhr5', 'Sanduhr 5 Tage', 'w', 'fortgeschritten', 'definieren', 'studio', [t('Glutes schwer', [1], glutes), t('Schultern und Rücken', [2], schulternRuecken), t('Quads und Po', [3], quadsPo), t('Oberkörper', [5], obenWB), t('Glutes leicht', [6], glutesB)]],
  ['w-gb4', 'Glutes und Beine', 'w', 'fortgeschritten', 'muskeln', 'studio', [t('Glutes A', [1], glutes), t('Quads', [2], quadsPo), t('Glutes B', [4], glutesB), t('Beinbeuger', [5], poBeuger)]],
  ['w-kc4', 'Kraft und Core', 'w', 'einsteiger', 'definieren', 'studio', [t('Beine und Po', [1], poBeuger), t('Core', [2], core), t('Oberkörper', [4], obenW), t('Core und Po', [5], [...core.slice(0, 3), ['gesaessbruecke', 3, 12, 15], ['abduktion', 3, 15, 20]])]],
  ['w-ul4', 'Oberkörper / Unterkörper', 'w', 'mittel', 'muskeln', 'studio', [t('Unterkörper A', [1], quadsPo), t('Oberkörper A', [2], obenW), t('Unterkörper B', [4], poBeuger), t('Oberkörper B', [5], obenWB)]],
  ['w-ppl3', 'Beine, Push, Pull', 'w', 'mittel', 'muskeln', 'studio', [t('Beine', [1], quadsPo), t('Push', [3], [['ohpKH', 3, 10, 12], ['schraegKH', 3, 10, 12], ['seitheben', 3, 12, 15], ['pushdown', 3, 12, 15], ['gesaessbruecke', 3, 10, 12]]), t('Pull', [5], [['latzug', 3, 10, 12], ['rudernKabel', 3, 10, 12], ['reverseFly', 3, 12, 15], ['curlKabel', 3, 12, 15], ['rdlKH', 3, 10, 12]])]],
  ['w-kh3', 'Zuhause mit Kurzhanteln', 'w', 'einsteiger', 'fit', 'kurzhantel', [t('Tag A', [1], [['goblet', 4, 10, 12], ['rdlKH', 3, 10, 12], ['rudernKH', 3, 10, 12], ['ohpStehendKH', 3, 10, 12], ['crunch', 3, 12, 15]]), t('Tag B', [3], khB), t('Tag C', [5], khC)]],
  ['w-kg3', 'Zuhause ohne Geräte', 'w', 'einsteiger', 'fit', 'zuhause', [
    t('Ganzkörper', [1, 3, 5], [['ausfallGehend', 3, 12, 20], ['liegestuetz', 3, 5, 12], ['hyper', 3, 12, 15], ['reverseCrunch', 3, 12, 15], ['bergsteiger', 3, 20, 30], ['russianTwist', 3, 15, 20]])]],
];

const fehler = [];
const aus = SPLITS.map(([id, name, gruppe, level, ziel, geraet, einheiten]) => ({
  id, name, gruppe, level, ziel, geraet,
  tage: new Set(einheiten.flatMap(e => e.wochentage)).size,
  einheiten: einheiten.map(e => ({
    name: e.name, wochentage: e.wochentage,
    uebungen: e.uebungen.map(([k, saetze, von, bis]) => {
      if (!U[k]) fehler.push(`${id}: Kurzname "${k}" fehlt`);
      else if (!katalog.has(U[k])) fehler.push(`${id}: ${k} -> ${U[k]} nicht im Katalog`);
      return { uebung: U[k], saetze, von, bis };
    }),
  })),
}));
for (const s of aus) {
  const alle = s.einheiten.flatMap(e => e.wochentage);
  if (alle.length !== new Set(alle).size) fehler.push(`${s.id}: Wochentag doppelt vergeben`);
  if (alle.some(w => w < 1 || w > 7)) fehler.push(`${s.id}: Wochentag außerhalb 1 bis 7`);
}
if (new Set(aus.map(s => s.id)).size !== aus.length) fehler.push('Split-id doppelt');
if (fehler.length) { console.error(fehler.join('\n')); process.exit(1); }

fs.mkdirSync(new URL('GymNeu/', wurzel), { recursive: true });
fs.writeFileSync(new URL('GymNeu/splits.json', wurzel), JSON.stringify(aus) + '\n');
console.log(`${aus.length} Splits geschrieben (${aus.filter(s => s.gruppe === 'm').length} m, ${aus.filter(s => s.gruppe === 'w').length} w)`);
