#!/bin/bash
# Detect potential breaking changes in staged diff
# Returns: JSON with breaking change analysis

set -e

DIFF=$(git diff --cached 2>/dev/null || echo "")

BREAKING_DETECTED="false"
BREAKING_INDICATORS=()
SEVERITY="none"

check_pattern() {
  local pattern=$1
  local description=$2
  local severity_level=$3

  if echo "$DIFF" | grep -qi "$pattern"; then
    BREAKING_DETECTED="true"
    BREAKING_INDICATORS+=("$description")
    if [ "$severity_level" = "critical" ]; then
      SEVERITY="critical"
    elif [ "$severity_level" = "high" ] && [ "$SEVERITY" != "critical" ]; then
      SEVERITY="high"
    elif [ "$severity_level" = "medium" ] && [ "$SEVERITY" = "none" ]; then
      SEVERITY="medium"
    fi
  fi
}

# API route changes (critical)
check_pattern "^-.*app\.\(get\|post\|put\|delete\|patch\)(" "Express route removed" "critical"
check_pattern "^-.*router\.\(get\|post\|put\|delete\|patch\)(" "Router endpoint removed" "critical"

# Exported function changes (high)
check_pattern "^-.*module\.exports\|^-.*export " "Exported module/function removed" "high"

# Environment variable changes (high)
check_pattern "^-.*process\.env\." "Environment variable reference removed" "high"

# Config schema changes (high)
check_pattern "^-.*required.*:\|^-.*REQUIRED" "Required field removed" "high"

# Database/schema changes (critical)
check_pattern "migration.*drop\|DROP TABLE\|DROP COLUMN" "Database migration removes data" "critical"

# Explicitly marked (critical)
check_pattern "BREAKING CHANGE\|breaking change" "Explicitly marked as breaking change" "critical"

# Deleted files that look like public API
DELETED_FILES=$(git diff --cached --name-only --diff-filter=D 2>/dev/null || echo "")
if [ -n "$DELETED_FILES" ]; then
  if echo "$DELETED_FILES" | grep -qiE "route|endpoint|api|handler|controller"; then
    BREAKING_DETECTED="true"
    BREAKING_INDICATORS+=("API/route file deleted")
    [ "$SEVERITY" != "critical" ] && SEVERITY="high"
  fi
fi

INDICATORS_JSON="[]"
if [ ${#BREAKING_INDICATORS[@]} -gt 0 ]; then
  if command -v jq >/dev/null 2>&1; then
    INDICATORS_JSON=$(printf '%s\n' "${BREAKING_INDICATORS[@]}" | jq -R . | jq -s .)
  fi
fi

RECOMMENDATIONS=""
if [ "$BREAKING_DETECTED" = "true" ]; then
  case $SEVERITY in
    critical) RECOMMENDATIONS="Add BREAKING CHANGE: footer with migration guide. Consider deprecation period." ;;
    high) RECOMMENDATIONS="Add BREAKING CHANGE: footer or use '!' after type/scope. Document migration path." ;;
    medium) RECOMMENDATIONS="Consider if this is truly breaking. If yes, add BREAKING CHANGE: footer." ;;
  esac
fi

CONFIDENCE="low"
if [ ${#BREAKING_INDICATORS[@]} -gt 2 ]; then CONFIDENCE="high"
elif [ ${#BREAKING_INDICATORS[@]} -gt 0 ]; then CONFIDENCE="medium"
fi

cat <<EOF
{
  "breaking_detected": $BREAKING_DETECTED,
  "severity": "$SEVERITY",
  "confidence": "$CONFIDENCE",
  "indicators": $INDICATORS_JSON,
  "recommendation": "$RECOMMENDATIONS",
  "indicator_count": ${#BREAKING_INDICATORS[@]}
}
EOF
