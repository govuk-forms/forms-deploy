"use strict";

const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const { test } = require("node:test");

const { createGitHubApp } = require("../lambda/token.js");

const { privateKey, publicKey } = crypto.generateKeyPairSync("rsa", {
  modulusLength: 2048,
  privateKeyEncoding: { type: "pkcs8", format: "pem" },
  publicKeyEncoding: { type: "spki", format: "pem" },
});

function github() {
  const calls = [];
  const fetchImpl = async (url, init = {}) => {
    calls.push({ url, init });
    const body = url.endsWith("/installation") ? { id: 77 } : { token: "ghs_scoped" };
    return { ok: true, status: 200, json: async () => body };
  };
  return { calls, fetchImpl };
}

test("a token is scoped to the one repository", async () => {
  const { calls, fetchImpl } = github();
  const { mintToken: mint } = createGitHubApp({ organisation: "govuk-forms", readApp: async () => ({ appId: "123", privateKey }), fetchImpl });

  assert.equal(await mint("govuk-forms/forms-deploy"), "ghs_scoped");
  assert.equal(calls[1].url, "https://api.github.com/app/installations/77/access_tokens");
  assert.deepEqual(JSON.parse(calls[1].init.body), { repositories: ["forms-deploy"] });
});

test("the App's JWT is signed with its key and names the App", async () => {
  const { calls, fetchImpl } = github();
  const { mintToken: mint } = createGitHubApp({ organisation: "govuk-forms", readApp: async () => ({ appId: "123", privateKey }), fetchImpl, now: () => 1_700_000_000_000 });
  await mint("govuk-forms/forms-deploy");

  const [header, claims, signature] = calls[0].init.headers.Authorization.replace("Bearer ", "").split(".");
  assert.equal(JSON.parse(Buffer.from(claims, "base64url")).iss, "123");
  assert.ok(crypto.createVerify("RSA-SHA256").update(`${header}.${claims}`).verify(publicKey, Buffer.from(signature, "base64url")));
});

test("a repository outside the organisation is refused", async () => {
  const { fetchImpl } = github();
  const { mintToken: mint } = createGitHubApp({ organisation: "govuk-forms", readApp: async () => ({ appId: "123", privateKey }), fetchImpl });
  await assert.rejects(mint("someone-else/forms-deploy"), /not in govuk-forms/);
});

test("the key is read once for several tokens", async () => {
  const { fetchImpl } = github();
  let reads = 0;
  const { mintToken: mint } = createGitHubApp({ organisation: "govuk-forms", readApp: async () => (reads += 1, { appId: "123", privateKey }), fetchImpl });
  await mint("govuk-forms/a");
  await mint("govuk-forms/b");
  assert.equal(reads, 1);
});

test("a GitHub error doesn't carry the response body", async () => {
  const { mintToken: mint } = createGitHubApp({
    organisation: "govuk-forms",
    readApp: async () => ({ appId: "123", privateKey }),
    fetchImpl: async () => ({ ok: false, status: 401, text: async () => "secret detail", json: async () => ({}) }),
  });
  await assert.rejects(mint("govuk-forms/a"), (error) => /401/.test(error.message) && !/secret detail/.test(error.message));
});

test("the installation's repositories are listed, without archived or disabled ones", async () => {
  const calls = [];
  const full = Array.from({ length: 98 }, (_, i) => ({ full_name: `govuk-forms/r${i}` }));
  const fetchImpl = async (url, init = {}) => {
    calls.push({ url, init });
    let body;
    if (url.endsWith("/installation")) body = { id: 77 };
    else if (url.endsWith("/access_tokens")) body = { token: "ghs_all" };
    else if (url.endsWith("&page=1")) body = { repositories: [...full, { full_name: "govuk-forms/old", archived: true }, { full_name: "govuk-forms/off", disabled: true }] };
    else body = { repositories: [{ full_name: "govuk-forms/Last" }] };
    return { ok: true, status: 200, json: async () => body };
  };
  const { listRepositories } = createGitHubApp({ organisation: "govuk-forms", readApp: async () => ({ appId: "123", privateKey }), fetchImpl });

  const repositories = await listRepositories();
  assert.equal(repositories.length, 99);
  assert.ok(repositories.includes("govuk-forms/Last"), "the second page is read");
  assert.ok(!repositories.includes("govuk-forms/old") && !repositories.includes("govuk-forms/off"));

  const tokenCall = calls.find((call) => call.url.endsWith("/access_tokens"));
  assert.equal(tokenCall.init.body, undefined, "the token lists repositories, so it isn't scoped to one");
  assert.equal(calls.at(-1).init.headers.Authorization, "Bearer ghs_all");
});
