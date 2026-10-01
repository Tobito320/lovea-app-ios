import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { handleEssen, normalisiere, opengtindbParsen } from "./essen.js";
import { fakeD1 } from "./fake-d1.js";

const schema = readFileSync(new URL("./essen-schema.sql", import.meta.url), "utf8");
function env() {
  const ESSEN = fakeD1(schema);
  const add = (code, name, marke, kcal, bel = 0) => ESSEN.roh.prepare(
    "INSERT INTO produkt (code,name,marke,pro100,beliebtheit) VALUES (?,?,?,?,?)")
    .run(code, name, marke, JSON.stringify({ kcal, protein: 11, kohlenhydrate: 4, fett: 0.2 }), bel);
  add("4311501679715", "Skyr Natur", "Gut & Günstig", 65, 50);
  add("20123456", "Magerquark", "Milbona", 67, 10);
  add("0012345678905", "Peanut Butter", "Brand", 590, 1);
  add("4000000000001", "Käse Gouda", "Milram", 356, 5);
  return { ESSEN };
}
const hol = (pfad, e = env()) => handleEssen(new URL("https://x" + pfad), e);

test("normalisiere", () => {
  assert.equal(normalisiere(" 4311501679715 "), "4311501679715");
  assert.equal(normalisiere("012345678905"), "0012345678905");
  assert.equal(normalisiere("20123456"), "20123456");
});

test("barcode gefunden, UPC-A und EAN-8", async () => {
  const e = env();
  assert.equal((await (await hol("/essen/barcode/4311501679715", e)).json()).produkt.name, "Skyr Natur");
  assert.equal((await (await hol("/essen/barcode/012345678905", e)).json()).produkt.code, "0012345678905");
  assert.equal((await (await hol("/essen/barcode/20123456", e)).json()).produkt.marke, "Milbona");
});

test("barcode unbekannt -> 404", async () => {
  const r = await hol("/essen/barcode/1111111111111");
  assert.equal(r.status, 404);
});

test("suche: Wortanfang, Umlaute, Beliebtheit, Grenze", async () => {
  const e = env();
  const t = (await (await hol("/essen/suche?q=sky", e)).json()).treffer;
  assert.equal(t[0].code, "4311501679715");
  assert.equal(t[0].pro100.kcal, 65);
  const k = (await (await hol("/essen/suche?q=kase", e)).json()).treffer;
  assert.equal(k[0].name, "Käse Gouda");
  const leer = (await (await hol("/essen/suche?q=", e)).json()).treffer;
  assert.deepEqual(leer, []);
  const sonder = await hol('/essen/suche?q=%22%29%28*', e);
  assert.equal(sonder.status, 200);
});

test("zweimal importiert -> einmal gefunden (FTS ohne Leichen)", async () => {
  const e = env();
  const upsert = "INSERT INTO produkt (code,name,marke,pro100,beliebtheit) VALUES (?,?,?,?,?) " +
    "ON CONFLICT(code) DO UPDATE SET name=excluded.name, marke=excluded.marke, pro100=excluded.pro100";
  e.ESSEN.roh.prepare(upsert).run("4311501679715", "Skyr Natur neu", "Gut & Günstig", JSON.stringify({ kcal: 64 }), 50);
  const t = (await (await hol("/essen/suche?q=skyr", e)).json()).treffer;
  assert.equal(t.length, 1);
  assert.equal(t[0].name, "Skyr Natur neu");
  const alt = (await (await hol("/essen/suche?q=natur", e)).json()).treffer;
  assert.equal(alt.length, 1);
});

test("opengtindb Antwort parsen", () => {
  const text = "error=0\n---\nname=Skyr Natur\ndetailname=\nvendor=Gut & Günstig\n---\n";
  assert.deepEqual(opengtindbParsen(text), { name: "Skyr Natur", marke: "Gut & Günstig" });
  assert.equal(opengtindbParsen("error=1\n"), null);
});

test("name ohne ID -> 503", async () => {
  const r = await hol("/essen/name/4311501679715");
  assert.equal(r.status, 503);
});
