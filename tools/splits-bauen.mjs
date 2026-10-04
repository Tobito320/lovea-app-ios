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
  pendlay: 'r0z6xzQ', rackPull: 'za9Ni4z', tbar: 'BgljGjd', latzugParallel: 'rkg41Fb', rearRow: 'yUdIGNs', invRow: 'bZGHsAZ',
  cleanPress: 'SGY8Zui', maschBrust: 'DOoWcnA', maschSchulter: '67n3r98', frontheben: '3eGE2JC', bankdip: '9RT8oQW',
  unterarm: 'LrV4s90', farmer: 'qPEzJjA', kbSwing: 'UHJlbu3', burpee: 'dK9394r', sprung: 'LIlE5Tn',
  sumoMulti: 'dzz6BiV', curtsey: 'gUjqdei', kniebeugeKH: 'HsvHqgf', kreuzhebenKH: 'nUwVh7b', einbeinRdl: 'gKozT8X', stepUpLH: 'Kxquu2E',
  bruecke: 'u0cNiij', brueckeBank: 'aWedzZX', einbeinBruecke: 'rmEukuS', hipThrustBand: 'Pjbc0Kt', seitAbduktion: '7WaDzyL', adduktionKabel: 'hBGWILP',
  rueckenstrecker: 'rUXfn3R', reverseHyper: 'Krmb3cB', eselWaden: 'u5ESqzH',
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
  // Ahmeds 15 Splits aus dem Vault (10 Fitness/Splits, 04.10.2026), FitX Hagen-Mitte. Nackenübungen fehlen im Katalog, Face Pull = Reverse Fliegende.
  ['m-ahmed01', "Empfohlen: V-Taper Upper Lower 45", 'm', 'mittel', 'definieren', 'studio', [
    t("Upper A (schwer)", [1], [['ns0SIbU', 3, 5, 8], ['lBDjFxJ', 3, 6, 10], ['dRTfGZT', 3, 12, 15], ['C0MA9bC', 2, 8, 12], ['FVmZVhk', 2, 12, 15]]),
    t("Lower A", [2], [['qx4fgX7', 3, 6, 10], ['rR0LJzx', 3, 6, 10], ['goJ6ezq', 2, 12, 15], ['I3tsCnC', 3, 10, 15]]),
    t("Upper B (Volumen)", [4], [['jHAnWmT', 3, 8, 12], ['qdRxqCj', 3, 8, 12], ['goJ6ezq', 3, 12, 15], ['FVmZVhk', 2, 12, 15], ['myfUsKf', 3, 12, 15], ['dU605di', 2, 10, 15]]),
    t("Lower B", [5], [['10Z2DXU', 3, 8, 12], ['Zg3XY7P', 3, 10, 12], ['DsgkuIt', 2, 15, 20], ['WW95auq', 3, 10, 15], ['slDvUAU', 2, 10, 12], ['2IxROQ1', 2, 10, 12], ['myfUsKf', 2, 15, 15]])]],
  ['m-ahmed06', "Empfohlen: Oestreicher PPL x Upper Lower", 'm', 'mittel', 'muskeln', 'studio', [
    t("Push", [1], [['ns0SIbU', 3, 6, 10], ['67n3r98', 2, 8, 12], ['goJ6ezq', 3, 12, 15], ['FVmZVhk', 2, 12, 15], ['DOoWcnA', 2, 8, 12], ['dU605di', 2, 10, 15]]),
    t("Pull", [2], [['lBDjFxJ', 3, 6, 10], ['7I6LNUG', 3, 8, 12], ['myfUsKf', 2, 15, 15], ['DT14T9T', 2, 12, 15], ['ae9UoXQ', 2, 8, 12], ['NJzBsGJ', 2, 10, 12]]),
    t("Beine", [3], [['qx4fgX7', 3, 6, 10], ['rR0LJzx', 3, 8, 10], ['my33uHU', 2, 12, 15], ['ykHcWme', 2, 12, 15]]),
    t("Upper", [5], [['jHAnWmT', 3, 8, 12], ['qdRxqCj', 3, 8, 12], ['dRTfGZT', 3, 12, 15], ['slDvUAU', 2, 10, 12], ['2IxROQ1', 2, 10, 12]]),
    t("Lower", [6], [['10Z2DXU', 3, 8, 12], ['Zg3XY7P', 3, 10, 12], ['DsgkuIt', 2, 15, 20], ['myfUsKf', 2, 15, 15], ['I3tsCnC', 3, 10, 15], ['WW95auq', 2, 12, 12]])]],
  ['m-ahmed02', "Laid DUP Powerbuilding", 'm', 'fortgeschritten', 'kraft', 'studio', [
    t("Beine schwer", [1], [['qXTaZnJ', 4, 4, 6], ['wQ2c4XD', 3, 8, 8], ['10Z2DXU', 2, 10, 12], ['6MaEjVA', 3, 10, 12], ['I3tsCnC', 3, 12, 12]]),
    t("Push schwer", [2], [['EIeI8Vf', 4, 4, 6], ['ns0SIbU', 3, 8, 10], ['Kyd9Rz5', 3, 6, 8], ['DsgkuIt', 4, 12, 15], ['2IxROQ1', 3, 10, 12]]),
    t("Pull schwer", [3], [['ila4NZS', 3, 3, 5], ['lBDjFxJ', 3, 6, 10], ['eZyBC3j', 3, 8, 10], ['myfUsKf', 3, 15, 15], ['6TG6x2w', 3, 8, 10]]),
    t("Beine Volumen", [4], [['qx4fgX7', 3, 8, 10], ['17lJ1kr', 3, 10, 12], ['my33uHU', 3, 12, 15], ['CqhoytW', 3, 8, 10], ['WW95auq', 3, 12, 12]]),
    t("Push Volumen", [5], [['3TZduzM', 4, 6, 10], ['9WTm7dq', 3, 8, 12], ['goJ6ezq', 4, 12, 15], ['FVmZVhk', 3, 12, 15], ['dU605di', 3, 12, 12]]),
    t("Pull Volumen", [6], [['qdRxqCj', 4, 8, 12], ['fUBheHs', 3, 10, 12], ['DT14T9T', 3, 12, 15], ['myfUsKf', 3, 15, 15], ['ae9UoXQ', 3, 10, 12], ['NJzBsGJ', 3, 10, 12]])]],
  ['m-ahmed03', "Push Beine Pull Push 45", 'm', 'mittel', 'definieren', 'studio', [
    t("Push A", [1], [['ns0SIbU', 3, 6, 10], ['5v7KYld', 2, 8, 12], ['goJ6ezq', 4, 12, 15], ['67n3r98', 2, 8, 12], ['dU605di', 2, 10, 15], ['I3tsCnC', 2, 10, 15]]),
    t("Beine + Bauch", [2], [['10Z2DXU', 3, 8, 12], ['rR0LJzx', 3, 8, 10], ['my33uHU', 3, 12, 15], ['17lJ1kr', 2, 10, 15], ['WW95auq', 3, 12, 15]]),
    t("Pull", [4], [['qdRxqCj', 3, 8, 12], ['7I6LNUG', 3, 8, 12], ['DT14T9T', 2, 12, 15], ['myfUsKf', 3, 12, 15], ['ae9UoXQ', 2, 8, 12], ['slDvUAU', 2, 10, 12]]),
    t("Push B + Lat", [5], [['FVmZVhk', 3, 12, 15], ['jHAnWmT', 2, 8, 12], ['DsgkuIt', 3, 12, 15], ['4c9BhzB', 2, 8, 12], ['2IxROQ1', 2, 10, 12], ['NAgVB3t', 2, 8, 12]])]],
  ['m-ahmed04', "Ganzkörper 3x", 'm', 'einsteiger', 'muskeln', 'studio', [
    t("Ganzkörper A", [1], [['jFtipLl', 3, 6, 10], ['ns0SIbU', 3, 6, 10], ['qdRxqCj', 3, 8, 12], ['dRTfGZT', 3, 12, 15], ['I3tsCnC', 2, 10, 15]]),
    t("Ganzkörper B", [3], [['wQ2c4XD', 3, 6, 10], ['znQUdHY', 3, 8, 12], ['7I6LNUG', 3, 8, 12], ['goJ6ezq', 3, 12, 15]]),
    t("Ganzkörper C", [5], [['10Z2DXU', 3, 8, 12], ['jHAnWmT', 3, 8, 12], ['lBDjFxJ', 3, 6, 10], ['DsgkuIt', 2, 12, 15], ['slDvUAU', 2, 10, 12], ['2IxROQ1', 2, 10, 12], ['WW95auq', 2, 12, 12]])]],
  ['m-ahmed05', "Arnold Split 6 Tage", 'm', 'fortgeschritten', 'muskeln', 'studio', [
    t("Brust + Rücken", [1, 4], [['3TZduzM', 3, 6, 10], ['lBDjFxJ', 3, 6, 10], ['v3xmPAR', 2, 12, 15], ['fUBheHs', 3, 8, 12], ['FVmZVhk', 2, 12, 15], ['DT14T9T', 2, 12, 15]]),
    t("Schulter + Arme", [2, 5], [['znQUdHY', 3, 8, 10], ['DsgkuIt', 4, 12, 15], ['myfUsKf', 2, 15, 15], ['6TG6x2w', 3, 8, 12], ['2IxROQ1', 3, 10, 12], ['slDvUAU', 2, 10, 12]]),
    t("Beine + Bauch", [3, 6], [['qXTaZnJ', 3, 6, 10], ['wQ2c4XD', 3, 8, 10], ['my33uHU', 2, 12, 15], ['ykHcWme', 3, 12, 15], ['I3tsCnC', 3, 10, 15]])]],
  ['m-ahmed07', "Schulter-Spezialisierung V-Taper", 'm', 'mittel', 'muskeln', 'studio', [
    t("Oberkörper A", [1], [['dRTfGZT', 3, 12, 15], ['ns0SIbU', 3, 6, 10], ['qdRxqCj', 3, 8, 12], ['dU605di', 2, 10, 15]]),
    t("Beine", [2], [['jFtipLl', 3, 6, 10], ['wQ2c4XD', 3, 8, 10], ['goJ6ezq', 3, 12, 15], ['I3tsCnC', 2, 10, 15]]),
    t("Oberkörper B", [3], [['znQUdHY', 3, 8, 10], ['7I6LNUG', 3, 8, 12], ['DsgkuIt', 3, 12, 20], ['myfUsKf', 2, 15, 15], ['ae9UoXQ', 2, 8, 12]]),
    t("Oberkörper C", [5], [['goJ6ezq', 3, 12, 15], ['jHAnWmT', 3, 8, 12], ['lBDjFxJ', 3, 6, 10], ['2IxROQ1', 2, 10, 12], ['slDvUAU', 2, 10, 12]]),
    t("Beine leicht + Bauch", [6], [['10Z2DXU', 3, 10, 12], ['17lJ1kr', 2, 10, 12], ['WW95auq', 3, 12, 12]])]],
  ['m-ahmed08', "Torso Limbs", 'm', 'mittel', 'muskeln', 'studio', [
    t("Torso A", [1], [['3TZduzM', 3, 6, 10], ['lBDjFxJ', 3, 6, 10], ['dRTfGZT', 3, 12, 15], ['fUBheHs', 2, 8, 12], ['myfUsKf', 2, 15, 15]]),
    t("Arme + Beine A", [2], [['jFtipLl', 3, 6, 10], ['Zg3XY7P', 2, 10, 12], ['6TG6x2w', 3, 8, 12], ['2IxROQ1', 3, 10, 12], ['I3tsCnC', 2, 10, 15]]),
    t("Torso B", [4], [['jHAnWmT', 3, 8, 12], ['qdRxqCj', 3, 8, 12], ['goJ6ezq', 3, 12, 15], ['FVmZVhk', 2, 12, 15], ['myfUsKf', 2, 15, 15]]),
    t("Arme + Beine B", [5], [['wQ2c4XD', 3, 8, 10], ['10Z2DXU', 2, 10, 12], ['slDvUAU', 2, 10, 12], ['dU605di', 2, 10, 15], ['WW95auq', 2, 12, 12]])]],
  ['m-ahmed09', "Upper Lower Push Pull Legs", 'm', 'mittel', 'muskeln', 'studio', [
    t("Upper schwer", [1], [['EIeI8Vf', 3, 4, 6], ['eZyBC3j', 3, 6, 8], ['Kyd9Rz5', 2, 6, 8], ['lBDjFxJ', 2, 6, 10]]),
    t("Lower schwer", [2], [['qXTaZnJ', 3, 4, 6], ['wQ2c4XD', 3, 6, 8], ['6MaEjVA', 3, 8, 12], ['I3tsCnC', 2, 10, 15]]),
    t("Push", [4], [['ns0SIbU', 3, 8, 12], ['FVmZVhk', 2, 12, 15], ['DsgkuIt', 4, 12, 15], ['2IxROQ1', 3, 10, 12]]),
    t("Pull", [5], [['qdRxqCj', 3, 8, 12], ['7I6LNUG', 3, 10, 12], ['myfUsKf', 3, 15, 15], ['ae9UoXQ', 3, 10, 12]]),
    t("Beine", [6], [['10Z2DXU', 3, 10, 12], ['17lJ1kr', 3, 10, 12], ['my33uHU', 2, 12, 15], ['WW95auq', 3, 12, 12]])]],
  ['m-ahmed10', "Bro Split klassisch", 'm', 'mittel', 'muskeln', 'studio', [
    t("Brust", [1], [['3TZduzM', 4, 6, 10], ['ns0SIbU', 3, 8, 12], ['DOoWcnA', 3, 8, 12], ['FVmZVhk', 3, 12, 15]]),
    t("Rücken", [2], [['lBDjFxJ', 4, 6, 10], ['eZyBC3j', 3, 8, 10], ['4c9BhzB', 3, 10, 12], ['DT14T9T', 3, 12, 15]]),
    t("Schulter", [3], [['znQUdHY', 3, 8, 10], ['DsgkuIt', 4, 12, 15], ['goJ6ezq', 3, 12, 15], ['myfUsKf', 3, 15, 15], ['NJzBsGJ', 3, 10, 12]]),
    t("Beine", [5], [['qXTaZnJ', 4, 6, 10], ['wQ2c4XD', 3, 8, 10], ['10Z2DXU', 3, 10, 12], ['17lJ1kr', 3, 10, 12], ['ykHcWme', 3, 12, 15]]),
    t("Arme + Bauch", [6], [['6TG6x2w', 3, 8, 12], ['2IxROQ1', 3, 10, 12], ['ae9UoXQ', 3, 10, 12], ['dU605di', 3, 10, 15], ['WW95auq', 3, 12, 12], ['I3tsCnC', 3, 10, 15]])]],
  ['m-ahmed11', "Kraftblock Powerlifting", 'm', 'fortgeschritten', 'kraft', 'studio', [
    t("Kniebeuge + Bank", [1], [['qXTaZnJ', 4, 3, 5], ['EIeI8Vf', 4, 3, 5], ['DsgkuIt', 3, 12, 15], ['I3tsCnC', 2, 10, 15]]),
    t("Kreuzheben + Overhead", [2], [['ila4NZS', 3, 2, 4], ['Kyd9Rz5', 3, 5, 6], ['lBDjFxJ', 3, 5, 8], ['myfUsKf', 2, 15, 15]]),
    t("Bank Volumen", [4], [['EIeI8Vf', 3, 6, 8], ['ns0SIbU', 2, 8, 10], ['eZyBC3j', 3, 6, 8], ['goJ6ezq', 3, 12, 15], ['2IxROQ1', 2, 10, 12]]),
    t("Kniebeuge Volumen", [5], [['qXTaZnJ', 3, 6, 8], ['wQ2c4XD', 3, 6, 8], ['qdRxqCj', 3, 8, 10], ['6TG6x2w', 2, 8, 10]])]],
  ['m-ahmed12', "Ganzkörper 4x kurz", 'm', 'einsteiger', 'definieren', 'studio', [
    t("Ganzkörper A", [1, 4], [['ns0SIbU', 3, 6, 10], ['qdRxqCj', 3, 8, 12], ['10Z2DXU', 2, 8, 12], ['dRTfGZT', 3, 12, 15], ['WW95auq', 2, 12, 12]]),
    t("Ganzkörper B", [2, 5], [['jHAnWmT', 2, 8, 12], ['7I6LNUG', 3, 8, 12], ['rR0LJzx', 2, 8, 10], ['goJ6ezq', 3, 12, 15], ['slDvUAU', 1, 10, 12], ['2IxROQ1', 1, 10, 12]])]],
  ['m-ahmed13', "PPL 3 Tage", 'm', 'einsteiger', 'muskeln', 'studio', [
    t("Push", [1], [['3TZduzM', 3, 6, 10], ['znQUdHY', 3, 8, 10], ['DsgkuIt', 4, 12, 15], ['FVmZVhk', 2, 12, 15], ['2IxROQ1', 3, 10, 12]]),
    t("Pull", [3], [['lBDjFxJ', 3, 6, 10], ['7I6LNUG', 3, 8, 12], ['qdRxqCj', 2, 10, 12], ['myfUsKf', 2, 15, 15], ['6TG6x2w', 3, 8, 12]]),
    t("Beine", [5], [['jFtipLl', 3, 6, 10], ['wQ2c4XD', 3, 8, 10], ['my33uHU', 2, 12, 15], ['I3tsCnC', 3, 10, 15]])]],
  ['m-ahmed14', "Anterior Posterior", 'm', 'mittel', 'muskeln', 'studio', [
    t("Vorderseite A", [1], [['3TZduzM', 3, 6, 10], ['jFtipLl', 3, 6, 10], ['dRTfGZT', 3, 12, 15], ['ae9UoXQ', 2, 8, 12], ['I3tsCnC', 2, 10, 15]]),
    t("Rückseite A", [2], [['lBDjFxJ', 3, 6, 10], ['wQ2c4XD', 3, 6, 10], ['7I6LNUG', 2, 8, 12], ['2IxROQ1', 2, 10, 12]]),
    t("Vorderseite B", [4], [['jHAnWmT', 3, 8, 12], ['10Z2DXU', 3, 10, 12], ['goJ6ezq', 3, 12, 15], ['slDvUAU', 2, 10, 12], ['WW95auq', 2, 12, 12]]),
    t("Rückseite B", [5], [['qdRxqCj', 3, 8, 12], ['Zg3XY7P', 3, 10, 12], ['myfUsKf', 2, 15, 15], ['dU605di', 2, 10, 15], ['DsgkuIt', 2, 15, 20]])]],
  ['m-ahmed15', "Minimum 2 Tage", 'm', 'einsteiger', 'fit', 'studio', [
    t("Ganzkörper A", [1], [['ns0SIbU', 3, 6, 10], ['qdRxqCj', 3, 8, 12], ['10Z2DXU', 2, 8, 12], ['dRTfGZT', 3, 12, 15], ['I3tsCnC', 2, 10, 15]]),
    t("Ganzkörper B", [4], [['67n3r98', 2, 8, 12], ['7I6LNUG', 3, 8, 12], ['rR0LJzx', 2, 8, 10], ['goJ6ezq', 3, 12, 15], ['WW95auq', 2, 12, 12]])]],

  // Ahmeds Reihenfolge im Oberkörper (PRODUCT.md): Schulter, Unterarme, Nacken, Rücken, Brust. Beine 2x, oben 2x.
  ['m-schulter4', 'Schulter zuerst', 'm', 'mittel', 'muskeln', 'studio', [
    t('Oberkörper A', [1], [['ohp', 4, 6, 8], ['seitheben', 4, 12, 15], ['unterarm', 3, 12, 15], ['shrugs', 3, 10, 12], ['rudernLH', 4, 6, 10], ['bank', 3, 6, 10]]),
    t('Beine A', [2], beine),
    t('Oberkörper B', [4], [['ohpKH', 4, 8, 10], ['seithebenKabel', 4, 12, 15], ['farmer', 3, 20, 30], ['aufrechtRudern', 3, 10, 12], ['klimmzug', 4, 6, 10], ['schraegKH', 3, 8, 12]]),
    t('Beine B', [5], beineB)]],
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
  ['m-gk2', 'Ganzkörper 2 Tage', 'm', 'einsteiger', 'fit', 'studio', [
    t('Ganzkörper A', [2], [['kniebeuge', 3, 6, 10], ['bank', 3, 6, 10], ['latzug', 3, 8, 12], ['ohpKH', 3, 8, 12], ['beinbeugerLiegend', 3, 10, 12], ['crunch', 3, 12, 15]]),
    t('Ganzkörper B', [5], [['kreuzheben', 3, 5, 8], ['schraegKH', 3, 8, 12], ['rudernKabel', 3, 8, 12], ['beinpresse', 3, 10, 12], ['seitheben', 3, 12, 15], ['beinheben', 3, 10, 15]])]],
  ['m-gk5', 'Ganzkörper 5 Tage', 'm', 'fortgeschritten', 'muskeln', 'studio', [
    t('Tag 1', [1], [['kniebeuge', 3, 5, 8], ['bank', 3, 5, 8], ['latzug', 3, 10, 12], ['seitheben', 3, 12, 15]]),
    t('Tag 2', [2], [['rdl', 3, 8, 10], ['ohp', 3, 6, 8], ['rudernKabel', 3, 10, 12], ['curlSZ', 3, 10, 12]]),
    t('Tag 3', [3], [['beinpresse', 3, 10, 12], ['schraegKH', 3, 8, 12], ['klimmzug', 3, 6, 10], ['pushdown', 3, 10, 12]]),
    t('Tag 4', [5], [['hack', 3, 8, 12], ['dipsBrust', 3, 8, 12], ['tbar', 3, 8, 12], ['rearRow', 3, 12, 15]]),
    t('Tag 5', [6], [['beinbeugerSitzend', 3, 10, 12], ['maschBrust', 3, 10, 12], ['latzugParallel', 3, 10, 12], ['hammer', 3, 10, 12], ['wadenStehend', 3, 12, 15]])]],
  ['m-stufen4', 'Linear in drei Stufen', 'm', 'einsteiger', 'kraft', 'studio', [
    t('Kniebeuge schwer', [1], [['kniebeuge', 5, 3, 3], ['bank', 3, 10, 10], ['latzug', 3, 15, 15]]),
    t('Drücken schwer', [2], [['ohp', 5, 3, 3], ['kreuzheben', 3, 10, 10], ['rudernKH', 3, 15, 15]]),
    t('Bank schwer', [4], [['bank', 5, 3, 3], ['kniebeuge', 3, 10, 10], ['latzugV', 3, 15, 15]]),
    t('Kreuzheben schwer', [5], [['kreuzheben', 5, 3, 3], ['ohp', 3, 10, 10], ['rudernKabel', 3, 15, 15]])]],
  ['m-volumen4', 'Hauptlift plus 5 × 10', 'm', 'mittel', 'kraft', 'studio', [
    t('Überkopfdrücken', [1], [['ohp', 3, 3, 5], ['ohpKH', 5, 10, 10], ['chinup', 5, 8, 10]]),
    t('Kreuzheben', [2], [['kreuzheben', 3, 3, 5], ['rdl', 5, 10, 10], ['beinheben', 5, 10, 15]]),
    t('Bankdrücken', [4], [['bank', 3, 3, 5], ['bankKH', 5, 10, 10], ['rudernKH', 5, 10, 10]]),
    t('Kniebeuge', [5], [['kniebeuge', 3, 3, 5], ['beinpresse', 5, 10, 10], ['beinbeugerLiegend', 5, 10, 10]])]],
  ['m-schwerleicht3', 'Viel, leicht, Rekord', 'm', 'mittel', 'kraft', 'studio', [
    t('Viel', [1], [['kniebeuge', 5, 5, 5], ['bank', 5, 5, 5], ['pendlay', 5, 5, 5]]),
    t('Leicht', [3], [['frontKniebeuge', 2, 5, 5], ['ohp', 3, 5, 5], ['chinup', 3, 6, 10], ['hyper', 3, 10, 12]]),
    t('Rekord', [5], [['kniebeuge', 1, 5, 5], ['bank', 1, 5, 5], ['kreuzheben', 1, 5, 5], ['dipsTrizeps', 3, 8, 12]])]],
  ['m-dreikampf3', 'Kraftdreikampf', 'm', 'fortgeschritten', 'kraft', 'studio', [
    t('Kniebeuge', [1], [['kniebeuge', 5, 3, 5], ['frontKniebeuge', 3, 5, 8], ['beinbeugerLiegend', 3, 8, 10], ['beinheben', 3, 10, 15]]),
    t('Bankdrücken', [3], [['bank', 5, 3, 5], ['bankEng', 3, 6, 8], ['pendlay', 4, 5, 8], ['skull', 3, 8, 12]]),
    t('Kreuzheben', [5], [['kreuzheben', 4, 2, 4], ['rackPull', 3, 4, 6], ['goodMorning', 3, 8, 10], ['klimmzug', 3, 6, 10]])]],
  ['m-oben4', 'Oberkörper Fokus', 'm', 'mittel', 'muskeln', 'studio', [
    t('Brust und Rücken', [1], [['bank', 4, 6, 8], ['tbar', 4, 8, 10], ['schraegKH', 3, 8, 12], ['latzugParallel', 3, 10, 12], ['butterfly', 3, 12, 15]]),
    t('Beine', [2], unten),
    t('Schultern und Arme', [4], [['ohp', 4, 6, 8], ['seitheben', 4, 12, 15], ['rearRow', 3, 12, 15], ['curlSZ', 3, 8, 12], ['pushdownV', 3, 10, 12]]),
    t('Oberkörper leicht', [6], [['maschBrust', 3, 10, 15], ['rudernMaschine', 3, 10, 15], ['maschSchulter', 3, 10, 15], ['curlKabel', 3, 12, 15], ['ueberkopfTrizeps', 3, 12, 15]])]],
  ['m-arme4', 'Arme Fokus', 'm', 'mittel', 'muskeln', 'studio', [
    t('Arme schwer', [1], [['bankEng', 4, 6, 8], ['curlLH', 4, 6, 8], ['dipsTrizeps', 3, 8, 12], ['hammer', 3, 8, 12], ['unterarm', 3, 12, 15]]),
    t('Beine', [2], unten),
    t('Brust, Rücken, Schultern', [4], [['bank', 3, 6, 10], ['klimmzug', 3, 6, 10], ['ohpKH', 3, 8, 10], ['rudernKabel', 3, 10, 12], ['seitheben', 3, 12, 15]]),
    t('Arme leicht', [5], [['skull', 3, 10, 12], ['preacher', 3, 10, 12], ['pushdown', 3, 12, 15], ['curlSchraeg', 3, 12, 15], ['konzentration', 2, 12, 15], ['kickbackKH', 2, 12, 15]])]],
  ['m-ruecken5', 'Breiter Rücken', 'm', 'fortgeschritten', 'muskeln', 'studio', [
    t('Rücken Breite', [1], [['klimmzug', 4, 6, 10], ['latzug', 3, 10, 12], ['latzugParallel', 3, 10, 12], ['ueberzug', 3, 12, 15], ['curlSZ', 3, 8, 12]]),
    t('Brust und Schultern', [2], [['bank', 4, 6, 8], ['ohpKH', 3, 8, 10], ['kabelFly', 3, 12, 15], ['seitheben', 3, 12, 15], ['pushdown', 3, 10, 12]]),
    t('Beine', [3], beine),
    t('Rücken Dicke', [5], [['pendlay', 4, 5, 8], ['tbar', 3, 8, 10], ['rudernKabel', 3, 10, 12], ['rearRow', 3, 12, 15], ['shrugs', 3, 10, 12], ['hammer', 3, 10, 12]]),
    t('Oberkörper leicht', [6], [['schraegKH', 3, 10, 12], ['rudernMaschine', 3, 10, 12], ['maschSchulter', 3, 10, 12], ['hyper', 3, 12, 15]])]],
  ['m-brust4', 'Brust Fokus', 'm', 'mittel', 'muskeln', 'studio', [
    t('Brust schwer', [1], [['bank', 5, 4, 6], ['schraegLH', 4, 6, 8], ['dipsBrust', 3, 8, 12], ['pushdown', 3, 10, 12]]),
    t('Rücken und Bizeps', [2], [['rudernLH', 4, 6, 8], ['latzug', 3, 10, 12], ['rearRow', 3, 12, 15], ['curlLH', 3, 8, 12]]),
    t('Beine', [4], beineB),
    t('Brust leicht und Schultern', [5], [['schraegKH', 4, 10, 12], ['maschBrust', 3, 12, 15], ['kabelFly', 3, 12, 15], ['ohpKH', 3, 8, 10], ['seitheben', 3, 12, 15]])]],
  ['m-masch3', 'Nur Maschinen', 'm', 'einsteiger', 'muskeln', 'studio', [
    t('Drücken', [1], [['maschBrust', 3, 10, 12], ['maschSchulter', 3, 10, 12], ['butterfly', 3, 12, 15], ['pushdown', 3, 12, 15]]),
    t('Ziehen', [3], [['latzug', 3, 10, 12], ['rudernMaschine', 3, 10, 12], ['rearRow', 3, 12, 15], ['curlKabel', 3, 12, 15], ['rueckenstrecker', 3, 12, 15]]),
    t('Beine', [5], [['beinpresse', 4, 10, 12], ['beinstrecker', 3, 12, 15], ['beinbeugerSitzend', 3, 12, 15], ['abduktion', 2, 15, 20], ['adduktion', 2, 15, 20], ['wadenSitzend', 3, 12, 15]])]],
  ['m-athletik4', 'Athletik', 'm', 'mittel', 'fit', 'studio', [
    t('Explosiv', [1], [['cleanPress', 5, 3, 5], ['sprung', 4, 5, 8], ['kbSwing', 4, 12, 15], ['beinheben', 3, 10, 15]]),
    t('Oberkörper', [2], [['klimmzug', 4, 6, 10], ['dipsBrust', 4, 8, 12], ['invRow', 3, 10, 12], ['liegestuetz', 3, 12, 20], ['farmer', 3, 20, 30]]),
    t('Beine', [4], [['frontKniebeuge', 4, 5, 8], ['einbeinRdl', 3, 8, 10], ['ausfallGehend', 3, 12, 16], ['eselWaden', 3, 15, 20]]),
    t('Ausdauer', [5], [['kbSwing', 5, 15, 20], ['burpee', 4, 10, 15], ['bergsteiger', 4, 20, 30], ['russianTwist', 3, 15, 20], ['hyper', 3, 12, 15]])]],
  ['m-def4', 'Definieren 4 Tage', 'm', 'mittel', 'definieren', 'studio', [
    t('Oberkörper Kraft', [1], [['bank', 4, 5, 8], ['rudernLH', 4, 5, 8], ['ohpKH', 3, 8, 10], ['klimmzug', 3, 6, 10]]),
    t('Unterkörper Kraft', [2], [['kniebeuge', 4, 5, 8], ['rdl', 3, 8, 10], ['beinpresse', 3, 10, 12], ['wadenStehend', 3, 12, 15]]),
    t('Oberkörper Zirkel', [4], [['schraegKH', 3, 12, 15], ['rudernKabel', 3, 12, 15], ['seitheben', 3, 15, 20], ['pushdown', 3, 15, 20], ['curlKabel', 3, 15, 20], ['bergsteiger', 3, 20, 30]]),
    t('Unterkörper Zirkel', [5], [['goblet', 3, 12, 15], ['ausfallGehend', 3, 12, 16], ['beinbeugerSitzend', 3, 12, 15], ['kbSwing', 3, 15, 20], ['beinheben', 3, 10, 15], ['burpee', 3, 10, 12]])]],
  ['m-def3', 'Definieren Zirkel', 'm', 'einsteiger', 'definieren', 'studio', [
    t('Zirkel A', [1], [['goblet', 3, 12, 15], ['liegestuetz', 3, 10, 15], ['rudernKabel', 3, 12, 15], ['kbSwing', 3, 15, 20], ['crunch', 3, 15, 20]]),
    t('Zirkel B', [3], [['beinpresse', 3, 12, 15], ['maschBrust', 3, 12, 15], ['latzug', 3, 12, 15], ['burpee', 3, 8, 12], ['russianTwist', 3, 15, 20]]),
    t('Zirkel C', [5], [['ausfallKH', 3, 12, 16], ['ohpKH', 3, 10, 12], ['invRow', 3, 10, 12], ['bergsteiger', 3, 20, 30], ['reverseCrunch', 3, 12, 15]])]],
  ['m-kh2', 'Kurzhanteln 2 Tage', 'm', 'einsteiger', 'fit', 'kurzhantel', [
    t('Tag A', [2], [['kniebeugeKH', 3, 10, 12], ['bankKH', 3, 8, 12], ['rudernKH', 3, 10, 12], ['seitheben', 3, 12, 15], ['crunch', 3, 12, 15]]),
    t('Tag B', [5], [['kreuzhebenKH', 3, 8, 12], ['ohpStehendKH', 3, 8, 12], ['ueberzug', 3, 10, 12], ['ausfallKH', 3, 10, 12], ['hammer', 3, 10, 12]])]],
  ['m-kh4', 'Kurzhanteln Ober / Unter', 'm', 'mittel', 'muskeln', 'kurzhantel', [
    t('Oberkörper A', [1], [['bankKH', 4, 8, 12], ['rudernKH', 4, 8, 12], ['ohpKH', 3, 8, 12], ['hammer', 3, 10, 12], ['kickbackKH', 3, 12, 15]]),
    t('Unterkörper A', [2], [['goblet', 4, 10, 12], ['rdlKH', 4, 10, 12], ['ausfallKH', 3, 10, 12], ['wadenKH', 4, 15, 20]]),
    t('Oberkörper B', [4], [['schraegKH', 4, 8, 12], ['ueberzug', 3, 10, 12], ['arnold', 3, 8, 12], ['reverseFlyKH', 3, 12, 15], ['curlSchraeg', 3, 10, 12]]),
    t('Unterkörper B', [5], [['splitSquatKH', 3, 8, 10], ['einbeinRdl', 3, 8, 10], ['stepUp', 3, 10, 12], ['kniebeugeKH', 3, 12, 15], ['russianTwist', 3, 15, 20]])]],
  ['m-kh5', 'Kurzhanteln 5 Tage', 'm', 'fortgeschritten', 'muskeln', 'kurzhantel', [
    t('Push', [1], [['bankKH', 4, 8, 12], ['schraegKH', 3, 8, 12], ['ohpKH', 3, 8, 12], ['seitheben', 4, 12, 15], ['kickbackKH', 3, 12, 15]]),
    t('Pull', [2], [['rudernKH', 4, 8, 12], ['ueberzug', 3, 10, 12], ['reverseFlyKH', 3, 12, 15], ['hammer', 3, 10, 12], ['konzentration', 3, 10, 12]]),
    t('Beine', [3], [['goblet', 4, 10, 12], ['rdlKH', 4, 10, 12], ['splitSquatKH', 3, 8, 10], ['wadenKH', 4, 15, 20]]),
    t('Oberkörper', [5], [['arnold', 4, 8, 12], ['fliegende', 3, 10, 12], ['rudernKH', 3, 10, 12], ['frontheben', 3, 12, 15], ['curlSchraeg', 3, 10, 12]]),
    t('Unterkörper', [6], [['kreuzhebenKH', 4, 8, 12], ['ausfallKH', 3, 10, 12], ['stepUp', 3, 10, 12], ['einbeinRdl', 3, 8, 10], ['crunch', 3, 15, 20]])]],
  ['m-kg4', 'Ohne Geräte Ober / Unter', 'm', 'mittel', 'fit', 'zuhause', [
    t('Oberkörper A', [1], [['liegestuetz', 4, 8, 15], ['invRow', 4, 8, 12], ['bankdip', 3, 10, 15], ['crunch', 3, 15, 20]]),
    t('Unterkörper A', [2], [['sprung', 4, 10, 15], ['ausfallGehend', 3, 12, 20], ['einbeinBruecke', 3, 10, 15], ['eselWaden', 3, 15, 25]]),
    t('Oberkörper B', [4], [['klimmzug', 4, 4, 10], ['dipsTrizeps', 3, 6, 12], ['liegestuetz', 3, 10, 20], ['reverseCrunch', 3, 12, 15]]),
    t('Unterkörper B', [5], [['curtsey', 3, 12, 16], ['bruecke', 3, 15, 20], ['bergsteiger', 3, 20, 30], ['burpee', 3, 8, 12], ['hyper', 3, 12, 15]])]],

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
  ['w-gk2', 'Ganzkörper 2 Tage', 'w', 'einsteiger', 'fit', 'studio', [
    t('Ganzkörper A', [2], [['beinpresse', 3, 10, 12], ['gesaessbruecke', 3, 10, 12], ['latzug', 3, 10, 12], ['maschBrust', 3, 10, 12], ['crunch', 3, 12, 15]]),
    t('Ganzkörper B', [5], [['goblet', 3, 10, 12], ['rdlKH', 3, 10, 12], ['rudernKabel', 3, 10, 12], ['ohpKH', 3, 10, 12], ['abduktion', 3, 15, 20]])]],
  ['w-po3', 'Po Aufbau Start', 'w', 'einsteiger', 'muskeln', 'studio', [
    t('Tag A', [1], [['bruecke', 3, 15, 20], ['goblet', 3, 10, 12], ['rudernKH', 3, 10, 12], ['seitAbduktion', 3, 15, 20], ['rueckenstrecker', 3, 12, 15]]),
    t('Tag B', [3], [['brueckeBank', 3, 12, 15], ['stepUp', 3, 10, 12], ['latzug', 3, 10, 12], ['bankKH', 3, 10, 12], ['hipThrustBand', 3, 15, 20]]),
    t('Tag C', [5], [['einbeinBruecke', 3, 10, 12], ['rdlKH', 3, 10, 12], ['maschSchulter', 3, 10, 12], ['curtsey', 3, 12, 15], ['reverseCrunch', 3, 12, 15]])]],
  ['w-po4', 'Po Aufbau 4 Tage', 'w', 'fortgeschritten', 'muskeln', 'studio', [
    t('Po schwer', [1], [['gesaessbruecke', 5, 6, 8], ['kniebeuge', 4, 6, 8], ['reverseHyper', 3, 10, 12], ['kickbackKabel', 3, 12, 15], ['klimmzugHilfe', 3, 6, 10]]),
    t('Po und Rücken', [2], [['rdl', 4, 8, 10], ['splitSquatKH', 3, 8, 10], ['rudernKabel', 3, 10, 12], ['abduktion', 4, 15, 20], ['rearRow', 3, 12, 15]]),
    t('Po Pump', [4], [['hueftheben', 4, 12, 15], ['sumoMulti', 3, 10, 12], ['pullThrough', 3, 12, 15], ['hipThrustBand', 3, 20, 25], ['ohpKH', 3, 10, 12]]),
    t('Beine und Bauch', [6], [['beinpresse', 4, 10, 12], ['stepUpLH', 3, 10, 12], ['beinbeugerLiegend', 3, 10, 12], ['adduktion', 3, 15, 20], ['beinheben', 3, 10, 15]])]],
  ['w-masch3', 'Nur Maschinen', 'w', 'einsteiger', 'muskeln', 'studio', [
    t('Beine und Po', [1], [['beinpresse', 4, 10, 12], ['beinbeugerSitzend', 3, 12, 15], ['beinstrecker', 3, 12, 15], ['abduktion', 3, 15, 20], ['adduktion', 3, 15, 20]]),
    t('Oberkörper', [3], [['latzug', 3, 10, 12], ['maschBrust', 3, 10, 12], ['rudernMaschine', 3, 10, 12], ['maschSchulter', 3, 10, 12], ['rueckenstrecker', 3, 12, 15]]),
    t('Po und Bauch', [5], [['kniebeugeMulti', 3, 10, 12], ['kickbackKabel', 3, 12, 15], ['reverseHyper', 3, 12, 15], ['abduktion', 3, 15, 20], ['crunch', 3, 15, 20]])]],
  ['w-straff4', 'Straff 4 Tage', 'w', 'mittel', 'definieren', 'studio', [
    t('Beine Kraft', [1], [['kniebeugeMulti', 4, 8, 10], ['rdl', 3, 8, 10], ['beinpresse', 3, 10, 12], ['wadenStehend', 3, 12, 15]]),
    t('Oberkörper Kraft', [2], [['latzug', 4, 8, 10], ['schraegKH', 3, 8, 10], ['rudernKH', 3, 10, 12], ['seitheben', 3, 12, 15]]),
    t('Zirkel unten', [4], [['goblet', 3, 15, 20], ['kbSwing', 3, 15, 20], ['ausfallGehend', 3, 12, 16], ['sprung', 3, 10, 15], ['bergsteiger', 3, 20, 30]]),
    t('Zirkel oben und Bauch', [5], [['liegestuetz', 3, 6, 12], ['invRow', 3, 8, 12], ['ohpStehendKH', 3, 12, 15], ['russianTwist', 3, 15, 20], ['reverseCrunch', 3, 12, 15], ['burpee', 3, 8, 10]])]],
  ['w-straff3', 'Straff Zirkel', 'w', 'einsteiger', 'definieren', 'studio', [
    t('Zirkel A', [1], [['goblet', 3, 12, 15], ['latzug', 3, 12, 15], ['bruecke', 3, 15, 20], ['bergsteiger', 3, 20, 30], ['crunch', 3, 15, 20]]),
    t('Zirkel B', [3], [['beinpresse', 3, 12, 15], ['maschBrust', 3, 12, 15], ['kbSwing', 3, 15, 20], ['seitAbduktion', 3, 15, 20], ['russianTwist', 3, 15, 20]]),
    t('Zirkel C', [5], [['stepUp', 3, 12, 15], ['rudernKabel', 3, 12, 15], ['curtsey', 3, 12, 15], ['ohpKH', 3, 12, 15], ['reverseCrunch', 3, 12, 15]])]],
  ['w-ppl6', 'Push Pull Beine 6 Tage', 'w', 'fortgeschritten', 'muskeln', 'studio', [
    t('Beine Quads', [1], [['kniebeuge', 4, 6, 10], ['hack', 3, 10, 12], ['ausfallGehend', 3, 10, 12], ['beinstrecker', 3, 12, 15], ['wadenStehend', 3, 12, 15]]),
    t('Push', [2], [['schraegKH', 3, 8, 12], ['maschSchulter', 3, 10, 12], ['seitheben', 4, 12, 15], ['butterfly', 3, 12, 15], ['pushdown', 3, 12, 15]]),
    t('Pull', [3], [['klimmzugHilfe', 3, 6, 10], ['rudernKabel', 3, 10, 12], ['latzugParallel', 3, 10, 12], ['rearRow', 3, 12, 15], ['curlKabel', 3, 12, 15]]),
    t('Beine Po', [4], [['gesaessbruecke', 4, 8, 12], ['rdl', 3, 8, 10], ['beinbeugerLiegend', 3, 10, 12], ['kickbackKabel', 3, 12, 15], ['abduktion', 3, 15, 20]]),
    t('Push leicht', [5], [['ohpKH', 3, 10, 12], ['maschBrust', 3, 12, 15], ['seithebenKabel', 3, 12, 15], ['ueberkopfTrizeps', 3, 12, 15], ['crunch', 3, 15, 20]]),
    t('Pull leicht', [6], [['latzug', 3, 10, 12], ['rudernMaschine', 3, 10, 12], ['reverseFly', 3, 12, 15], ['hammer', 3, 12, 15], ['hyper', 3, 12, 15]])]],
  ['w-kraft3', 'Stark werden', 'w', 'einsteiger', 'kraft', 'studio', [
    t('Kniebeuge', [1], [['kniebeuge', 3, 5, 5], ['ohp', 3, 5, 5], ['latzug', 3, 8, 10], ['hyper', 3, 10, 12]]),
    t('Bankdrücken', [3], [['bank', 3, 5, 5], ['rdl', 3, 6, 8], ['rudernKabel', 3, 8, 10], ['beinheben', 3, 8, 12]]),
    t('Kreuzheben', [5], [['kreuzheben', 3, 5, 5], ['frontKniebeuge', 3, 5, 8], ['klimmzugHilfe', 3, 5, 8], ['gesaessbruecke', 3, 8, 10]])]],
  ['w-kraft4', 'Kraft Ober / Unter', 'w', 'mittel', 'kraft', 'studio', [
    t('Unterkörper Kraft', [1], [['kniebeuge', 4, 4, 6], ['gesaessbruecke', 4, 5, 8], ['beinbeugerLiegend', 3, 8, 10], ['wadenStehend', 3, 10, 12]]),
    t('Oberkörper Kraft', [2], [['bank', 4, 4, 6], ['rudernLH', 4, 5, 8], ['ohpKH', 3, 6, 8], ['klimmzugHilfe', 3, 5, 8]]),
    t('Unterkörper Volumen', [4], [['sumoKreuzheben', 3, 5, 8], ['beinpresse', 3, 10, 12], ['ausfallKH', 3, 10, 12], ['abduktion', 3, 15, 20]]),
    t('Oberkörper Volumen', [5], [['schraegKH', 3, 8, 12], ['latzug', 3, 10, 12], ['seitheben', 3, 12, 15], ['rearRow', 3, 12, 15], ['pushdown', 3, 12, 15]])]],
  ['w-haltung3', 'Rücken und Haltung', 'w', 'einsteiger', 'fit', 'studio', [
    t('Rücken', [1], [['latzug', 3, 10, 12], ['rudernKabel', 3, 10, 12], ['rearRow', 3, 12, 15], ['rueckenstrecker', 3, 12, 15], ['reverseCrunch', 3, 12, 15]]),
    t('Beine und Po', [3], [['goblet', 3, 10, 12], ['rdlKH', 3, 10, 12], ['bruecke', 3, 15, 20], ['seitAbduktion', 3, 15, 20]]),
    t('Schultern und Rumpf', [5], [['ohpKH', 3, 10, 12], ['reverseFly', 3, 12, 15], ['invRow', 3, 8, 12], ['hyper', 3, 12, 15], ['russianTwist', 3, 15, 20]])]],
  ['w-taille4', 'Bauch und Taille', 'w', 'mittel', 'definieren', 'studio', [
    t('Bauch und Beine', [1], [['beinpresse', 3, 10, 12], ['beinheben', 3, 10, 15], ['russianTwist', 3, 15, 20], ['ausfallGehend', 3, 12, 16]]),
    t('Rücken und Schultern', [2], [['latzug', 4, 10, 12], ['seitheben', 4, 12, 15], ['rudernKabel', 3, 10, 12], ['reverseFly', 3, 12, 15]]),
    t('Bauch und Po', [4], [['gesaessbruecke', 4, 10, 12], ['reverseCrunch', 3, 12, 15], ['kickbackKabel', 3, 12, 15], ['crunch', 3, 15, 20], ['bergsteiger', 3, 20, 30]]),
    t('Ganzkörper leicht', [6], [['goblet', 3, 12, 15], ['maschBrust', 3, 12, 15], ['latzugParallel', 3, 12, 15], ['kbSwing', 3, 15, 20]])]],
  ['w-innen4', 'Beine innen und außen', 'w', 'mittel', 'muskeln', 'studio', [
    t('Beine außen und Po', [1], [['gesaessbruecke', 4, 8, 12], ['abduktion', 4, 15, 20], ['curtsey', 3, 12, 15], ['kickbackKabel', 3, 12, 15]]),
    t('Oberkörper', [2], obenW),
    t('Beine innen', [4], [['sumoMulti', 4, 10, 12], ['adduktion', 4, 15, 20], ['adduktionKabel', 3, 12, 15], ['beinbeugerSitzend', 3, 10, 12], ['wadenSitzend', 3, 12, 15]]),
    t('Po und Bauch', [5], [['hueftheben', 3, 12, 15], ['stepUp', 3, 10, 12], ['seitAbduktion', 3, 15, 20], ['beinheben', 3, 10, 15]])]],
  ['w-gk5', 'Ganzkörper 5 Tage kurz', 'w', 'mittel', 'fit', 'studio', [
    t('Tag 1', [1], [['kniebeugeMulti', 3, 8, 12], ['latzug', 3, 10, 12], ['crunch', 3, 15, 20]]),
    t('Tag 2', [2], [['gesaessbruecke', 3, 8, 12], ['ohpKH', 3, 10, 12], ['abduktion', 3, 15, 20]]),
    t('Tag 3', [3], [['beinpresse', 3, 10, 12], ['rudernKabel', 3, 10, 12], ['reverseCrunch', 3, 12, 15]]),
    t('Tag 4', [4], [['rdlKH', 3, 10, 12], ['maschBrust', 3, 10, 12], ['seitheben', 3, 12, 15]]),
    t('Tag 5', [5], [['stepUp', 3, 10, 12], ['klimmzugHilfe', 3, 6, 10], ['kickbackKabel', 3, 12, 15]])]],
  ['w-kh2', 'Kurzhanteln 2 Tage', 'w', 'einsteiger', 'fit', 'kurzhantel', [
    t('Tag A', [2], [['goblet', 3, 10, 12], ['rudernKH', 3, 10, 12], ['bruecke', 3, 15, 20], ['ohpStehendKH', 3, 10, 12], ['crunch', 3, 12, 15]]),
    t('Tag B', [5], [['kreuzhebenKH', 3, 10, 12], ['bankKH', 3, 10, 12], ['stepUp', 3, 10, 12], ['seitheben', 3, 12, 15], ['russianTwist', 3, 15, 20]])]],
  ['w-kh4', 'Kurzhanteln Po und Oberkörper', 'w', 'mittel', 'muskeln', 'kurzhantel', [
    t('Po und Beinbeuger', [1], [['rdlKH', 4, 10, 12], ['einbeinRdl', 3, 8, 10], ['einbeinBruecke', 3, 10, 12], ['seitAbduktion', 3, 15, 20]]),
    t('Oberkörper A', [2], [['ohpKH', 3, 10, 12], ['rudernKH', 3, 10, 12], ['seitheben', 3, 12, 15], ['kickbackKH', 3, 12, 15]]),
    t('Quads und Po', [4], [['goblet', 4, 10, 12], ['splitSquatKH', 3, 8, 10], ['stepUp', 3, 10, 12], ['wadenKH', 3, 15, 20]]),
    t('Oberkörper B', [5], [['schraegKH', 3, 10, 12], ['ueberzug', 3, 10, 12], ['reverseFlyKH', 3, 12, 15], ['hammer', 3, 12, 15], ['reverseCrunch', 3, 12, 15]])]],
  ['w-kg4', 'Ohne Geräte Po und Bauch', 'w', 'einsteiger', 'definieren', 'zuhause', [
    t('Po', [1], [['bruecke', 4, 15, 20], ['curtsey', 3, 12, 15], ['seitAbduktion', 3, 15, 20], ['einbeinBruecke', 3, 10, 12]]),
    t('Bauch', [2], [['crunch', 3, 15, 20], ['reverseCrunch', 3, 12, 15], ['russianTwist', 3, 15, 20], ['bergsteiger', 3, 20, 30]]),
    t('Beine', [4], [['ausfallGehend', 3, 12, 20], ['sprung', 3, 10, 15], ['brueckeBank', 3, 12, 15], ['eselWaden', 3, 15, 25]]),
    t('Oberkörper und Bauch', [5], [['liegestuetz', 3, 5, 12], ['bankdip', 3, 8, 12], ['hyper', 3, 12, 15], ['beinheben', 3, 8, 12]])]],
  ['w-kg5', 'Ohne Geräte jeden Werktag', 'w', 'mittel', 'fit', 'zuhause', [
    t('Po', [1], [['einbeinBruecke', 4, 10, 15], ['curtsey', 3, 12, 16], ['seitAbduktion', 3, 15, 20]]),
    t('Oberkörper', [2], [['liegestuetz', 4, 5, 12], ['bankdip', 3, 8, 12], ['hyper', 3, 12, 15]]),
    t('Bauch', [3], [['reverseCrunch', 3, 12, 15], ['russianTwist', 3, 15, 20], ['crunch', 3, 15, 20]]),
    t('Beine', [4], [['ausfallGehend', 4, 12, 20], ['sprung', 3, 10, 15], ['eselWaden', 3, 15, 25]]),
    t('Zirkel', [5], [['burpee', 3, 8, 12], ['bergsteiger', 3, 20, 30], ['bruecke', 3, 15, 20], ['liegestuetz', 3, 5, 10]])]],
];

const fehler = [];
const aus = SPLITS.map(([id, name, gruppe, level, ziel, geraet, einheiten]) => ({
  id, name, gruppe, level, ziel, geraet,
  tage: new Set(einheiten.flatMap(e => e.wochentage)).size,
  einheiten: einheiten.map(e => ({
    name: e.name, wochentage: e.wochentage,
    uebungen: e.uebungen.map(([k, saetze, von, bis]) => {
      const uid = U[k] ?? (katalog.has(k) ? k : undefined); // Kurzname oder direkt eine Katalog-id
      if (!uid) fehler.push(`${id}: Kurzname "${k}" fehlt`);
      else if (!katalog.has(uid)) fehler.push(`${id}: ${k} -> ${uid} nicht im Katalog`);
      return { uebung: uid, saetze, von, bis };
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
