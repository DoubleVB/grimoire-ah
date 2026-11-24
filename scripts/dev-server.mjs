// Serveur de dev statique sans dependance. Usage : npm run dev (PORT=5173 par defaut).
import { createServer } from "node:http";
import { readFile, stat } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { dirname, join, extname, resolve, sep } from "node:path";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const PORT = Number(process.env.PORT) || 5173;

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".png": "image/png",
  ".webp": "image/webp",
  ".svg": "image/svg+xml",
  ".zip": "application/zip",
  ".ps1": "text/plain; charset=utf-8",
  ".md": "text/plain; charset=utf-8",
  ".lua": "text/plain; charset=utf-8",
};

async function isFile(p) {
  try { return (await stat(p)).isFile(); } catch { return false; }
}

function send(res, code, body, type = "text/plain; charset=utf-8") {
  res.writeHead(code, { "Content-Type": type, "Cache-Control": "no-store" });
  res.end(body);
}

const server = createServer(async (req, res) => {
  if (req.method !== "GET" && req.method !== "HEAD") return send(res, 405, "Methode non autorisee");
  let rel;
  try {
    rel = decodeURIComponent(new URL(req.url, "http://localhost").pathname);
  } catch {
    return send(res, 400, "Requete invalide");
  }
  if (rel.includes("\0")) return send(res, 400, "Requete invalide");

  let file;
  if (rel === "/" || rel === "") {
    file = (await isFile(join(ROOT, "index.html"))) ? join(ROOT, "index.html") : join(ROOT, "profitmancer.html");
  } else {
    file = resolve(ROOT, "." + rel);
    if (file !== ROOT && !file.startsWith(ROOT + sep)) return send(res, 403, "Acces refuse");
  }
  if (!(await isFile(file))) return send(res, 404, "404 - introuvable : " + rel);

  try {
    const data = await readFile(file);
    res.writeHead(200, {
      "Content-Type": MIME[extname(file).toLowerCase()] || "application/octet-stream",
      "Content-Length": data.length,
      "Cache-Control": "no-store",
    });
    res.end(req.method === "HEAD" ? undefined : data);
  } catch {
    send(res, 500, "Erreur de lecture");
  }
});

server.on("error", (e) => {
  console.error(e.code === "EADDRINUSE" ? `Port ${PORT} deja utilise (essayez PORT=xxxx).` : e.message);
  process.exit(1);
});
server.listen(PORT, () => console.log(`Profitmancer : http://localhost:${PORT}`));
