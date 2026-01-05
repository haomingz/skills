# Conversion Verification Guide

This guide provides detailed scripts and procedures for verifying that your Grafana JSON to Jsonnet conversion is complete and accurate.

## Contents
- Overview
- Step 1: Create inventory from source JSON
- Step 2: Panel count verification
- Step 3: Variable completeness check
- Step 4: Row structure and row membership verification
- Step 5: Complete verification script
- Step 6: Visual verification in Grafana
- Step 7: Debugging missing elements
- Feedback loop process
- Quick reference: Common jq patterns

## Overview

After converting a dashboard, run these verification checks to ensure:
- All panels from the source JSON are present
- All variables are converted
- Row structure is preserved
- No elements are missing or duplicated

## Step 1: Create inventory from source JSON

Before starting conversion, run these commands to document the source dashboard's structure:

```bash
INPUT_JSON="input-dashboard.json"

echo "=== Source Dashboard Inventory ==="

# Total panels (including those nested in rows)
echo -e "\nTotal panels (including in rows):"
jq '[.panels[] | if .type == "row" then (.panels // [])[] else . end | select(.type != "row")] | length' $INPUT_JSON

# Top-level panel count
echo "Top-level panels:"
jq '.panels | length' $INPUT_JSON

# Row count
echo "Rows:"
jq '[.panels[] | select(.type == "row")] | length' $INPUT_JSON

# List all row titles
echo -e "\nRow titles:"
jq -r '.panels[] | select(.type == "row") | .title' $INPUT_JSON

# Variable count
echo -e "\nVariables:"
jq '.templating.list | length' $INPUT_JSON

# List all variable names
echo "Variable names:"
jq -r '.templating.list[].name' $INPUT_JSON

# Datasources used
echo -e "\nDatasources:"
jq -r '[.panels[].datasource.type // "null"] | unique | .[]' $INPUT_JSON
```

Save this output for comparison after conversion.

## Step 2: Panel count verification

After conversion, verify that all panels were converted:

```bash
INPUT_JSON="input-dashboard.json"
OUTPUT_JSONNET="output-dashboard.jsonnet"

# Count panels in source (excluding row objects)
SOURCE_PANELS=$(jq '[.panels[] | if .type == "row" then (.panels // [])[] else . end | select(.type != "row")] | length' $INPUT_JSON)

# Count panel definitions in Jsonnet
JSONNET_PANELS=$(grep -c "local .*Panel = panels\." $OUTPUT_JSONNET)

echo "Source panels: $SOURCE_PANELS"
echo "Jsonnet panels: $JSONNET_PANELS"

if [ "$SOURCE_PANELS" == "$JSONNET_PANELS" ]; then
  echo "✓ Panel count matches"
else
  echo "✗ ERROR: Panel count mismatch! Missing $(($SOURCE_PANELS - $JSONNET_PANELS)) panels"

  # List panels in source for debugging
  echo -e "\nSource panel titles:"
  jq -r '[.panels[] | if .type == "row" then (.panels // [])[] else . end | select(.type != "row") | .title] | .[]' $INPUT_JSON
fi
```

## Step 3: Variable completeness check

Verify all variables were converted:

```bash
INPUT_JSON="input-dashboard.json"
OUTPUT_JSONNET="output-dashboard.jsonnet"

# Extract variable names from source
jq -r '.templating.list[].name' $INPUT_JSON | sort > /tmp/source_vars.txt

# Extract variable names from Jsonnet
# This looks for variable definitions like: g.dashboard.variable.query.new('name', ...)
grep "g.dashboard.variable" $OUTPUT_JSONNET | grep -oP "(?<=')[^']+(?=')" | sort > /tmp/jsonnet_vars.txt

echo "Source variables:"
cat /tmp/source_vars.txt

echo -e "\nJsonnet variables:"
cat /tmp/jsonnet_vars.txt

echo -e "\nComparison:"
if diff /tmp/source_vars.txt /tmp/jsonnet_vars.txt > /dev/null; then
  echo "✓ All variables converted"
else
  echo "✗ ERROR: Variable mismatch!"
  echo "Missing variables:"
  diff /tmp/source_vars.txt /tmp/jsonnet_vars.txt
fi

# Cleanup
rm -f /tmp/source_vars.txt /tmp/jsonnet_vars.txt
```

