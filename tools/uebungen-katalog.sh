#!/usr/bin/env bash
# Builds Lovea/Sources/Health/uebungen.json: [{id, name (de), en, muskel, koerper, geraet, neben}] from
# tools/uebungen-roh.json (ExerciseDB rows) and tools/uebungen-namen-de.json ({id: German name}).
# Only exercises whose GIF was found by uebungen-laden.sh in tools/gifs/ (ExerciseDB has none for 176 ids).
set -euo pipefail
hier="$(cd "$(dirname "$0")" && pwd)"
mit="$(ls "$hier/gifs" | sed -n 's/\.gif$//p' | tr -d '\r' | jq -R . | jq -s 'map({(.): true}) | add // {}')"
jq --slurpfile de "$hier/uebungen-namen-de.json" --argjson mit "$mit" '
  def t: {
    "back":"Rücken","cardio":"Cardio","chest":"Brust","lower arms":"Unterarme","lower legs":"Waden","neck":"Nacken",
    "shoulders":"Schultern","upper arms":"Arme","upper legs":"Beine","waist":"Bauch",
    "assisted":"Assistiert","band":"Band","barbell":"Langhantel","body weight":"Körpergewicht","bosu ball":"Bosu-Ball",
    "cable":"Kabelzug","dumbbell":"Kurzhantel","elliptical machine":"Crosstrainer","ez barbell":"SZ-Stange","hammer":"Hammer",
    "kettlebell":"Kettlebell","leverage machine":"Maschine","medicine ball":"Medizinball","olympic barbell":"Olympia-Langhantel",
    "resistance band":"Widerstandsband","roller":"Rolle","rope":"Seil","skierg machine":"Ski-Ergometer","sled machine":"Schlitten",
    "smith machine":"Multipresse","stability ball":"Gymnastikball","stationary bike":"Fahrrad-Ergometer","stepmill machine":"Stepper",
    "tire":"Reifen","trap bar":"Trap-Bar","upper body ergometer":"Armergometer","weighted":"Zusatzgewicht","wheel roller":"Bauchroller",
    "abductors":"Abduktoren","abs":"Bauch","adductors":"Adduktoren","biceps":"Bizeps","calves":"Waden",
    "cardiovascular system":"Herz-Kreislauf","delts":"Schultern","forearms":"Unterarme","glutes":"Po","hamstrings":"Beinbeuger",
    "lats":"Latissimus","levator scapulae":"Schulterblattheber","pectorals":"Brust","quads":"Quadrizeps",
    "serratus anterior":"Sägemuskel","spine":"Rückenstrecker","traps":"Trapez","triceps":"Trizeps","upper back":"oberer Rücken",
    "abdominals":"Bauch","ankle stabilizers":"Sprunggelenk","ankles":"Sprunggelenke","brachialis":"Oberarmmuskel","chest":"Brust",
    "core":"Rumpf","deltoids":"Schultern","feet":"Füße","grip muscles":"Griffkraft","groin":"Leiste","hands":"Hände",
    "hip flexors":"Hüftbeuger","inner thighs":"Oberschenkel innen","latissimus dorsi":"Latissimus","lower abs":"unterer Bauch",
    "lower back":"unterer Rücken","obliques":"seitlicher Bauch","quadriceps":"Quadrizeps","rear deltoids":"hintere Schulter",
    "rhomboids":"Rautenmuskel","rotator cuff":"Rotatorenmanschette","shins":"Schienbein","soleus":"Schollenmuskel",
    "sternocleidomastoid":"Kopfwender","trapezius":"Trapez","upper chest":"obere Brust","wrist extensors":"Handgelenkstrecker",
    "wrist flexors":"Handgelenkbeuger","wrists":"Handgelenke"
  };
  def de($w): t[$w] // $w;
  [ .[] | select($mit[.exerciseId]) | {
      id: .exerciseId,
      name: ($de[0][.exerciseId] // .name),
      en: .name,
      muskel: de(.targetMuscles[0] // ""),
      koerper: de(.bodyParts[0] // ""),
      geraet: de(.equipments[0] // ""),
      neben: ([.secondaryMuscles[] | de(.)] | unique)
    } ] | sort_by(.name)
' "$hier/uebungen-roh.json" > "$hier/../Lovea/Sources/Health/uebungen.json"
echo "uebungen.json: $(jq length "$hier/../Lovea/Sources/Health/uebungen.json") Eintraege"
