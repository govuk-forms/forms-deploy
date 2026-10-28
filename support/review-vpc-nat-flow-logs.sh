#!/usr/bin/env bash
# Read-only: summarise review VPC flow logs for NAT gateway traffic.
# Usage: gds aws forms-integration-admin -- support/review-vpc-nat-flow-logs.sh [START_ISO] [END_ISO]
#   Times are UTC, e.g. 2026-10-29T07:00:00Z. Defaults to today 00:00 -> now.
export AWS_DEFAULT_REGION=eu-west-2
LG=/vpc/review/flow-logs
START=${1:-$(date -u +%Y-%m-%dT00:00:00Z)}
END=${2:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}
S=$(date -ju -f %Y-%m-%dT%H:%M:%SZ "$START" +%s)
E=$(date -ju -f %Y-%m-%dT%H:%M:%SZ "$END" +%s)
echo "window: $START -> $END UTC"

ENIS=$(aws ec2 describe-nat-gateways --filter Name=state,Values=available Name=vpc-id,Values=vpc-0ae612557d05df65a \
  --query 'NatGateways[].NatGatewayAddresses[].NetworkInterfaceId' --output text | tr '\t' '|')
echo "NAT ENIs: $ENIS"

# $1 title  $2 query  $3 row limit  $4 "dns" to reverse-resolve the first column
run() {
  echo; echo "=== $1"
  qid=$(aws logs start-query --log-group-name "$LG" --start-time "$S" --end-time "$E" --limit "$3" --query-string "$2" --query queryId --output text)
  for _ in $(seq 1 90); do
    st=$(aws logs get-query-results --query-id "$qid" --query status --output text)
    [ "$st" = Complete ] && break
    sleep 3
  done
  aws logs get-query-results --query-id "$qid" --output json | DNS="$4" python3 -I -c '
import json, os, subprocess, sys
d = json.load(sys.stdin)
print("status:", d["status"], "| scanned records:", int(d["statistics"]["recordsScanned"]))
for r in d["results"]:
    vals = [f["value"] for f in r if f["field"] != "@ptr"]
    if os.environ.get("DNS") == "dns":
        name = subprocess.run(["dig", "+short", "-x", vals[0]], capture_output=True, text=True).stdout.split("\n")[0]
        vals.append(name)
    print("  " + "  ".join(vals))'
}

PARSE='parse @message "* * * * * * * * *" as eni, src, dst, pktsrc, pktdst, dstport, proto, bytes, action'
NATF="filter eni like /^(${ENIS})\$/"
IN="filter action = 'ACCEPT' and pktsrc not like /^10\\./"

run "records per hour (is logging working?)" "stats count(*) as records by bin(1h) as hour | sort hour" 100
run "NAT ENI: GB by direction (from_private, to_private)" "$PARSE | $NATF | filter action = 'ACCEPT' | stats sum(bytes)/1000000000 as gb by (pktsrc like /^10\\./) as from_private, (pktdst like /^10\\./) as to_private" 10
run "NAT ENI: inbound GB per hour" "$PARSE | $NATF | $IN | stats sum(bytes)/1000000000 as gb by bin(1h) as hour | sort hour" 100
run "NAT ENI: inbound GB per 10 min (find the spike)" "$PARSE | $NATF | $IN | stats sum(bytes)/1000000000 as gb by bin(10m) as t | sort t" 200
run "NAT ENI: top 25 external sources of inbound GB (+ reverse DNS)" "$PARSE | $NATF | $IN | stats sum(bytes)/1000000000 as gb by pktsrc | sort gb desc" 25 dns
run "NAT ENI: top 10 /16 source ranges of inbound GB" "$PARSE | $NATF | $IN | parse pktsrc /^(?<range>\\d+\\.\\d+)\\./ | stats sum(bytes)/1000000000 as gb by range | sort gb desc" 10
