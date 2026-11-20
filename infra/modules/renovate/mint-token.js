// Prints a GitHub App installation token for the organisation's installation,
// limited to the repositories Renovate runs against. Renovate has no built-in
// GitHub App login, and installation tokens only last an hour, so the build
// mints one each run.
"use strict";

const crypto = require("node:crypto");

const { GITHUB_APP_ID, GITHUB_APP_PRIVATE_KEY, GITHUB_ORG, GITHUB_REPOSITORIES } = process.env;
for (const [name, value] of Object.entries({ GITHUB_APP_ID, GITHUB_APP_PRIVATE_KEY, GITHUB_ORG, GITHUB_REPOSITORIES })) {
  if (!value) throw new Error(`${name} is not set`);
}

const b64url = (input) => Buffer.from(input).toString("base64url");

function appJwt() {
  const now = Math.floor(Date.now() / 1000);
  const unsigned = `${b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }))}.${b64url(
    // Backdated a minute to allow for clock drift. GitHub caps the lifetime at ten minutes.
    JSON.stringify({ iat: now - 60, exp: now + 9 * 60, iss: GITHUB_APP_ID }),
  )}`;
  // A key pasted into a single line has literal \n sequences in place of newlines.
  const key = GITHUB_APP_PRIVATE_KEY.replace(/\\n/g, "\n");
  const signature = crypto.createSign("RSA-SHA256").update(unsigned).sign(key);
  return `${unsigned}.${b64url(signature)}`;
}

async function github(path, jwt, init = {}) {
  const response = await fetch(`https://api.github.com${path}`, {
    ...init,
    headers: {
      Accept: "application/vnd.github+json",
      Authorization: `Bearer ${jwt}`,
      "X-GitHub-Api-Version": "2022-11-28",
    },
  });
  if (!response.ok) {
    throw new Error(`${init.method ?? "GET"} ${path} failed: ${response.status} ${await response.text()}`);
  }
  return response.json();
}

async function main() {
  const jwt = appJwt();
  const installation = await github(`/orgs/${GITHUB_ORG}/installation`, jwt);
  const repositories = GITHUB_REPOSITORIES.split(",").map((repo) => repo.trim().split("/").pop());
  const { token } = await github(`/app/installations/${installation.id}/access_tokens`, jwt, {
    method: "POST",
    body: JSON.stringify({ repositories }),
  });
  process.stdout.write(token);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