### Step 3.1: Duplicate and extra variable detection

Detect duplicate variable definitions and extra variables that were not in the source JSON:

```bash
INPUT_JSON="input-dashboard.json"
OUTPUT_JSONNET="output-dashboard.jsonnet"

# Normalize variable lists
jq -r '.templating.list[].name' $INPUT_JSON | sort > /tmp/source_vars.txt
grep "g.dashboard.variable" $OUTPUT_JSONNET | grep -oP "(?<=')[^']+(?=')" | sort > /tmp/jsonnet_vars_raw.txt

# Duplicates in Jsonnet
sort /tmp/jsonnet_vars_raw.txt | uniq -d > /tmp/jsonnet_vars_dups.txt

# Extra variables (in Jsonnet but not in source)
comm -13 /tmp/source_vars.txt <(sort /tmp/jsonnet_vars_raw.txt | uniq) > /tmp/jsonnet_vars_extra.txt

echo "Duplicate variables in Jsonnet:"
cat /tmp/jsonnet_vars_dups.txt

echo -e "\nExtra variables in Jsonnet (not in source):"
cat /tmp/jsonnet_vars_extra.txt

# Cleanup
rm -f /tmp/source_vars.txt /tmp/jsonnet_vars_raw.txt /tmp/jsonnet_vars_dups.txt /tmp/jsonnet_vars_extra.txt
```

### Step 3.2: Regex filter preservation and necessity (heuristic)

If the source variable uses `regex`, ensure the Jsonnet output preserves it. Prefer checking the compiled JSON output.

To generate compiled JSON:
```bash
jsonnet -J vendor output-dashboard.jsonnet > output-dashboard.json
```

```bash
INPUT_JSON="input-dashboard.json"
COMPILED_JSON="output-dashboard.json"

# Variables that require regex in source
jq -r '.templating.list[] | select(.regex != null and .regex != "") | .name' $INPUT_JSON | sort > /tmp/source_regex_vars.txt

# Variables that still have regex in compiled output
jq -r '.templating.list[] | select(.regex != null and .regex != "") | .name' $COMPILED_JSON | sort > /tmp/output_regex_vars.txt

echo "Source regex variables:"
cat /tmp/source_regex_vars.txt

echo -e "\nOutput regex variables:"
cat /tmp/output_regex_vars.txt

echo -e "\nMissing regex in output:"
comm -23 /tmp/source_regex_vars.txt /tmp/output_regex_vars.txt

rm -f /tmp/source_regex_vars.txt /tmp/output_regex_vars.txt
```

Heuristic warning for variables that likely need regex filters (high-cardinality labels). Review these manually:

```bash
jq -r '.templating.list[]
  | select(.query != null)
  | select(.query | test("label_values\\([^,]+, *(pod|instance|ip|host|node|url|path)\\)"))
  | .name' input-dashboard.json
```

If any of these variables return excessive values or include unwanted suffixes, add a `regex` filter in Jsonnet to constrain the options.

### Step 3.3: Variable value availability (Grafana UI)

After import, open each variable dropdown in Grafana:
- Variables must return non-empty values.
- If empty, check datasource UID, query syntax, and regex filters.

## Step 4: Row structure and row membership verification

Verify rows are present and named correctly:

```bash
INPUT_JSON="input-dashboard.json"
OUTPUT_JSONNET="output-dashboard.jsonnet"

# Count rows in source
SOURCE_ROWS=$(jq '[.panels[] | select(.type == "row")] | length' $INPUT_JSON)

# Count row definitions in Jsonnet
JSONNET_ROWS=$(rg -c "panels\\.rowPanel\\(|g\\.panel\\.row\\.new|type: 'row'" $OUTPUT_JSONNET)

echo "Source rows: $SOURCE_ROWS"
echo "Jsonnet rows: $JSONNET_ROWS"

if [ "$SOURCE_ROWS" == "$JSONNET_ROWS" ]; then
  echo "✓ Row count matches"
else
  echo "✗ WARNING: Row count mismatch"
fi

echo -e "\nSource row titles:"
jq -r '.panels[] | select(.type == "row") | .title' $INPUT_JSON

echo -e "\nJsonnet row definitions:"
rg "panels\\.rowPanel\\(|g\\.panel\\.row\\.new|type: 'row'" $OUTPUT_JSONNET
```

