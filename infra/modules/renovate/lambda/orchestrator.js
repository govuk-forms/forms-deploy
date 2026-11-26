// Decides when Renovate builds start. Each repo has one row in a DynamoDB table:
//
//   pending     "event" or "full" once a run has been asked for. Requests for a
//               repo collapse into one, and full wins over event. It stays until
//               the build is recorded, so a request survives an invocation that
//               dies while starting one.
//   leaseUntil  set from the moment a repo is claimed, so it isn't started
//               again. It only runs out if a build dies without CodeBuild
//               reporting it.
//   buildId     the build that holds the lease.
//
// Invoked with { action: "request", repos: [...] | "all", mode } by the webhook
// and the schedule, with CodeBuild's state change event when a build ends, and
// with { action: "reconcile" } by a timer, to start anything a missed event left
// behind. Each invocation ends by starting every pending repo without a live
// lease, up to the build limit. The start is a conditional update, so two
// invocations can't start the same repo.
//
// The repos are the ones the GitHub App is installed on. { action: "suspend" }
// stops anything starting, and { action: "resume" } lets it. Requests made in
// between are kept and run on resume.
//
// A full run may open new pull requests. An event run, from a push or a tick,
// only updates existing ones, and a new branch waits for a tick on the dashboard.
"use strict";

const { createGitHubApp } = require("./token.js");

const FULL = "full";
const EVENT = "event";

// The row that holds the suspend switch. No repo has a name without a slash.
const CONTROL = "_control";
const REPOSITORIES_CACHE_MS = 5 * 60 * 1000;

// CodeBuild turns a start away with this when it is at its concurrent limit.
// Anything else that goes wrong while starting is a failure to report.
const AT_THE_LIMIT = "AccountLimitExceededException";

// Renovate's global "force" overrides repository config. New branches wait for
// approval on the dashboard, and nothing else about a pull request changes, so
// its body stays the same.
const EVENT_RUN_FORCE = JSON.stringify({ dependencyDashboardApproval: true });

function buildIdFromEvent(event) {
  // The event names the build by ARN: arn:aws:codebuild:region:account:build/project:id
  return String(event.detail?.["build-id"] ?? "").split("build/").pop();
}

function createOrchestrator({ db, startBuild, listRepositories, config, now = Date.now }) {
  let installed;
  let installedAt = 0;

  // A failed lookup falls back to the last list, so GitHub having a bad minute
  // doesn't stop runs.
  async function allowedRepositories() {
    if (installed && now() - installedAt < REPOSITORIES_CACHE_MS) return installed;
    try {
      installed = (await listRepositories()).map((repo) => repo.toLowerCase());
      installedAt = now();
    } catch (error) {
      if (!installed) throw error;
      console.log(JSON.stringify({ result: "repository list failed, using the last one", error: error.name }));
    }
    return installed;
  }

  function repositoriesIn(request, allowed) {
    if (request.repos === "all") return [...allowed];
    if (!Array.isArray(request.repos)) return [];
    return request.repos.map((repo) => String(repo).toLowerCase()).filter((repo) => allowed.includes(repo));
  }

  async function reconcile() {
    const items = await db.all();
    if (items.find((item) => item.repo === CONTROL)?.suspended) {
      console.log(JSON.stringify({ result: "suspended", waiting: items.filter((item) => item.pending).length }));
      return;
    }

    const allowed = await allowedRepositories();
    const time = now();
    const held = (item) => item.leaseUntil > time;

    const failures = [];
    let running = items.filter(held).length;
    const waiting = items.filter((item) => allowed.includes(item.repo) && item.pending && !held(item)).sort((a, b) => a.pendingSince - b.pendingSince);

    for (const item of waiting) {
      if (running >= config.concurrentBuilds) {
        console.log(JSON.stringify({ result: "at the build limit", running, waiting: waiting.length }));
        break;
      }

      const claimed = await db.claim(item.repo, time, time + config.leaseMs);
      if (!claimed) continue; // another invocation started it
      const { mode, since } = claimed;

      let buildId;
      try {
        // A start that timed out may still have been accepted. CodeBuild returns
        // the same build for a repeated token for five minutes, so freeing the
        // lease below can't start a second build for the same request.
        buildId = await startBuild(item.repo, mode, `${item.repo}/${mode}/${since}`);
      } catch (error) {
        // The request is still pending, so freeing the repo is enough: the next
        // build to end or the next sweep tries again.
        await db.abandon(item.repo);
        if (error.name === AT_THE_LIMIT) {
          console.log(JSON.stringify({ result: "at CodeBuild's limit", repo: item.repo }));
          break; // nothing else can start either
        }
        // Another repo may still start, and the failure is raised at the end so
        // that the Lambda's own alarm sees it.
        console.log(JSON.stringify({ result: "start failed", repo: item.repo, error: error.name }));
        failures.push(error);
        continue;
      }

      // If this fails the build is running and unrecorded. The lease stays, so
      // the repo isn't started twice, and the error reaches the alarm.
      await db.confirm(item.repo, buildId, mode);
      running += 1;
      console.log(JSON.stringify({ result: "started", repo: item.repo, mode, buildId }));
    }

    if (failures.length > 0) throw failures[0];
  }

  return async (event) => {
    if (event?.action === "suspend" || event?.action === "resume") {
      await db.setSuspended(event.action === "suspend");
      console.log(JSON.stringify({ result: event.action === "suspend" ? "suspend set" : "suspend cleared" }));
    } else if (event?.action === "request") {
      const mode = event.mode === EVENT ? EVENT : FULL;
      for (const repo of repositoriesIn(event, await allowedRepositories())) await db.request(repo, mode, now());
    } else if (event?.["detail-type"] === "CodeBuild Build State Change") {
      const buildId = buildIdFromEvent(event);
      if (buildId) await db.release(buildId);
    }
    await reconcile();
  };
}

