#!/usr/bin/env python3
"""Mappa del Malandrino: rigenera l'indice di 221b e verifica le invarianti del grafo.

Uso:
  marauders_map.py indice   [cartella]            scrive indice/entita.md e indice/note-AAAA-MM.md
  marauders_map.py verifica [cartella] [--git R]  elenca le violazioni, esce con 1 se ce ne sono

Solo libreria standard. Stesso input, stesso output byte per byte.
"""
import datetime
import os
import re
import subprocess
import sys

TIPI = ["nota", "todo", "decisione", "feedback", "incidente", "meeting", "1:1", "idea"]
STATI = ["aperto", "fatto"]
LINK = re.compile(r"\[\[([^\]]*)\]\]")
LINK_ESATTO = re.compile(r"\[\[([^\[\]]+)\]\]")
RIGA_DIARIO = re.compile(r"^(a-\d{8}-\d{4}(?:-\d+)?) · ")
AVVISO = "Generato da marauders_map.py a partire dalle note: non modificare a mano.\n"


class Errore(Exception):
    pass


# --- Parser YAML minimo: chiave: valore, stringhe, liste in linea e a blocchi, booleani, null ---

def _valore(s):
    s = s.strip()
    if s == "":
        return None
    if s[0] in "\"'":
        fine = s.find(s[0], 1)
        if fine < 0:
            raise Errore(f"virgolette non chiuse in {s}")
        resto = s[fine + 1:].strip()
        if resto and not resto.startswith("#"):
            raise Errore(f"testo dopo le virgolette in {s}")
        return s[1:fine]
    if s.startswith("[["):
        raise Errore(f'i link vanno tra virgolette: scrivi "{s}"')
    if s[0] == "[":
        elementi, cur, q, chiusa = [], "", None, False
        for i, ch in enumerate(s[1:], 1):
            if q:
                cur += ch
                if ch == q:
                    q = None
            elif ch in "\"'":
                q = ch
                cur += ch
            elif ch == ",":
                elementi.append(cur)
                cur = ""
            elif ch == "]":
                chiusa = True
                resto = s[i + 1:].strip()
                if resto and not resto.startswith("#"):
                    raise Errore(f"testo dopo la lista in {s}")
                break
            else:
                cur += ch
        if not chiusa:
            raise Errore(f"lista non chiusa in {s}")
        if cur.strip():
            elementi.append(cur)
        return [_valore(e) for e in elementi if e.strip()]
    s = re.sub(r"\s+#.*$", "", s).strip()
    if s in ("true", "false"):
        return s == "true"
    if s in ("null", "~"):
        return None
    return s


def frontmatter(testo):
    """Restituisce (campi, corpo). Solleva Errore se il frontmatter manca o non è valido."""
    righe = testo.split("\n")
    if not righe or righe[0].strip() != "---":
        raise Errore("manca il frontmatter: il file deve iniziare con ---")
    try:
        fine = next(i for i in range(1, len(righe)) if righe[i].strip() == "---")
    except StopIteration:
        raise Errore("frontmatter non chiuso: manca la riga --- finale")
    campi, chiave = {}, None
    for riga in righe[1:fine]:
        if not riga.strip() or riga.lstrip().startswith("#"):
            continue
        m = re.match(r"^\s+-\s*(.*)$", riga) or re.match(r"^-\s+(.*)$", riga)
        if m and chiave is not None and (campi[chiave] is None or isinstance(campi[chiave], list)):
            if campi[chiave] is None:
                campi[chiave] = []
            campi[chiave].append(_valore(m.group(1)))
            continue
        m = re.match(r"^([A-Za-z_][\w-]*)\s*:(.*)$", riga)
        if not m:
            raise Errore(f"riga del frontmatter non valida: {riga.strip()}")
        chiave = m.group(1)
        if chiave in campi:
            raise Errore(f"campo ripetuto: {chiave}")
        campi[chiave] = _valore(m.group(2))
    return campi, "\n".join(righe[fine + 1:])


# --- Grafo ---

def _data(v, con_ora):
    if not isinstance(v, str):
        return None
    formati = ["%Y-%m-%d %H:%M", "%Y-%m-%d"] if con_ora else ["%Y-%m-%d"]
    for f in formati:
        try:
            return datetime.datetime.strptime(v.strip(), f)
        except ValueError:
            pass
    return None


def _lista(v):
    if v is None:
        return []
    return v if isinstance(v, list) else [v]


def _md(root, cartella):
    base = os.path.join(root, cartella)
    trovati = []
    for d, sotto, files in os.walk(base):
        sotto.sort()
        trovati += [os.path.relpath(os.path.join(d, f), root) for f in files if f.endswith(".md")]
    return sorted(trovati)


