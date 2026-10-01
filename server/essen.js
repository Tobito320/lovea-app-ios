// Essen-Datenbank (Open Food Facts DACH in D1) und Name-Nachschlag bei der Open EAN Database.
export function normalisiere(roh) {
  const z = String(roh ?? "").replace(/\D/g, "");
  return z.length === 12 ? "0" + z : z;
}

function produkt(zeile) {
  if (!zeile) return null;
  return {
    code: zeile.code, name: zeile.name, marke: zeile.marke ?? null, menge: zeile.menge ?? null,
    portion_g: zeile.portion_g ?? null, portion_name: zeile.portion_name ?? null,
    pro100: JSON.parse(zeile.pro100),
  };
}

// FTS5-Anfrage aus freiem Text: nur Buchstaben/Ziffern, jedes Wort als Präfix.
function ftsAnfrage(q) {
  const woerter = String(q ?? "").toLowerCase().match(/[\p{L}\p{N}]+/gu) ?? [];
  return woerter.slice(0, 6).map((w) => `"${w}"*`).join(" ");
}

export function opengtindbParsen(text) {
  const felder = Object.fromEntries(
    text.split("\n").filter((z) => z.includes("=")).map((z) => [z.slice(0, z.indexOf("=")), z.slice(z.indexOf("=") + 1).trim()]));
  if (felder.error !== "0" || !felder.name) return null;
  return { name: felder.name, marke: felder.vendor || null };
}

async function nameNachschlagen(code, env) {
  if (!env.OPENGTINDB_ID) return Response.json({ fehler: "nicht eingerichtet" }, { status: 503 });
  const r = await fetch(`https://opengtindb.org/?ean=${code}&cmd=query&queryid=${env.OPENGTINDB_ID}`);
  const text = new TextDecoder("iso-8859-1").decode(await r.arrayBuffer());
  const treffer = opengtindbParsen(text);
  return treffer ? Response.json(treffer) : Response.json({ name: null }, { status: 404 });
}

export async function handleEssen(url, env) {
  const teile = url.pathname.split("/").filter(Boolean); // ["essen", art, wert?]
  const art = teile[1];
  if (art === "barcode") {
    const code = normalisiere(teile[2]);
    const zeile = await env.ESSEN.prepare("SELECT * FROM produkt WHERE code = ?").bind(code).first();
    return Response.json({ produkt: produkt(zeile) }, { status: zeile ? 200 : 404, headers: { "Cache-Control": "private, max-age=86400" } });
  }
  if (art === "suche") {
    const anfrage = ftsAnfrage(url.searchParams.get("q"));
    const n = Math.min(Math.max(parseInt(url.searchParams.get("n") ?? "30", 10) || 30, 1), 50);
    if (!anfrage) return Response.json({ treffer: [] });
    const { results } = await env.ESSEN.prepare(
      `SELECT p.* FROM produkt_fts f JOIN produkt p ON p.rowid = f.rowid
       WHERE produkt_fts MATCH ? ORDER BY bm25(produkt_fts) - p.beliebtheit * 0.01 LIMIT ?`).bind(anfrage, n).all();
    return Response.json({ treffer: results.map(produkt) });
  }
  if (art === "name") return nameNachschlagen(normalisiere(teile[2]), env);
  return new Response("not found", { status: 404 });
}
