#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}Autoglot Translate${NC}"
echo "=================="

# Validate inputs
if [ -z "$AUTOGLOT_API_KEY" ]; then
    echo -e "${RED}Error: AUTOGLOT_API_KEY is required${NC}"
    exit 1
fi

if [ -z "$TARGET_LANGUAGES" ]; then
    echo -e "${RED}Error: TARGET_LANGUAGES is required${NC}"
    exit 1
fi

API_URL="${AUTOGLOT_API_URL:-https://api.autoglot.app}"
PARALLEL="${PARALLEL_JOBS:-4}"

# Find all .xcstrings files
if [ -z "$INPUT_FILE" ]; then
    echo "Searching for .xcstrings files..."
    FILES=$(find . -name "*.xcstrings" -type f | grep -v "node_modules" | grep -v ".build" | sort)
else
    # Support glob patterns
    FILES=$(ls $INPUT_FILE 2>/dev/null || echo "")
fi

if [ -z "$FILES" ]; then
    echo -e "${YELLOW}No .xcstrings files found${NC}"
    exit 0
fi

FILE_COUNT=$(echo "$FILES" | wc -l | tr -d ' ')
echo -e "Found ${BLUE}$FILE_COUNT${NC} file(s)"
echo "Languages: $TARGET_LANGUAGES"
echo "Parallel jobs: $PARALLEL"
echo ""

# Create temp directory for results
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Convert comma-separated languages to JSON array
LANGUAGES_JSON=$(echo "$TARGET_LANGUAGES" | jq -R 'split(",")')

# Function to translate a single file
translate_file() {
    local file="$1"
    local result_file="$2"

    echo -e "${YELLOW}Translating:${NC} $file"

    # Extract source language directly from file
    local source_lang
    source_lang=$(jq -r '.sourceLanguage // "en"' "$file")

    # Build request payload using --slurpfile to avoid argument length limits
    # This reads the file content directly instead of passing it as a CLI argument
    local payload
    payload=$(jq -n \
        --slurpfile xcstrings "$file" \
        --arg source_language "$source_lang" \
        --argjson target_languages "$LANGUAGES_JSON" \
        '{
            xcstrings: $xcstrings[0],
            source_language: $source_language,
            target_languages: $target_languages
        }')

    # Make API request
    local response
    response=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $AUTOGLOT_API_KEY" \
        -d "$payload" \
        "$API_URL/v1/translate" 2>&1)

    # Extract HTTP status and body
    local http_code
    http_code=$(echo "$response" | tail -n1)
    local body
    body=$(echo "$response" | sed '$d')

    # Check for errors
    if [ "$http_code" != "200" ]; then
        local error_msg
        error_msg=$(echo "$body" | jq -r '.error // "Unknown error"' 2>/dev/null || echo "$body")
        echo -e "${RED}  Error ($http_code): $error_msg${NC}"
        echo "{\"success\": false, \"file\": \"$file\", \"error\": \"$error_msg\"}" > "$result_file"
        return 1
    fi

    # Extract results
    local chars
    chars=$(echo "$body" | jq -r '.characters_used // 0')
    local strings
    strings=$(echo "$body" | jq -r '.strings_translated // 0')

    # Write translated content back
    echo "$body" | jq -r '.xcstrings' > "$file"

    echo -e "${GREEN}  Done:${NC} $strings strings, $chars characters"
    echo "{\"success\": true, \"file\": \"$file\", \"characters\": $chars, \"strings\": $strings}" > "$result_file"
}

export -f translate_file
export API_URL AUTOGLOT_API_KEY LANGUAGES_JSON RED GREEN YELLOW NC

# Translate files in parallel
echo -e "${BLUE}Starting translations...${NC}"
echo ""

COUNTER=0
for file in $FILES; do
    COUNTER=$((COUNTER + 1))
    result_file="$TEMP_DIR/result_$COUNTER.json"

    # Run in background, limit parallelism
    translate_file "$file" "$result_file" &

    # Wait if we've hit the parallel limit
    if [ $(jobs -r | wc -l) -ge "$PARALLEL" ]; then
        wait -n 2>/dev/null || true
    fi
done

# Wait for all remaining jobs
wait

echo ""
echo -e "${GREEN}All translations complete!${NC}"
echo ""

# Aggregate results
TOTAL_FILES=0
TOTAL_CHARS=0
TOTAL_STRINGS=0
FAILED_FILES=0

for result in "$TEMP_DIR"/result_*.json; do
    if [ -f "$result" ]; then
        success=$(jq -r '.success' "$result")
        if [ "$success" = "true" ]; then
            TOTAL_FILES=$((TOTAL_FILES + 1))
            chars=$(jq -r '.characters // 0' "$result")
            strings=$(jq -r '.strings // 0' "$result")
            TOTAL_CHARS=$((TOTAL_CHARS + chars))
            TOTAL_STRINGS=$((TOTAL_STRINGS + strings))
        else
            FAILED_FILES=$((FAILED_FILES + 1))
        fi
    fi
done

echo "Summary:"
echo "  Files translated: $TOTAL_FILES"
echo "  Total strings:    $TOTAL_STRINGS"
echo "  Total characters: $TOTAL_CHARS"

if [ "$FAILED_FILES" -gt 0 ]; then
    echo -e "  ${RED}Failed files: $FAILED_FILES${NC}"
fi

# Set outputs for GitHub Actions
if [ -n "$GITHUB_OUTPUT" ]; then
    echo "files-translated=$TOTAL_FILES" >> "$GITHUB_OUTPUT"
    echo "total-characters=$TOTAL_CHARS" >> "$GITHUB_OUTPUT"
    echo "total-strings=$TOTAL_STRINGS" >> "$GITHUB_OUTPUT"
fi

# Exit with error if any files failed
if [ "$FAILED_FILES" -gt 0 ]; then
    exit 1
fi
