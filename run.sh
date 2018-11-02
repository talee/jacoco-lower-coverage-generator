#!/bin/sh
#
# Generates Jacoco rules that match current code coverage so that next commit
# must cover at least the current coverage or higher. Useful when starting code
# coverage for an existing code base
#
# Version: 1.0.0
#
if [ -z "$input_file" ]; then
    input_file='code-coverage.csv'
fi
if [ ! -f "$input_file" ]; then
    echo "File '$input_file' not found. Pass in file argument via the command:"
    echo "input_file=somefile.csv output_file=someoutput.gradle ./run.sh"
    exit 1
fi

if [ -z "$output_file" ]; then
    output_file='code-coverage-rules.gradle'
fi
rm "$output_file" 2> /dev/null
touch "$output_file"
if [ ! -f "$output_file" ]; then
    echo "Cannot write to '$output_file'. Make sure the directory of the output file is writable."
    echo "input_file=somefile.csv output_file=directory/someoutput.gradle ./run.sh"
fi

if [ -z "$excludes_file" ]; then
    excludes_file=exclude-classes.gradle
fi

# Don't create rules coverage greater than these %. Global coverage rules will
# cover for this
if [ -z "$instruction_max_default" ]; then
    instruction_max_default=0.85
fi
if [ -z "$branch_max_default" ]; then
    branch_max_default=0.9
fi

# Write standard verification block
echo \
'jacocoTestCoverageVerification {
    violationRules {' >> "$output_file"

COLUMN_INDEX_PACKAGE=1
COLUMN_INDEX_CLASS=2
COLUMN_INDEX_INSTRUCTION_MISSED=3
COLUMN_INDEX_INSTRUCTION_COVERED=4
COLUMN_INDEX_BRANCH_MISSED=5
COLUMN_INDEX_BRANCH_COVERED=6

EXCLUDE_CLASSES=()

# Read in each line and generate a rule
main() {
    header_line_read=0
    while IFS='' read -r line || [[ -n "$line" ]]; do
        if [ $header_line_read = 0 ]; then
            header_line_read=1
            continue
        fi
        generate_rule "$line" >> "$output_file"
    done < "$input_file"

    # TODO: Improve this
    echo "excludes = [" > "$excludes_file"
    for package_class in "${EXCLUDE_CLASSES[@]}"
    do
        echo "'$package_class'," >> "$excludes_file"
    done
    echo "]" >> "$excludes_file"
}

# $1 = math expression
calculate_prefix_zero() {
    local result=`bc <<< "scale=2; $1" 2> /dev/null`
    # zero len if error. Return early
    if [ -z $result ]; then
        return
    fi
    # Not applicable if bc has error e.g. divide by zero
    # Possible only for branch coverage (0/0 if no branches)
    # 3 for .dd format. 1.00 (100%) is ignored as well
    if [ ${#result} -le 3 ]; then
        # Prefix zero to decimal only (len != 1)
        if [ ${#result} -eq 1 ] 2> /dev/null; then
            echo "$result"
        else
            echo "0$result"
        fi
    fi
}

print_err() {
    (>&2 echo "ERROR: $@")
}

# $1 = line from file
# Echos a multiline rule string
generate_rule() {
    local line=$1
    IFS=','
    columns=($line)
    PACKAGE=${columns[COLUMN_INDEX_PACKAGE]}
    CLASS=${columns[COLUMN_INDEX_CLASS]}
    INSTRUCTION_MISSED=${columns[COLUMN_INDEX_INSTRUCTION_MISSED]}
    INSTRUCTION_COVERED=${columns[COLUMN_INDEX_INSTRUCTION_COVERED]}
    BRANCH_MISSED=${columns[COLUMN_INDEX_BRANCH_MISSED]}
    BRANCH_COVERED=${columns[COLUMN_INDEX_BRANCH_COVERED]}

    INSTRUCTION_MIN=`calculate_prefix_zero "$INSTRUCTION_COVERED/($INSTRUCTION_MISSED+$INSTRUCTION_COVERED)"`
    BRANCH_MIN=`calculate_prefix_zero "$BRANCH_COVERED/($BRANCH_MISSED+$BRANCH_COVERED)"`
    IGNORE_BRANCH=`calculate_prefix_zero "$BRANCH_MIN>$branch_max_default"`
    IGNORE_INSTRUCTION=`calculate_prefix_zero "$INSTRUCTION_MIN>$instruction_max_default"`
    # Don't generate rule for class if class meets global coverage expectations
    if [ -z "$BRANCH_MIN" -o "$IGNORE_BRANCH" = '1' ] && [ -z "$INSTRUCTION_MIN" -o "$IGNORE_INSTRUCTION" = '1' ]; then
        return 
    fi
    # Add to excludes array
    EXCLUDE_CLASSES+=("$PACKAGE.$CLASS")
    echo \
"        rule {
            element = 'CLASS'
            includes = ['$PACKAGE.$CLASS']"

    # Only add branch rule if there are branches to cover
    if [ "$BRANCH_MIN" -a "$IGNORE_BRANCH" = '0' ]; then
        echo \
"            limit {
                counter = 'BRANCH'
                value = 'COVEREDRATIO'
                minimum = $BRANCH_MIN
            }"
    fi

    # Only add instruction rule if there are instructions to cover (not 100%)
    if [ "$INSTRUCTION_MIN" -a "$IGNORE_INSTRUCTION" = '0' ]; then
    echo \
"            limit {
                counter = 'INSTRUCTION'
                value = 'COVEREDRATIO'
                minimum = $INSTRUCTION_MIN
            }"
    fi
    echo \
'        }'
}

main "$@"

# Write and close standard verification block
echo '
    }
}' >> "$output_file"