### Step 4.1: Row membership verification (compiled JSON)

Use compiled JSON to verify panels are attached to the correct row (by `gridPos.y`):

```bash
COMPILED_JSON="output-dashboard.json"

# Rows with no panels at matching Y
jq -r '
  [ .panels[] | select(.type=="row") | {title, y: .gridPos.y} ] as $rows
  | [ .panels[] | select(.type!="row") | .gridPos.y ] as $ys
  | $rows[]
  | select(.y as $y | ($ys | index($y) | not))
  | "\(.title) (y=\(.y))"
' $COMPILED_JSON

# Panels that are not aligned to any row Y
jq -r '
  [ .panels[] | select(.type=="row") | .gridPos.y ] as $rows
  | [ .panels[] | select(.type!="row") | {title, y: .gridPos.y} ] as $panels
  | $panels[]
  | select($rows | index(.y) | not)
  | "\(.title) (y=\(.y))"
' $COMPILED_JSON
```

## Step 5: Complete verification script

Combine all checks into a single verification script:

```bash
#!/bin/bash
# verify-conversion.sh
# Run this after conversion to verify completeness.
# Optional 3rd argument: compiled JSON output for regex/row membership checks.

INPUT_JSON="${1:-input-dashboard.json}"
OUTPUT_JSONNET="${2:-output-dashboard.jsonnet}"
COMPILED_JSON="${3:-}"

if [ ! -f "$INPUT_JSON" ]; then
  echo "Error: Input JSON file not found: $INPUT_JSON"
  exit 1
fi

if [ ! -f "$OUTPUT_JSONNET" ]; then
  echo "Error: Output Jsonnet file not found: $OUTPUT_JSONNET"
  exit 1
fi

echo "=== Conversion Completeness Verification ==="
echo "Input: $INPUT_JSON"
echo "Output: $OUTPUT_JSONNET"

ERRORS=0

# 1. Panel count verification
echo -e "\n1. Panel Count Verification:"
SOURCE_PANELS=$(jq '[.panels[] | if .type == "row" then (.panels // [])[] else . end | select(.type != "row")] | length' $INPUT_JSON)
JSONNET_PANELS=$(grep -c "local .*Panel = panels\." $OUTPUT_JSONNET)

echo "Source panels: $SOURCE_PANELS"
echo "Jsonnet panels: $JSONNET_PANELS"

if [ "$SOURCE_PANELS" == "$JSONNET_PANELS" ]; then
  echo "✓ Panel count matches"
else
  echo "✗ ERROR: Panel count mismatch! Missing $(($SOURCE_PANELS - $JSONNET_PANELS)) panels"
  ERRORS=$((ERRORS + 1))
fi

# 2. Variable verification
echo -e "\n2. Variable Verification:"
SOURCE_VARS=$(jq '.templating.list | length' $INPUT_JSON)
JSONNET_VARS=$(grep -c "g.dashboard.variable" $OUTPUT_JSONNET)

echo "Source variables: $SOURCE_VARS"
echo "Jsonnet variables: $JSONNET_VARS"

if [ "$SOURCE_VARS" == "$JSONNET_VARS" ]; then
  echo "✓ Variable count matches"
else
  echo "✗ ERROR: Variable count mismatch!"

  echo "Source variables:"
  jq -r '.templating.list[].name' $INPUT_JSON | sort

  echo "Jsonnet variables:"
  grep "g.dashboard.variable" $OUTPUT_JSONNET | grep -oP "(?<=')[^']+(?=')" | sort

  ERRORS=$((ERRORS + 1))
fi

# 2.1 Duplicate/extra variables
echo -e "\n2.1 Duplicate/Extra Variables:"
jq -r '.templating.list[].name' $INPUT_JSON | sort > /tmp/source_vars.txt
grep "g.dashboard.variable" $OUTPUT_JSONNET | grep -oP "(?<=')[^']+(?=')" | sort > /tmp/jsonnet_vars_raw.txt

DUP_VARS=$(sort /tmp/jsonnet_vars_raw.txt | uniq -d | wc -l | tr -d ' ')
EXTRA_VARS=$(comm -13 /tmp/source_vars.txt <(sort /tmp/jsonnet_vars_raw.txt | uniq) | wc -l | tr -d ' ')

if [ "$DUP_VARS" -eq 0 ] && [ "$EXTRA_VARS" -eq 0 ]; then
  echo "✓ No duplicate or extra variables"
else
  echo "✗ WARNING: Duplicate or extra variables detected"
  echo "Duplicates:"
  sort /tmp/jsonnet_vars_raw.txt | uniq -d
  echo "Extras:"
  comm -13 /tmp/source_vars.txt <(sort /tmp/jsonnet_vars_raw.txt | uniq)
fi

rm -f /tmp/source_vars.txt /tmp/jsonnet_vars_raw.txt

# 2.2 Regex preservation (optional; requires compiled JSON)
if [ -n "$COMPILED_JSON" ] && [ -f "$COMPILED_JSON" ]; then
  echo -e "\n2.2 Regex Preservation (compiled JSON):"
  jq -r '.templating.list[] | select(.regex != null and .regex != "") | .name' $INPUT_JSON | sort > /tmp/source_regex_vars.txt
  jq -r '.templating.list[] | select(.regex != null and .regex != "") | .name' $COMPILED_JSON | sort > /tmp/output_regex_vars.txt

  if diff /tmp/source_regex_vars.txt /tmp/output_regex_vars.txt > /dev/null; then
    echo "✓ Regex filters preserved"
  else
    echo "✗ WARNING: Regex filters missing in output"
    echo "Missing regex variables:"
    comm -23 /tmp/source_regex_vars.txt /tmp/output_regex_vars.txt
  fi
  rm -f /tmp/source_regex_vars.txt /tmp/output_regex_vars.txt
else
  echo -e "\n2.2 Regex Preservation: skipped (compiled JSON not provided)"
fi

# 3. Row structure verification
echo -e "\n3. Row Structure Verification:"
SOURCE_ROWS=$(jq '[.panels[] | select(.type == "row")] | length' $INPUT_JSON)
JSONNET_ROWS=$(rg -c "panels\\.rowPanel\\(|g\\.panel\\.row\\.new|type: 'row'" $OUTPUT_JSONNET)

echo "Source rows: $SOURCE_ROWS"
echo "Jsonnet rows: $JSONNET_ROWS"

if [ "$SOURCE_ROWS" == "$JSONNET_ROWS" ]; then
  echo "✓ Row count matches"
else
  echo "⚠ WARNING: Row count mismatch"
  echo "Source row titles:"
  jq -r '.panels[] | select(.type == "row") | .title' $INPUT_JSON
fi

# 3.1 Row membership verification (optional; requires compiled JSON)
if [ -n "$COMPILED_JSON" ] && [ -f "$COMPILED_JSON" ]; then
  echo -e "\n3.1 Row Membership Verification (compiled JSON):"
  MISSING_ROW_PANELS=$(jq -r '
    [ .panels[] | select(.type=="row") | {title, y: .gridPos.y} ] as $rows
    | [ .panels[] | select(.type!="row") | .gridPos.y ] as $ys
    | $rows[]
    | select(.y as $y | ($ys | index($y) | not))
    | .title
  ' $COMPILED_JSON | wc -l | tr -d ' ')

  if [ "$MISSING_ROW_PANELS" -eq 0 ]; then
    echo "✓ All rows have panels at matching Y"
  else
    echo "✗ WARNING: Rows without matching panels:"
    jq -r '
      [ .panels[] | select(.type=="row") | {title, y: .gridPos.y} ] as $rows
      | [ .panels[] | select(.type!="row") | .gridPos.y ] as $ys
      | $rows[]
      | select(.y as $y | ($ys | index($y) | not))
      | "\(.title) (y=\(.y))"
    ' $COMPILED_JSON
  fi
else
  echo -e "\n3.1 Row Membership Verification: skipped (compiled JSON not provided)"
fi

# Summary
echo -e "\n=== Summary ==="
if [ $ERRORS -eq 0 ]; then
  echo "✓ All validation checks passed!"
  exit 0
else
  echo "✗ $ERRORS error(s) found. Review conversion and fix issues."
  exit 1
fi
```

