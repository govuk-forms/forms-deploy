"use strict";

const assert = require("node:assert/strict");
const { test } = require("node:test");

const { createOrchestrator } = require("../lambda/orchestrator.js");

const A = "o/a";
const B = "o/b";
const C = "o/c";
const MINUTE = 60 * 1000;

// An in-memory runs table that behaves like the DynamoDB one: a request and a
// lease live in the same row, and a claim takes one only if the other allows.
function world({ limit = 1, reject = false, failConfirm = false, hangFirstStart = false, atCapacity = false, breakRepos = [] } = {}) {
  const rows = new Map();
  const started = [];
  let clock = 1_000_000;
  let built = 0;
  let starts = 0;
  const tokens = [];
  let gate = null;
  const active = new Set();
  const row = (repo) => rows.get(repo) ?? rows.set(repo, { repo }).get(repo);
  const setPending = (r, mode, time) => {
    r.pending = mode === "full" ? "full" : (r.pending ?? "event");
    r.pendingSince ??= time;
  };
  const clearLease = (r) => {
    delete r.leaseUntil;
    delete r.buildId;
    delete r.runMode;
  };

  const installed = [A, B, C];
  let listings = 0;
  let listingFails = false;

  const db = {
    setSuspended: async (suspended) => {
      row("_control").suspended = suspended;
    },
    request: async (repo, mode, time) => setPending(row(repo), mode, time),
    all: async () => [...rows.values()].map((r) => ({ pendingSince: 0, leaseUntil: 0, ...r })),
    claim: async (repo, time, until) => {
      const r = row(repo);
      if (!r.pending || (r.leaseUntil && r.leaseUntil > time)) return undefined;
      r.leaseUntil = until;
      delete r.buildId;
      delete r.runMode;
      return { mode: r.pending, since: r.pendingSince ?? 0 };
    },
    confirm: async (repo, buildId, mode) => {
      if (failConfirm) throw new Error("throttled");
      const r = row(repo);
      Object.assign(r, { buildId, runMode: mode });
      if (r.pending === mode) {
        delete r.pending;
        delete r.pendingSince;
      }
    },
    abandon: async (repo) => delete row(repo).leaseUntil,
    release: async (buildId) => {
      for (const r of rows.values()) if (r.buildId === buildId) clearLease(r);
    },
  };

  const orchestrator = createOrchestrator({
    db,
    now: () => clock,
    listRepositories: async () => {
      listings += 1;
      if (listingFails) throw new Error("GitHub is down");
      return [...installed];
    },
    config: { concurrentBuilds: limit, leaseMs: 40 * MINUTE },
    startBuild: async (repo, mode, token) => {
      starts += 1;
      tokens.push(token);
      if (hangFirstStart && starts === 1) await new Promise(() => {});
      if (gate) await gate;
      if (reject || (atCapacity && active.size >= limit)) throw Object.assign(new Error("limit"), { name: "AccountLimitExceededException" });
      if (breakRepos.includes(repo)) throw Object.assign(new Error("no token"), { name: "Error" });
      const id = `renovate:${++built}`;
      active.add(id);
      started.push([repo, mode, id]);
      return id;
    },
  });

  return {
    rows,
    installed,
    listings: () => listings,
    failListing: (fails) => (listingFails = fails),
    started,
    tokens,
    run: orchestrator,
    tick: (ms) => (clock += ms),
    holdStarts: () => {
      let open;
      gate = new Promise((resolve) => (open = resolve));
      return () => {
        gate = null;
        open();
      };
    },
    ended: (id) =>
      (active.delete(id), orchestrator({ "detail-type": "CodeBuild Build State Change", detail: { "build-id": `arn:aws:codebuild:eu-west-2:1:build/${id}` } })),
  };
}

const request = (repos, mode) => ({ action: "request", repos, mode });
const runs = (w) => w.started.map(([repo, mode]) => `${repo}:${mode}`);

test("an event request starts an event run", async () => {
  const w = world();
  await w.run(request([A], "event"));
  assert.deepEqual(runs(w), [`${A}:event`]);
});

test("the build limit holds repos back until a build ends", async () => {
  const w = world({ limit: 1 });
  await w.run(request("all", "full"));
  assert.deepEqual(runs(w), [`${A}:full`]);

  await w.run({ action: "reconcile" });
  assert.equal(w.started.length, 1, "a sweep starts nothing while the limit is full");

  await w.ended(w.started[0][2]);
  assert.deepEqual(runs(w), [`${A}:full`, `${B}:full`]);
  await w.ended(w.started[1][2]);
  assert.deepEqual(runs(w), [`${A}:full`, `${B}:full`, `${C}:full`]);
});

