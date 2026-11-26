// GitHub's webhook for the Renovate App. Asks the orchestrator for an event run
// when the dashboard or a Renovate pull request is edited, or the default branch
// is pushed. The function URL is open to the internet, so nothing is acted on
// until the delivery's signature checks out.
"use strict";

const crypto = require("node:crypto");

const DASHBOARD_TITLE = "Dependency Dashboard";
const PLACEHOLDER_SECRET = "dummy-value";
const MIN_SECRET_LENGTH = 32;
const SECRET_CACHE_MS = 5 * 60 * 1000;

// Terraform creates the secret as a placeholder, which anyone could sign with.
function isUsableSecret(secret) {
  return secret !== PLACEHOLDER_SECRET && secret.length >= MIN_SECRET_LENGTH;
}

function header(event, name) {
  return event.headers?.[name] ?? event.headers?.[name.toLowerCase()];
}

function signatureMatches(secret, rawBody, signature) {
  if (!signature) return false;
  const expected = Buffer.from(`sha256=${crypto.createHmac("sha256", secret).update(rawBody).digest("hex")}`);
  const actual = Buffer.from(signature);
  return expected.length === actual.length && crypto.timingSafeEqual(expected, actual);
}

function decide(eventName, payload, { botLogin }) {
  if (eventName !== "issues" && eventName !== "pull_request" && eventName !== "push") return { ignore: `unhandled event ${eventName}` };

  const repository = payload.repository?.full_name?.toLowerCase();

  if (eventName === "push") {
    if (payload.deleted) return { ignore: "branch deleted" };
    if (payload.ref !== `refs/heads/${payload.repository.default_branch}`) return { ignore: "not the default branch" };
    if (payload.sender?.login?.toLowerCase() === botLogin) return { ignore: "push made by the Renovate App" };
    return { repository };
  }

  if (payload.action !== "edited" || !payload.changes?.body) return { ignore: "not a body edit" };

  // Renovate rewrites the dashboard and its pull requests on every run, so
  // reacting to its own edits would loop.
  if (payload.sender?.login?.toLowerCase() === botLogin) return { ignore: "edit made by the Renovate App" };

  if (eventName === "issues") {
    const { issue } = payload;
    if (issue?.user?.login?.toLowerCase() !== botLogin) return { ignore: "issue was not opened by the Renovate App" };
    if (issue.title !== DASHBOARD_TITLE) return { ignore: "not the Dependency Dashboard" };
  } else {
    const { pull_request: pullRequest } = payload;
    if (pullRequest?.user?.login?.toLowerCase() !== botLogin) return { ignore: "pull request was not opened by the Renovate App" };
    if (!pullRequest.head?.ref?.startsWith("renovate/")) return { ignore: "not a Renovate branch" };
  }

  return { repository };
}

function createHandler({ getSecret, requestRun, config }) {
  const respond = (statusCode, message) => {
    console.log(JSON.stringify({ statusCode, message }));
    return { statusCode, body: message };
  };

  return async (event) => {
    const rawBody = event.isBase64Encoded ? Buffer.from(event.body ?? "", "base64") : Buffer.from(event.body ?? "");

    const secret = await getSecret();
    if (!isUsableSecret(secret)) return respond(503, "webhook secret is not set");

    if (!signatureMatches(secret, rawBody, header(event, "x-hub-signature-256"))) {
      return respond(401, "invalid signature");
    }

    const eventName = header(event, "x-github-event");
    if (eventName === "ping") return respond(200, "pong");

    const decision = decide(eventName, JSON.parse(rawBody.toString("utf8")), config);
    if (decision.ignore) return respond(200, `ignored: ${decision.ignore}`);

    await requestRun(decision.repository);
    return respond(202, `asked for a run for ${decision.repository}`);
  };
}

function realHandler() {
  const { SSMClient, GetParameterCommand } = require("@aws-sdk/client-ssm");
  const { LambdaClient, InvokeCommand } = require("@aws-sdk/client-lambda");
  const ssm = new SSMClient({});
  const lambda = new LambdaClient({});

  let secret;
  let fetchedAt = 0;
  return createHandler({
    config: {
      botLogin: process.env.BOT_LOGIN.toLowerCase(),
    },
    // A rejected value isn't cached, so setting the secret after the first
    // delivery takes effect on the next one.
    getSecret: async () => {
      if (secret !== undefined && Date.now() - fetchedAt <= SECRET_CACHE_MS) return secret;

      const fetched = (
        await ssm.send(new GetParameterCommand({ Name: process.env.WEBHOOK_SECRET_PARAMETER, WithDecryption: true }))
      ).Parameter.Value;
      if (!isUsableSecret(fetched)) return fetched;

      secret = fetched;
      fetchedAt = Date.now();
      return secret;
    },
    // Asynchronous, so GitHub isn't kept waiting.
    requestRun: (repository) =>
      lambda.send(
        new InvokeCommand({
          FunctionName: process.env.ORCHESTRATOR_FUNCTION,
          InvocationType: "Event",
          Payload: JSON.stringify({ action: "request", repos: [repository], mode: "event" }),
        }),
      ),
  });
}

module.exports = { createHandler, decide, handler: process.env.ORCHESTRATOR_FUNCTION ? realHandler() : undefined };
