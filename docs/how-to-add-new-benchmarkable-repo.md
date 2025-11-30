## How to Add New Benchmarkable Repo

##### 1. Integrate benchmarks in benchmarkable repo with [Conbench](https://github.com/conbench/conbench)
Please follow [these instructions](https://github.com/conbench/conbench#authoring-benchmarks) to integrate benchmarks with Conbench.

Examples of benchmarks integrated with Conbench:

- https://github.com/arctosalliance/benchmarks/tree/main/benchmarks
- https://github.com/ElenaHenderson/benchmarkable-repo/blob/master/benchmarks.py
- https://github.com/apache/arrow-rs/blob/master/conbench/_criterion.py
- https://github.com/apache/arrow-datafusion/blob/master/conbench/_criterion.py

##### 2. Add `benchmarks.json` to benchmarkable repo
`benchmarks.json` should contain a list of benchmark groups that will be executed by Arrow Benchmarks CI
```json
[
  {
    "command": "cpp-micro --iterations=1",
    "flags": {
      "language": "C++"
    }
  },
  {
    "command": "csv-read ALL --iterations=3 --all=true --drop-caches=true",
    "flags": {
      "language": "Python"
    }
  }
]
```
Note that splitting all benchmarks into groups is not required but will allow Arrow Benchmarks CI 
to execute each benchmark group even if one benchmark group fails.

Examples of `benchmarks.json` in repos with benchmarks integrated with Conbench:

- https://github.com/arctosalliance/benchmarks/blob/main/benchmarks.json
- https://github.com/ElenaHenderson/benchmarkable-repo/blob/master/benchmarks.json
- https://github.com/apache/arrow-rs/blob/master/conbench/benchmarks.json
- https://github.com/apache/arrow-datafusion/blob/master/conbench/benchmarks.json


##### 3. Create Pull Request to add new benchmarkable repo to Arrow Benchmarks CI
##### 3.1 Add repo to **repos_with_benchmark_groups** in [`buildkite/benchmark/run.py`](../buildkite/benchmark/run.py) in this format:
```python
    {
        "benchmarkable_type": "benchmarkable-repo-commit",
        "repo": "https://github.com/ElenaHenderson/benchmarkable-repo.git",
        "root": "benchmarkable-repo",
        "branch": "master",
        "setup_commands": [],
        "path_to_benchmark_groups_list_json": "benchmarkable-repo/benchmarks.json",
        "url_for_benchmark_groups_list_json": "https://raw.githubusercontent.com/ElenaHenderson/benchmarkable-repo/master/benchmarks.json",
        "setup_commands_for_lang_benchmarks": {
            "R": [
                "build_arrow_r",
                "install_arrowbench",
                "create_data_dir",
            ]
        },
        "env_vars": {},
    },
```
| Key | Purpose     | 
| ----------- | ----------- |
| benchmarkable_type | Used by Arrow Benchmarks CI to have separate business logic for benchmark builds for different repos or benchmarkables (e.g., git commit vs wheel) |
| repo | Repo's HTTPS url used by Arrow Benchmarks CI to clone repo     |
| root | Repo's path to dir with benchmarks        |
| branch | Repo's branch used by Arrow Benchmarks CI to fetch commits to be benchmarked       |
| setup_commands | Shell commands that should be executed by Arrow Benchmarks CI to setup benchmarks after conda env is created and activated        |
| path_to_benchmark_groups_list_json | Repo's path to **benchmarks.json**|
| url_for_benchmark_groups_list_json | Repos HTTPS url to raw **benchmarks.json**|
| setup_commands_for_lang_benchmarks | Shell commands that should be executed by Arrow Benchmarks CI before running benchmarks for specific language|
| env_vars | Env vars that should be set by Arrow Benchmarks CI before running benchmarks|

##### 3.2 Add benchmark language to **benchmark_langs** in [`buildkite/benchmark/run.py`](../buildkite/benchmark/run.py)
Add your benchmark language to **benchmark_langs** if it is not already included. Value for benchmarks language should be the same as specified in **benchmarks.json**

##### 3.3 Add script for creating conda env for running benchmarks in your repo in [`buildkite/benchmark/utils.sh`](../buildkite/benchmark/utils.sh)
- Add function for creating and activating conda env required for running benchmarks in benchmarkable repo
```shell script
create_conda_env_for_arrow_rs_commit() {
  conda create -y -n "${BENCHMARKABLE_TYPE}" -c conda-forge \
    python="3.9" \
    rust
  conda activate "${BENCHMARKABLE_TYPE}"
}
```
- Update `create_conda_env_and_run_benchmarks` function to call above function for BENCHMARKABLE_TYPE used by benchmarkable repo:
```shell script
create_conda_env_and_run_benchmarks() {
  init_conda
  case "${BENCHMARKABLE_TYPE}" in
    "arrow-commit")
      ...
      ;;
    "arrow-rs-commit")
      export REPO=https://github.com/apache/arrow-rs.git
      export REPO_DIR=arrow-rs
      clone_repo
      create_conda_env_for_arrow_rs_commit
      ;;
...
}
```
##### 3.4 Add repo to **GITHUB_REPOS_WITH_BENCHMARKABLE_COMMITS** in [`config.py`](../config.py)
Add repo dict in this format to **GITHUB_REPOS_WITH_BENCHMARKABLE_COMMITS**
```python
    GITHUB_REPOS_WITH_BENCHMARKABLE_COMMITS = {
        "apache/arrow": {
            "benchmarkable_type": "arrow-commit",
            "enable_benchmarking_for_pull_requests": True,
            "github_secret": os.getenv("GITHUB_SECRET"),
            "publish_benchmark_results_on_pull_requests": True,
        },
        "apache/arrow-rs": {
            "benchmarkable_type": "arrow-rs-commit",
            "enable_benchmarking_for_pull_requests": False,
            "github_secret": None,
            "publish_benchmark_results_on_pull_requests": False,
        },
        "ElenaHenderson/benchmarkable-repo": {
            "benchmarkable_type": "benchmarkable-repo-commit",
            "enable_benchmarking_for_pull_requests": False,
            "github_secret": None,
            "publish_benchmark_results_on_pull_requests": False,
        },
    }
```
Repo's **benchmarkable_type** included in **GITHUB_REPOS_WITH_BENCHMARKABLE_COMMITS** 
should match value of **benchmarkable_type** in **repos_with_benchmark_groups** in [`buildkite/benchmark/run.py`](../buildkite/benchmark/run.py)
Note that posting benchmark results on Pull Requests is only supported for "apache/arrow" repo right now but it can be implemented to work for all benchmarkable repos if needed.

##### 4. Add machine to run benchmarks for benchmarkable repo
Please follow instructions in [How to Add New Benchmark Machine](./how-to-add-new-benchmark-machine.md)