test("with room, every repo starts at once", async () => {
  const w = world({ limit: 3 });
  await w.run(request("all", "full"));
  assert.equal(w.started.length, 3);
});

test("a request during a run waits, and a full request beats an event one", async () => {
  const w = world({ limit: 3 });
  await w.run(request([A], "event"));
  await w.run(request([A], "event"));
  await w.run(request([A], "full"));
  assert.equal(w.started.length, 1, "no second build for a repo that is running");
  assert.equal(w.rows.get(A).pending, "full");

  await w.ended(w.started[0][2]);
  assert.deepEqual(runs(w), [`${A}:event`, `${A}:full`]);
});

test("many requests during a run become one more run", async () => {
  const w = world({ limit: 3 });
  await w.run(request([A], "event"));
  for (let i = 0; i < 10; i += 1) await w.run(request([A], "event"));
  await w.ended(w.started[0][2]);
  assert.deepEqual(runs(w), [`${A}:event`, `${A}:event`]);
});

test("repos wait in the order they asked", async () => {
  const w = world({ limit: 1 });
  await w.run(request([B], "event"));
  w.tick(1);
  await w.run(request([A], "event"));
  w.tick(1);
  await w.ended(w.started[0][2]);
  assert.deepEqual(runs(w), [`${B}:event`, `${A}:event`]);
});

test("a rejected start puts the request back and frees the repo", async () => {
  const w = world({ reject: true });
  await w.run(request([A], "full"));
  assert.equal(w.started.length, 0);
  assert.equal(w.rows.get(A).pending, "full");
  assert.equal(w.rows.get(A).leaseUntil, undefined);
});

test("a build that started but couldn't be recorded isn't started again", async () => {
  const w = world({ limit: 3, failConfirm: true });
  await assert.rejects(w.run(request([A], "event")), /throttled/);
  w.tick(10 * MINUTE);
  await w.run({ action: "reconcile" });
  assert.equal(w.started.length, 1);
  assert.equal(w.rows.get(A).pending, "event", "the request stays until the build is recorded");
});

test("a request survives an invocation that dies while starting its build", async () => {
  const w = world({ limit: 1, hangFirstStart: true });
  w.run(request([A], "full")); // never settles, like a Lambda that times out
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(w.rows.get(A).pending, "full");
  assert.ok(w.rows.get(A).leaseUntil > 0, "the repo is claimed");

  w.tick(41 * MINUTE);
  await w.run({ action: "reconcile" });
  assert.deepEqual(runs(w), [`${A}:full`]);
  assert.equal(w.rows.get(A).pending, undefined);
});

test("a full request that arrives while a build starts gets its own run", async () => {
  const w = world({ limit: 3 });
  await w.run(request([A], "event"));
  await w.run(request([A], "full"));
  await w.ended(w.started[0][2]);
  assert.deepEqual(runs(w), [`${A}:event`, `${A}:full`]);
});

test("a lease that ran out frees a repo whose build died", async () => {
  const w = world({ limit: 1 });
  await w.run(request([A], "event"));
  w.tick(41 * MINUTE);
  await w.run(request([A], "event"));
  assert.equal(w.started.length, 2);
});

test("a build the table doesn't know releases nothing", async () => {
  const w = world({ limit: 2 });
  await w.run(request([A], "event"));
  await w.ended("renovate:unknown");
  assert.ok(w.rows.get(A).leaseUntil > 0);
});

test("a repo that isn't allowed is ignored", async () => {
  const w = world({ limit: 3 });
  await w.run(request(["x/other"], "full"));
  assert.equal(w.started.length, 0);
});

test("invocations at the same time start a repo once", async () => {
  const w = world({ limit: 3 });
  await Promise.all([w.run(request([A], "event")), w.run(request([A], "event")), w.run({ action: "reconcile" })]);
  assert.equal(w.started.length, 1);
});

test("all means every repo the App is installed on", async () => {
  const w = world({ limit: 4 });
  w.installed.push("o/d");
  await w.run(request("all", "full"));
  assert.deepEqual(runs(w).sort(), [A, B, C, "o/d"].map((repo) => `${repo}:full`).sort());
});

