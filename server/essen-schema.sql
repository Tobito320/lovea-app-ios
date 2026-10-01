CREATE TABLE IF NOT EXISTS produkt (
  code TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  marke TEXT,
  menge TEXT,
  portion_g REAL,
  portion_name TEXT,
  pro100 TEXT NOT NULL,
  beliebtheit INTEGER NOT NULL DEFAULT 0
);
CREATE VIRTUAL TABLE IF NOT EXISTS produkt_fts USING fts5(name, marke, content='produkt', content_rowid='rowid', tokenize='unicode61 remove_diacritics 2');
CREATE TRIGGER IF NOT EXISTS produkt_ai AFTER INSERT ON produkt BEGIN
  INSERT INTO produkt_fts(rowid, name, marke) VALUES (new.rowid, new.name, new.marke);
END;
CREATE TRIGGER IF NOT EXISTS produkt_ad AFTER DELETE ON produkt BEGIN
  INSERT INTO produkt_fts(produkt_fts, rowid, name, marke) VALUES ('delete', old.rowid, old.name, old.marke);
END;
CREATE TRIGGER IF NOT EXISTS produkt_au AFTER UPDATE ON produkt BEGIN
  INSERT INTO produkt_fts(produkt_fts, rowid, name, marke) VALUES ('delete', old.rowid, old.name, old.marke);
  INSERT INTO produkt_fts(rowid, name, marke) VALUES (new.rowid, new.name, new.marke);
END;
