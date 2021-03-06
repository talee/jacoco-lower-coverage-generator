# jacoco-lower-coverage-generator

Generates Jacoco rules that match current code coverage so that next commit must
cover at least the current coverage or higher. Useful when starting code
coverage for an existing code base.

	input_file=some-file.csv output_file=some-file.gradle ./run.sh

Default input file is

	code-coverage.csv

Default outputs to

	code-coverage-rules.gradle

Excludes need to apply to the global coverage rule. Define the pre and post
section of that rule via the params (these are defaults as well):

	pre_excludes_file=pre_excludes.gradle
	post_excludes_file=post_excludes.gradle

Generated excludes array will be wrapped by these two files.

Rules aren't generated for coverage greater than a certain amount to allow for
global rules to apply.

    instruction_max_default=0.85
    branch_max_default=0.9

Can be overriden by passing these in a parameters as well.

    instruction_max_default=0.8 ./run.sh
