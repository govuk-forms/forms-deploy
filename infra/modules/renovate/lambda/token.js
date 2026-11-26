// The GitHub App client: mints an installation token limited to one repository,
// and lists the repositories the App is installed on. The App's private key is
// read here and never reaches a build, because a build runs commands from the
// repository's own config.
"use strict";

const crypto = require("node:crypto");

const KEY_CACHE_MS = 5 * 60 * 1000;

const b64url = (input) => Buffer.from(input).toString("base64url");

function appJwt(appId, privateKey, nowMs) {
  const now = Math.floor(nowMs / 1000);
  const unsigned = `${b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }))}.${b64url(
    // Backdated a minute to allow for clock drift. GitHub caps the lifetime at ten minutes.
    JSON.stringify({ iat: now - 60, exp: now + 9 * 60, iss: appId }),
  )}`;
  // A key pasted into a single line has literal \n sequences in place of newlines.
  const key = privateKey.replace(/\\n/g, "\n");
  const signature = crypto.createSign("RSA-SHA256").update(unsigned).sign(key);
  return `${unsigned}.${b64url(signature)}`;
}

function createGitHubApp({ organisation, readApp, fetchImpl = fetch, now = Date.now }) {
  let cached;

  async function app() {
    if (!cached || cached.until <= now()) {
      cached = { ...(await readApp()), until: now() + KEY_CACHE_MS };
    }
    return cached;
  }

  async function github(path, bearer, init = {}) {
    const response = await fetchImpl(`https://api.github.com${path}`, {
      ...init,
      headers: {
        Accept: "application/vnd.github+json",
        Authorization: `Bearer ${bearer}`,
        "X-GitHub-Api-Version": "2022-11-28",
      },
    });
    if (!response.ok) {
      throw new Error(`${init.method ?? "GET"} ${path} failed: ${response.status}`);
    }
    return response.json();
  }

  async function installation() {
    const { appId, privateKey } = await app();
    const jwt = appJwt(appId, privateKey, now());
    const { id } = await github(`/orgs/${organisation}/installation`, jwt);
    return { id, jwt };
  }

  async function mintToken(repo) {
    const [owner, name] = repo.split("/");
    if (owner.toLowerCase() !== organisation.toLowerCase() || !name) {
      throw new Error(`${repo} is not in ${organisation}`);
    }
    const { id, jwt } = await installation();
    const { token } = await github(`/app/installations/${id}/access_tokens`, jwt, {
      method: "POST",
      body: JSON.stringify({ repositories: [name] }),
    });
    return token;
  }

  async function listRepositories() {
    const { id, jwt } = await installation();
    // A token for every repository the App is installed on. It only lists them,
    // and never leaves this function.
    const { token } = await github(`/app/installations/${id}/access_tokens`, jwt, { method: "POST" });

    const repositories = [];
    for (let page = 1; ; page += 1) {
      const { repositories: batch } = await github(`/installation/repositories?per_page=100&page=${page}`, token);
      repositories.push(...batch);
      if (batch.length < 100) break;
    }
    return repositories.filter((repository) => !repository.archived && !repository.disabled).map((repository) => repository.full_name);
  }

  return { mintToken, listRepositories };
}

module.exports = { createGitHubApp, appJwt };