Save this as `verify-conversion.sh`, make it executable, and run:

```bash
chmod +x verify-conversion.sh
./verify-conversion.sh input-dashboard.json mixin/application/dashboard.jsonnet /path/to/compiled-dashboard.json
```

## Step 6: Visual verification in Grafana

After automated checks pass, perform visual verification:

1. **Import the dashboard**: Upload the compiled JSON to Grafana
2. **Check panel count**: Count panels in Grafana UI vs source dashboard
3. **Verify variables**: Open each variable dropdown - should populate with values
4. **Check row structure**: Expand/collapse rows - panels should be organized correctly
5. **Compare layouts**: Side-by-side comparison with source dashboard
6. **Test queries**: Verify all panels display data (no "No Data" errors)

### Common issues to check:

**Variables show no data:**
- Check datasource configuration in variables
- Verify query syntax is correct for your datasource
- Confirm datasource UID is valid

**Panels missing:**
- Check panel count from Step 2
- Look for panels that failed to convert (check build errors)
- Verify panels in collapsed rows are included

**Row structure incorrect:**
- Check that `gridPos.y` matches between rows and their panels
- Verify row objects are included in the `withPanels([...])` array
- Confirm collapsed state matches source

## Step 7: Debugging missing elements

If verification fails, use these commands to identify missing elements:

