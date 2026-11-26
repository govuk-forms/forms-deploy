"use strict";

const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const { test } = require("node:test");

const { createHandler, decide } = require("../lambda/index.js");

const BOT = "forms-renovate[bot]";
const REPO = "govuk-forms/forms-deploy";
const config = { botLogin: BOT };
const repository = { full_name: REPO, default_branch: "main" };

test("a push to the default branch asks for a run", () => {
  assert.deepEqual(decide("push", { repository, ref: "refs/heads/main", sender: { login: "someone" } }, config), { repository: REPO });
});

test("pushes that can't conflict a Renovate pull request are ignored", () => {
  assert.ok(decide("push", { repository, ref: "refs/heads/other" }, config).ignore);
  assert.ok(decide("push", { repository, ref: "refs/heads/main", deleted: true }, config).ignore);
  assert.ok(decide("push", { repository, ref: "refs/heads/main", sender: { login: BOT } }, config).ignore);
});

test("an edit to the Dependency Dashboard by someone else asks for a run", () => {
  const payload = {
    action: "edited",
    changes: { body: {} },
    repository,
    sender: { login: "someone" },
    issue: { user: { login: BOT }, title: "Dependency Dashboard" },
  };
  assert.deepEqual(decide("issues", payload, config), { repository: REPO });
  assert.ok(decide("issues", { ...payload, sender: { login: BOT } }, config).ignore, "the bot's own edits would loop");
  assert.ok(decide("issues", { ...payload, issue: { user: { login: BOT }, title: "Other" } }, config).ignore);
});

test("an edit to a Renovate pull request asks for a run", () => {
  const payload = {
    action: "edited",
    changes: { body: {} },
    repository,
    sender: { login: "someone" },
    pull_request: { user: { login: BOT }, head: { ref: "renovate/tflint" } },
  };
  assert.deepEqual(decide("pull_request", payload, config), { repository: REPO });
  assert.ok(decide("pull_request", { ...payload, pull_request: { user: { login: BOT }, head: { ref: "feature" } } }, config).ignore);
});

test("the handler checks the signature before acting, and asks the orchestrator for a run", async () => {
  const secret = "s".repeat(40);
  const requested = [];
  const handler = createHandler({
    config,
    getSecret: async () => secret,
    requestRun: async (repo) => requested.push(repo),
  });
  const body = JSON.stringify({ repository, ref: "refs/heads/main", sender: { login: "someone" } });
  const sign = (key) => `sha256=${crypto.createHmac("sha256", key).update(body).digest("hex")}`;
  const event = (signature) => ({ body, headers: { "x-github-event": "push", "x-hub-signature-256": signature } });

  assert.equal((await handler(event(sign("wrong")))).statusCode, 401);
  assert.deepEqual(requested, []);

  assert.equal((await handler(event(sign(secret)))).statusCode, 202);
  assert.deepEqual(requested, [REPO]);
});

test("the handler stays inactive until the secret is set, and starts at 32 characters", async () => {
  const requested = [];
  const body = JSON.stringify({ repository, ref: "refs/heads/main", sender: { login: "someone" } });
  const deliveryWith = async (secret) => {
    const handler = createHandler({ config, getSecret: async () => secret, requestRun: async (repo) => requested.push(repo) });
    const signature = `sha256=${crypto.createHmac("sha256", secret).update(body).digest("hex")}`;
    return handler({ body, headers: { "x-github-event": "push", "x-hub-signature-256": signature } });
  };

  assert.equal((await deliveryWith("dummy-value")).statusCode, 503, "the placeholder");
  assert.equal((await deliveryWith("s".repeat(31))).statusCode, 503, "one short");
  assert.deepEqual(requested, [], "a correctly signed delivery with an unusable secret does nothing");

  assert.equal((await deliveryWith("s".repeat(32))).statusCode, 202);
  assert.deepEqual(requested, [REPO]);
});