function realOrchestrator() {
  const { CodeBuildClient, StartBuildCommand } = require("@aws-sdk/client-codebuild");
  const { DynamoDBClient, ScanCommand, UpdateItemCommand } = require("@aws-sdk/client-dynamodb");
  const { GetParametersCommand, PutParameterCommand, SSMClient } = require("@aws-sdk/client-ssm");
  const codebuild = new CodeBuildClient({});
  const dynamodb = new DynamoDBClient({});
  const ssm = new SSMClient({});

  const table = process.env.TABLE_NAME;
  const projectName = process.env.PROJECT_NAME;
  // Each repo caches under its own prefix, so builds for different repos can't
  // overwrite one another's cache.
  const cacheLocation = process.env.CACHE_LOCATION;

  const { mintToken, listRepositories } = createGitHubApp({
    organisation: process.env.GITHUB_ORG,
    readApp: async () => {
      const names = [process.env.APP_ID_PARAMETER, process.env.APP_KEY_PARAMETER];
      const { Parameters } = await ssm.send(new GetParametersCommand({ Names: names, WithDecryption: true }));
      const value = (name) => Parameters.find((parameter) => parameter.Name === name)?.Value;
      return { appId: value(names[0]), privateKey: value(names[1]) };
    },
  });
  // The build reads the token from a parameter, so it isn't in the build's
  // record or in CloudTrail. A repo's next build overwrites it.
  const tokenParameter = (repo) => `${process.env.TOKEN_PARAMETER_PREFIX}/${repo}`;

  const key = (repo) => ({ repo: { S: repo } });
  const update = (repo, expression, values, condition) =>
    dynamodb.send(
      new UpdateItemCommand({
        TableName: table,
        Key: key(repo),
        UpdateExpression: expression,
        ExpressionAttributeValues: values,
        ...(condition && { ConditionExpression: condition }),
        ReturnValues: "ALL_OLD",
      }),
    );
  const lost = (error) => error.name === "ConditionalCheckFailedException";

  const setPending = (mode, time) =>
    mode === FULL
      ? { expression: "SET pending = :mode, pendingSince = if_not_exists(pendingSince, :time)", values: { ":mode": { S: FULL }, ":time": { N: String(time) } } }
      : { expression: "SET pending = if_not_exists(pending, :mode), pendingSince = if_not_exists(pendingSince, :time)", values: { ":mode": { S: EVENT }, ":time": { N: String(time) } } };

  const db = {
    request: async (repo, mode, time) => {
      const { expression, values } = setPending(mode, time);
      await update(repo, expression, values);
    },
    all: async () => {
      const items = [];
      let start;
      do {
        const page = await dynamodb.send(new ScanCommand({ TableName: table, ExclusiveStartKey: start, ConsistentRead: true }));
        for (const item of page.Items ?? []) {
          items.push({
            repo: item.repo.S,
            pending: item.pending?.S,
            pendingSince: Number(item.pendingSince?.N ?? 0),
            leaseUntil: Number(item.leaseUntil?.N ?? 0),
            suspended: item.suspended?.BOOL,
            buildId: item.buildId?.S,
          });
        }
        start = page.LastEvaluatedKey;
      } while (start);
      return items;
    },
    setSuspended: async (suspended) => {
      await update(CONTROL, "SET suspended = :suspended", { ":suspended": { BOOL: suspended } });
    },
    claim: async (repo, time, leaseUntil) => {
      try {
        const { Attributes } = await update(
          repo,
          "SET leaseUntil = :lease REMOVE buildId, runMode",
          { ":lease": { N: String(leaseUntil) }, ":time": { N: String(time) } },
          "attribute_exists(pending) AND (attribute_not_exists(leaseUntil) OR leaseUntil <= :time)",
        );
        return Attributes?.pending?.S ? { mode: Attributes.pending.S, since: Number(Attributes.pendingSince?.N ?? 0) } : undefined;
      } catch (error) {
        if (lost(error)) return undefined;
        throw error;
      }
    },
    confirm: async (repo, buildId, mode) => {
      const build = { ":build": { S: buildId }, ":mode": { S: mode } };
      try {
        // A request that arrived while the build started is for another run.
        await update(repo, "SET buildId = :build, runMode = :mode REMOVE pending, pendingSince", build, "pending = :mode");
      } catch (error) {
        if (!lost(error)) throw error;
        await update(repo, "SET buildId = :build, runMode = :mode", build);
      }
    },
    abandon: async (repo) => {
      await update(repo, "REMOVE leaseUntil");
    },
    release: async (buildId) => {
      for (const item of await db.all()) {
        if (item.buildId !== buildId) continue;
        try {
          await update(item.repo, "REMOVE leaseUntil, buildId, runMode", { ":build": { S: buildId } }, "buildId = :build");
        } catch (error) {
          if (!lost(error)) throw error;
        }
      }
    },
  };

  return createOrchestrator({
    db,
    listRepositories,
    config: {
      concurrentBuilds: Number(process.env.CONCURRENT_BUILDS),
      leaseMs: Number(process.env.LEASE_MINUTES) * 60 * 1000,
    },
    startBuild: async (repo, mode, idempotencyToken) => {
      await ssm.send(
        new PutParameterCommand({ Name: tokenParameter(repo), Value: await mintToken(repo), Type: "SecureString", Overwrite: true }),
      );
      const overrides = [
        { name: "RENOVATE_REPOSITORIES", value: repo, type: "PLAINTEXT" },
        { name: "RENOVATE_TOKEN", value: tokenParameter(repo), type: "PARAMETER_STORE" },
      ];
      if (mode === EVENT) overrides.push({ name: "RENOVATE_FORCE", value: EVENT_RUN_FORCE, type: "PLAINTEXT" });
      const { build } = await codebuild.send(
        new StartBuildCommand({
          projectName,
          idempotencyToken,
          environmentVariablesOverride: overrides,
          cacheOverride: { type: "S3", location: `${cacheLocation}/${repo}` },
        }),
      );
      return build.id;
    },
  });
}

const configured =
  process.env.TABLE_NAME &&
  process.env.PROJECT_NAME &&
  process.env.CACHE_LOCATION &&
  process.env.GITHUB_ORG &&
  process.env.APP_ID_PARAMETER &&
  process.env.APP_KEY_PARAMETER &&
  process.env.TOKEN_PARAMETER_PREFIX;

module.exports = { createOrchestrator, handler: configured ? realOrchestrator() : undefined };