### Find which panels are missing:

```bash
# List all panel titles from source
echo "Source panels:"
jq -r '[.panels[] | if .type == "row" then (.panels // [])[] else . end | select(.type != "row") | .title] | .[]' input.json | sort

# List all panel titles from Jsonnet (by searching for title= in panel definitions)
echo -e "\nJsonnet panels:"
grep "title=" output.jsonnet | grep -oP "title='?\K[^',]+" | sort

# Compare
comm -23 <(jq -r '[.panels[] | if .type == "row" then (.panels // [])[] else . end | select(.type != "row") | .title] | .[]' input.json | sort) <(grep "title=" output.jsonnet | grep -oP "title='?\K[^',]+" | sort)
```

### Find which variables are missing:

```bash
# Show variable names side by side
echo "Source variables:"
jq -r '.templating.list[].name' input.json | sort

echo -e "\nJsonnet variables:"
grep "g.dashboard.variable" output.jsonnet | grep -oP "(?<=')[^']+(?=')" | sort

# Show differences
comm -23 <(jq -r '.templating.list[].name' input.json | sort) <(grep "g.dashboard.variable" output.jsonnet | grep -oP "(?<=')[^']+(?=')" | sort)
```

## Feedback loop process

If any verification step fails:

1. **Identify the gap**: Note which panels/variables/rows are missing
2. **Return to conversion**: Go back to the appropriate workflow step
   - Missing variables → Step 2
   - Missing panels → Step 4
   - Missing rows → Step 3
3. **Add missing elements**: Convert the missing items
4. **Recompile**: Run `mixin/build.sh` again
5. **Re-verify**: Run verification checks again
6. **Repeat until all checks pass**

This feedback loop ensures completeness before moving forward.

## Quick reference: Common jq patterns

```bash
# Count total panels (including in rows)
jq '[.panels[] | if .type == "row" then (.panels // [])[] else . end | select(.type != "row")] | length' file.json

# List all panel titles
jq -r '[.panels[] | if .type == "row" then (.panels // [])[] else . end | select(.type != "row") | .title] | .[]' file.json

# Count variables
jq '.templating.list | length' file.json

# List variable names
jq -r '.templating.list[].name' file.json

# Count rows
jq '[.panels[] | select(.type == "row")] | length' file.json

# List row titles
jq -r '.panels[] | select(.type == "row") | .title' file.json

# List datasource types
jq -r '[.panels[].datasource.type // "null"] | unique | .[]' file.json
```
