#!/bin/bash

init_conda() {
  eval "$(command "$HOME/miniconda3/bin/conda" 'shell.bash' 'hook' 2> /dev/null)"
}

create_conda_env_for_arrow_commit() {
  pushd $REPO_DIR

  conda -V
  conda create -y -n "${BENCHMARKABLE_TYPE}" --solver libmamba -c conda-forge \
  --file ci/conda_env_unix.txt \
  --file ci/conda_env_cpp.txt \
  --file ci/conda_env_python.txt \
  compilers \
  python="${PYTHON_VERSION}" \
  pandas

  source dev/conbench_envs/hooks.sh activate_conda_env_for_benchmark_build
  source dev/conbench_envs/hooks.sh install_arrow_python_dependencies
  source dev/conbench_envs/hooks.sh set_arrow_build_and_run_env_vars

  export RANLIB=`which $RANLIB`
  export AR=`which $AR`

  source dev/conbench_envs/hooks.sh build_arrow_cpp
  source dev/conbench_envs/hooks.sh build_arrow_python
  source dev/conbench_envs/hooks.sh install_archery
  source dev/conbench_envs/hooks.sh install_r
  popd
}

create_conda_env_for_pyarrow_apache_wheel() {
  conda create -y -n "${BENCHMARKABLE_TYPE}" -c conda-forge \
    python="${PYTHON_VERSION}" \
    pandas
  conda activate "${BENCHMARKABLE_TYPE}"
  pip install "${BENCHMARKABLE}"
}

create_conda_env_for_benchmarkable_repo_commit() {
  conda create -y -n "${BENCHMARKABLE_TYPE}" python="${PYTHON_VERSION}"
  conda activate "${BENCHMARKABLE_TYPE}"
}

create_conda_env_for_arrow_rs_commit() {
  conda create -y -n "${BENCHMARKABLE_TYPE}" -c conda-forge \
    python="3.9" \
    rust
  conda activate "${BENCHMARKABLE_TYPE}"
}

create_conda_env_for_arrow_datafusion_commit() {
  conda create -y -n "${BENCHMARKABLE_TYPE}" -c conda-forge \
    python="3.9" \
    rust
  conda activate "${BENCHMARKABLE_TYPE}"
}

clone_repo() {
  rm -rf arrow
  git clone "${REPO}"
  pushd $REPO_DIR
  git fetch -v --prune -- origin "${BENCHMARKABLE}"
  git checkout -f "${BENCHMARKABLE}"
  popd
}

build_arrow_r() {
  pushd $REPO_DIR
  source dev/conbench_envs/hooks.sh build_arrow_r
  popd
}

build_arrow_java() {
  conda install -y --solver libmamba -c conda-forge 'maven=3.9.6' 'openjdk=17'
  # arrow java gets built as part of archery
}

install_minio() {
  pushd $REPO_DIR
  ci/scripts/install_minio.sh latest ${ARROW_HOME}
  popd
}

install_arrowbench() {
  # do I need to cd into benchmarks dir?
  git clone https://github.com/arctosalliance/arrowbench.git
  R -e "remotes::install_local('./arrowbench')"
}

install_java_script_project_dependencies() {
  conda install -y --solver libmamba -c conda-forge 'nodejs>=12.20'
  npm install -g yarn
  pushd $REPO_DIR
  source dev/conbench_envs/hooks.sh install_java_script_project_dependencies
  popd
}

create_data_dir() {
  mkdir -p "${BENCHMARKS_DATA_DIR}"
  mkdir -p "${BENCHMARKS_DATA_DIR}/temp"
}

test_pyarrow_is_built() {
  echo "------------>Testing pyarrow is built"
  python -c "import pyarrow; print(pyarrow.__version__)"
  echo "------------>End"
}

create_conda_env_and_run_benchmarks() {
  init_conda
  case "${BENCHMARKABLE_TYPE}" in
    "arrow-commit")
      export REPO=https://github.com/apache/arrow.git
      export REPO_DIR=arrow
      clone_repo
      # retry this sometimes-flaky step
      create_conda_env_for_arrow_commit || create_conda_env_for_arrow_commit
      test_pyarrow_is_built
      ;;
    "pyarrow-apache-wheel")
      create_conda_env_for_pyarrow_apache_wheel
      ;;
    "benchmarkable-repo-commit")
      export REPO=https://github.com/ElenaHenderson/benchmarkable-repo.git
      export REPO_DIR=benchmarkable-repo
      clone_repo
      create_conda_env_for_benchmarkable_repo_commit
      ;;
    "arrow-rs-commit")
      export REPO=https://github.com/apache/arrow-rs.git
      export REPO_DIR=arrow-rs
      clone_repo
      create_conda_env_for_arrow_rs_commit
      ;;
    "arrow-datafusion-commit")
      export REPO=https://github.com/apache/arrow-datafusion.git
      export REPO_DIR=arrow-datafusion
      clone_repo
      create_conda_env_for_arrow_datafusion_commit
      ;;
  esac

  # pypi doesn't have wheels for macos 13 and source build fails
  conda install -y --solver libmamba -c conda-forge 'psycopg2-binary'
  pip install -r requirements.txt
  python -m buildkite.benchmark.run_benchmark_groups
}

"$@"