test("a repo the App no longer covers is not started", async () => {
  const w = world({ limit: 1 });
  await w.run(request([A], "event"));
  await w.run(request([B], "event")); // waits for A
  w.installed.splice(w.installed.indexOf(B), 1);
  w.tick(10 * MINUTE);
  await w.ended(w.started[0][2]);
  assert.deepEqual(runs(w), [`${A}:event`]);
});

test("the installed list is read once in five minutes", async () => {
  const w = world({ limit: 3 });
  await w.run(request([A], "event"));
  await w.run({ action: "reconcile" });
  assert.equal(w.listings(), 1);
  w.tick(6 * MINUTE);
  await w.run({ action: "reconcile" });
  assert.equal(w.listings(), 2);
});

test("a failed lookup falls back to the last list, and fails if there isn't one", async () => {
  const cold = world();
  cold.failListing(true);
  await assert.rejects(cold.run(request([A], "event")), /GitHub is down/);

  const w = world({ limit: 3 });
  await w.run(request([A], "event"));
  w.failListing(true);
  w.tick(10 * MINUTE);
  await w.run(request([B], "event"));
  assert.deepEqual(runs(w), [`${A}:event`, `${B}:event`]);
});

test("while suspended requests are kept and nothing starts, and resume starts them", async () => {
  const w = world({ limit: 3 });
  await w.run({ action: "suspend" });
  await w.run(request("all", "full"));
  await w.run({ action: "reconcile" });
  assert.equal(w.started.length, 0);
  assert.equal(w.rows.get(A).pending, "full", "the request is kept");

  await w.run({ action: "resume" });
  assert.deepEqual(runs(w), [`${A}:full`, `${B}:full`, `${C}:full`]);
});

test("a build that ends while suspended still frees its repo", async () => {
  const w = world({ limit: 3 });
  await w.run(request([A], "event"));
  await w.run({ action: "suspend" });
  await w.ended(w.started[0][2]);
  assert.equal(w.rows.get(A).buildId, undefined);
});

test("the suspend switch is not a repo", async () => {
  const w = world({ limit: 1 });
  await w.run({ action: "suspend" });
  await w.run({ action: "resume" });
  await w.run(request([A], "event"));
  assert.deepEqual(runs(w), [`${A}:event`], "the control row doesn't take the build slot");
});

test("a start that fails for another reason doesn't block the other repos, and is raised", async () => {
  const w = world({ limit: 3, breakRepos: [A] });
  await assert.rejects(w.run(request("all", "full")), /no token/);
  assert.deepEqual(runs(w), [`${B}:full`, `${C}:full`]);
  assert.equal(w.rows.get(A).pending, "full", "the broken repo stays pending");
  assert.equal(w.rows.get(A).leaseUntil, undefined);
});

test("a start failure is still raised when the build limit stops the pass", async () => {
  const w = world({ limit: 1, breakRepos: [A] });
  await assert.rejects(w.run(request("all", "full")), /no token/);
  assert.deepEqual(runs(w), [`${B}:full`]);
  assert.equal(w.rows.get(C).pending, "full", "the repo held back at the limit stays pending");
});

test("a retried start of the same request carries the same idempotency token", async () => {
  const w = world({ limit: 3, reject: true });
  await w.run(request([A], "full"));
  await w.run(request([A], "full"));
  assert.equal(w.tokens.length, 2);
  assert.equal(w.tokens[0], w.tokens[1]);
  assert.match(w.tokens[0], /^o\/a\/full\/\d+$/);
});

test("two invocations for different repos at the limit start one, and the other waits without failing", async () => {
  const w = world({ limit: 1, atCapacity: true });
  await Promise.all([w.run(request([A], "full")), w.run(request([B], "full"))]);
  assert.equal(w.started.length, 1, "CodeBuild's limit holds");
  const waiting = [A, B].filter((repo) => w.rows.get(repo).pending && !w.rows.get(repo).leaseUntil);
  assert.equal(waiting.length, 1, "the other repo is pending with no lease");
});

test("a late end event for an old build doesn't release the lease that replaced it", async () => {
  const w = world({ limit: 1 });
  await w.run(request([A], "event"));
  const [, , oldBuild] = w.started[0];
  w.tick(41 * MINUTE); // the lease runs out, with no end event

  const open = w.holdStarts();
  const second = w.run(request([A], "event")); // claims A, then waits in startBuild
  await new Promise((resolve) => setImmediate(resolve));
  await w.ended(oldBuild); // the old build's end event arrives late
  assert.ok(w.rows.get(A).leaseUntil > 0, "the new claim keeps its lease");
  open();
  await second;
  assert.equal(w.started.length, 2);
});