class Grafo:
    def __init__(self, root):
        self.root = root
        self.violazioni = set()  # (percorso, messaggio)
        self.persone, self.progetti, self.note = {}, {}, {}  # nome/stem -> (percorso, campi, corpo)
        self.corpi = {}
        for tipo, dest in (("persone", self.persone), ("progetti", self.progetti)):
            for p in _md(root, tipo):
                if os.path.dirname(p) != tipo:
                    self.v(p, f"i nodi stanno direttamente in {tipo}/, non in sottocartelle")
                    continue
                c = self._leggi(p)
                if c is not None:
                    dest[os.path.basename(p)[:-3]] = (p, c[0], c[1])
        for p in _md(root, "note"):
            c = self._leggi(p)
            if c is not None:
                self.note[os.path.basename(p)[:-3]] = (p, c[0], c[1])
        # nome o alias (minuscolo) -> {(tipo, nome canonico)}
        self.nomi = {}
        for tipo, nodi in (("persona", self.persone), ("progetto", self.progetti)):
            for nome, (p, campi, _) in nodi.items():
                for n in [nome] + [a for a in _lista(campi.get("alias")) if isinstance(a, str)]:
                    self.nomi.setdefault(n.strip().lower(), set()).add((tipo, nome, p))

    def v(self, percorso, msg):
        self.violazioni.add((percorso, msg))

    def _leggi(self, p):
        try:
            with open(os.path.join(self.root, p), encoding="utf-8") as f:
                return frontmatter(f.read())
        except UnicodeDecodeError:
            self.v(p, "il file non è in UTF-8")
        except Errore as e:
            self.v(p, str(e))
        return None

    # Risolve un nome verso i tipi ammessi ("persona", "progetto", "nota"); restituisce un errore o None.
    def risolvi(self, nome, ammessi):
        t = nome.split("|")[0].split("#")[0].strip()
        if "persona" in ammessi and t in self.persone:
            return None
        if "progetto" in ammessi and t in self.progetti:
            return None
        if "nota" in ammessi and t in self.note:
            return None
        trovati = sorted(self.nomi.get(t.lower(), set()))
        buoni = [x for x in trovati if x[0] in ammessi]
        if buoni:
            canon = buoni[0][1]
            if canon.lower() == t.lower():
                return f'"{t}" va scritto nella forma canonica: usa [[{canon}]]'
            return f'"{t}" è un alias di "{canon}": usa la forma canonica [[{canon}]]'
        if trovati:
            return f'"{t}" è un {trovati[0][0]}, ma qui serve: {" o ".join(ammessi)}'
        cosa = "questa nota" if ammessi == ["nota"] else f'"{t}"'
        return f"{cosa} non esiste nell'indice: chiedi all'utente se aggiungerlo, non inventare il nodo"

    def _campo_link(self, p, campo, valore, ammessi, singolo=False):
        valori = _lista(valore)
        if singolo and len(valori) > 1:
            self.v(p, f"{campo}: ammesso un solo valore")
        for x in valori:
            m = LINK_ESATTO.fullmatch(x.strip()) if isinstance(x, str) else None
            if not m:
                self.v(p, f'{campo}: {x!r} non è un link, scrivi "[[nome]]"')
                continue
            err = self.risolvi(m.group(1), ammessi)
            if err:
                self.v(p, f"{campo}: {err}")

    def _link_liberi(self, p, testo):
        for nome in LINK.findall(testo):
            err = self.risolvi(nome, ["persona", "progetto", "nota"])
            if err:
                self.v(p, f"link nel testo: {err}")

    def controlla(self):
        for tipo, nodi in (("persona", self.persone), ("progetto", self.progetti)):
            for nome, (p, campi, corpo) in nodi.items():
                if campi.get("nome") != nome:
                    self.v(p, f"il campo nome deve essere {nome!r}, come il nome del file")
                if nome != nome.lower():
                    self.v(p, "il nome canonico deve essere minuscolo")
                if not all(isinstance(a, str) and a.strip() for a in _lista(campi.get("alias"))):
                    self.v(p, "alias: deve essere una lista di nomi")
                if tipo == "persona":
                    self._campo_link(p, "progetti", campi.get("progetti"), ["progetto"])
                self._link_liberi(p, corpo)
        for n, possessori in sorted(self.nomi.items()):
            nodi = sorted({x[2] for x in possessori})
            if len(nodi) > 1:
                for p in nodi:
                    self.v(p, f'"{n}" appartiene a più nodi ({", ".join(nodi)}): ogni nome e alias deve essere unico')
        for stem, (p, c, corpo) in self.note.items():
            for campo in ("titolo", "tipo", "quando", "todo"):
                if campo not in c or c[campo] in (None, ""):
                    self.v(p, f"manca il campo {campo}")
            if c.get("titolo") is not None and not isinstance(c.get("titolo"), str):
                self.v(p, "titolo: deve essere un testo")
            if c.get("tipo") not in (None, "") and c.get("tipo") not in TIPI:
                self.v(p, f"tipo {c.get('tipo')!r} non ammesso: usa uno tra {', '.join(TIPI)}")
            quando = _data(c.get("quando"), True)
            if c.get("quando") not in (None, "") and not quando:
                self.v(p, f"quando {c.get('quando')!r} non è una data valida (AAAA-MM-GG HH:MM)")
            if quando and os.path.dirname(p) != f"note/{quando:%Y-%m}":
                self.v(p, f"la nota è del {quando:%Y-%m} ma sta in {os.path.dirname(p)}/: va in note/{quando:%Y-%m}/")
            todo = c.get("todo")
            if "todo" in c and not isinstance(todo, bool):
                self.v(p, "todo: deve essere true o false")
            if todo is True:
                owner = c.get("owner")
                if owner is None:
                    self.v(p, "un todo deve avere owner: io oppure \"[[persona]]\"")
                elif owner != "io":
                    self._campo_link(p, "owner", owner, ["persona"], singolo=True)
                if c.get("stato") not in STATI:
                    self.v(p, f"stato {c.get('stato')!r} non valido per un todo: usa aperto o fatto")
                if c.get("scadenza") is not None and not _data(c.get("scadenza"), False):
                    self.v(p, f"scadenza {c.get('scadenza')!r} non è una data valida (AAAA-MM-GG)")
            elif todo is False:
                for campo in ("owner", "stato", "scadenza"):
                    if campo in c:
                        self.v(p, f"todo è false ma c'è il campo {campo}: toglilo oppure metti todo: true")
                if c.get("tipo") == "todo":
                    self.v(p, "tipo todo richiede todo: true")
            self._campo_link(p, "chi", c.get("chi"), ["persona"])
            self._campo_link(p, "progetto", c.get("progetto"), ["progetto"])
            self._campo_link(p, "segue", c.get("segue"), ["nota"])
            self._campo_link(p, "blocca", c.get("blocca"), ["nota", "progetto"])
            if c.get("tags") is not None and not isinstance(c.get("tags"), list):
                self.v(p, "tags: deve essere una lista, per esempio [api, caching]")
            altri = " ".join(str(v) for k, v in c.items() if k not in ("chi", "progetto", "owner", "segue", "blocca"))
            self._link_liberi(p, altri + "\n" + corpo)

    # --- Indice ---

    def _nomi(self, valore):
        out = []
        for x in _lista(valore):
            m = LINK_ESATTO.fullmatch(x.strip()) if isinstance(x, str) else None
            if m:
                out.append(m.group(1).strip())
        return out

    def indice(self):
        righe_mese = {}
        ultima, ultimo_11, aperti = {}, {}, {}
        miei_aperti = 0
        for stem, (p, c, _) in sorted(self.note.items(), key=lambda x: (str(x[1][1].get("quando")), x[1][0])):
            quando = _data(c.get("quando"), True)
            if not quando:
                continue
            giorno = f"{quando:%Y-%m-%d}"
            chi, prog = self._nomi(c.get("chi")), self._nomi(c.get("progetto"))
            owner = c.get("owner") if c.get("todo") is True else None
            owner_nome = (self._nomi(owner) or [None])[0] if owner not in (None, "io") else owner
            coinvolti = set(chi) | ({owner_nome} if owner_nome not in (None, "io") else set())
            for n in coinvolti | set(prog):
                ultima[n] = max(ultima.get(n, ""), giorno)
            if c.get("tipo") == "1:1":
                for n in chi:
                    ultimo_11[n] = max(ultimo_11.get(n, ""), giorno)
            if c.get("todo") is True and c.get("stato") == "aperto":
                if owner_nome == "io":
                    miei_aperti += 1
                for n in ({owner_nome} - {None, "io"}) | set(prog):
                    aperti[n] = aperti.get(n, 0) + 1
            riga = " · ".join([giorno, str(c.get("tipo")), ", ".join(prog) or "—",
                               ", ".join(chi) or "—", str(c.get("titolo")), p])
            if c.get("todo") is True:
                riga += f" · todo {c.get('stato')} → {owner_nome}"
                if c.get("scadenza"):
                    riga += f", entro {c.get('scadenza')}"
            righe_mese.setdefault(f"{quando:%Y-%m}", []).append(riga)

        def cella(x):
            return str(x).replace("|", "/").replace("\n", " ") if x not in (None, "", []) else "—"

        out = ["# Indice delle entità", "", AVVISO, "## Persone", "",
               "| nome | alias | progetti | ruolo | ultima nota | ultimo 1:1 | todo aperti |",
               "| --- | --- | --- | --- | --- | --- | --- |"]
        for nome, (p, c, _) in sorted(self.persone.items()):
            out.append("| " + " | ".join(cella(x) for x in [
                nome, ", ".join(a for a in _lista(c.get("alias")) if isinstance(a, str)),
                ", ".join(self._nomi(c.get("progetti"))), c.get("ruolo"),
                ultima.get(nome), ultimo_11.get(nome), aperti.get(nome, 0)]) + " |")
        out += ["", "## Progetti", "", "| nome | alias | membri | descrizione | ultima nota | todo aperti |",
                "| --- | --- | --- | --- | --- | --- |"]
        for nome, (p, c, _) in sorted(self.progetti.items()):
            membri = [n for n, (_, pc, _) in sorted(self.persone.items()) if nome in self._nomi(pc.get("progetti"))]
            out.append("| " + " | ".join(cella(x) for x in [
                nome, ", ".join(a for a in _lista(c.get("alias")) if isinstance(a, str)), ", ".join(membri),
                c.get("descrizione"), ultima.get(nome), aperti.get(nome, 0)]) + " |")
        out += ["", f"Todo aperti con owner io: {miei_aperti}", ""]
        files = {"indice/entita.md": "\n".join(out)}
        for mese, righe in sorted(righe_mese.items()):
            files[f"indice/note-{mese}.md"] = "\n".join(
                [f"# Note di {mese}", "", AVVISO, "data · tipo · progetto · chi · titolo · file", ""] + righe) + "\n"
        return files


def _ids_git(repo):
    try:
        out = subprocess.run(["git", "-C", repo, "log", "--format=%B"], capture_output=True, text=True, check=True).stdout
    except (subprocess.CalledProcessError, FileNotFoundError):
        return set()  # repository senza commit
    return set(re.findall(r"^azione: (a-\S+)$", out, re.M))


def verifica(root, repo=None):
    g = Grafo(root)
    g.controlla()
    atteso = g.indice()
    presenti = set(_md(root, "indice"))
    for p in sorted(presenti | set(atteso)):
        try:
            with open(os.path.join(root, p), encoding="utf-8") as f:
                reale = f.read()
        except OSError:
            reale = None
        if reale != atteso.get(p):
            g.v("indice", f"{p} non coincide con le note: va rigenerato con marauders_map.py indice")
    ids = []
    for p in _md(root, "diario-di-bordo"):
        with open(os.path.join(root, p), encoding="utf-8") as f:
            ids += [m.group(1) for m in map(RIGA_DIARIO.match, f) if m]
    for i in sorted({i for i in ids if ids.count(i) > 1}):
        g.v("diario-di-bordo", f"l'azione {i} compare più volte nel diario")
    if repo is None and os.path.isdir(os.path.join(root, ".git")):
        repo = root
    if repo:
        git = _ids_git(repo)
        for i in sorted(set(ids) - git):
            g.v("diario-di-bordo", f"l'azione {i} è nel diario ma non ha un commit")
        for i in sorted(git - set(ids)):
            g.v("diario-di-bordo", f"il commit dell'azione {i} non ha la sua riga nel diario")
    return sorted(g.violazioni)


def scrivi_indice(root):
    files = Grafo(root).indice()
    os.makedirs(os.path.join(root, "indice"), exist_ok=True)
    for p in _md(root, "indice"):
        if p not in files:
            os.remove(os.path.join(root, p))
    for p, testo in files.items():
        with open(os.path.join(root, p), "w", encoding="utf-8") as f:
            f.write(testo)


def main(argv):
    if len(argv) < 2 or argv[1] not in ("indice", "verifica"):
        print(__doc__.strip(), file=sys.stderr)
        return 2
    args = argv[2:]
    repo = None
    if "--git" in args:
        i = args.index("--git")
        repo = args[i + 1]
        args = args[:i] + args[i + 2:]
    root = os.path.abspath(args[0] if args else ".")
    if argv[1] == "indice":
        scrivi_indice(root)
        return 0
    violazioni = verifica(root, repo)
    for p, msg in violazioni:
        print(f"✗ {p}: {msg}")
    return 1 if violazioni else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
