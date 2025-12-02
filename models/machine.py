import socket
from copy import deepcopy
from datetime import datetime
from typing import Optional, Tuple

import sqlalchemy as s
from authlib.jose import jwt
from sqlalchemy.dialects import postgresql
from sqlalchemy.orm import backref, relationship

from buildkite.benchmark.run import MockRun, repos_with_benchmark_groups
from config import Config
from db import Base
from integrations.buildkite import buildkite
from logger import log
from models.base import BaseMixin, NotNull, Nullable


class Machine(Base, BaseMixin):
    __tablename__ = "machine"
    name = NotNull(s.String, primary_key=True)
    info = Nullable(s.String)
    default_filters = NotNull(postgresql.JSONB)
    supported_filters = NotNull(postgresql.ARRAY(s.String))
    publish_benchmark_results = NotNull(s.Boolean, server_default="false")
    max_builds = NotNull(s.Integer, server_default="1")
    build_timeout = Nullable(s.Integer)
    runs = relationship("Run", backref=backref("machine", lazy="joined"))

    @property
    def buildkite_pipeline_name(self):
        return f"Arrow BCI Benchmark on {self.name}"

    @property
    def buildkite_agent_queue(self):
        return f"{self.name}"

    def supported_langs(self, benchmarkable_type):
        return sorted(list(self.default_filters[benchmarkable_type]["langs"].keys()))

    def create_benchmark_pipeline(self):
        buildkite.create_pipeline(
            self.buildkite_pipeline_name, self.buildkite_agent_queue
        )

    def delete_benchmark_pipeline(self):
        buildkite.delete_pipeline(self.buildkite_pipeline_name)

    def run_filters_and_skip_reason(
        self,
        benchmarkable_type: str,
        benchmarkable_reason: str,
        benchmarkable_commit_msg: Optional[str],
        override_filters: Optional[dict],
    ) -> Tuple[dict, Optional[str]]:
        """Decide which benchmarks to run on this machine.

        Return a tuple of augmented filters (default filters + override filters) and an
        optional reason to skip benchmarks altogether. If the skip_reason is not None,
        the scheduler should not start a benchmark run on this machine for this
        benchmarkable.

        If the skip_reason is None, the returned augmented run_filters should be passed
        to the Buildkite job so that they can be applied to benchmarks during the job.
        """
        if benchmarkable_type not in self.default_filters:
            return (
                {},
                f"Benchmarking of {benchmarkable_type}s is not supported on {self.name}",
            )

        machine_run_filters = deepcopy(self.default_filters[benchmarkable_type])

        if (
            "commit_message_skip_strings" in machine_run_filters
            # never skip PRs or wheels with otherwise-skippable commit messages
            # (possible reasons: arrow-commit, other-project-commit, pull-request, pyarrow-apache-wheel)
            and benchmarkable_reason.endswith("-commit")
            and benchmarkable_commit_msg
        ):
            for skip_string in machine_run_filters["commit_message_skip_strings"]:
                if skip_string.upper() in benchmarkable_commit_msg.upper():
                    return (
                        machine_run_filters,
                        f"The following commit message is skipped on {self.name} due "
                        f"to containing '{skip_string}': {benchmarkable_commit_msg}",
                    )

        if not override_filters:
            return machine_run_filters, None

        if "lang" in override_filters and override_filters[
            "lang"
        ] not in self.supported_langs(benchmarkable_type):
            return (
                override_filters,
                f"Only {self.supported_langs(benchmarkable_type)} langs are supported on {self.name}",
            )

        for override_filter in override_filters.keys():
            if override_filter not in self.supported_filters:
                return (
                    override_filters,
                    f"Only {self.supported_filters} filters are supported on {self.name}",
                )

        # Apply override_filters to machine_run_filters
        # override_filters can only have lang, name, command and flags filters
        if "command" in override_filters and "C++" in self.supported_langs(
            benchmarkable_type
        ):
            return override_filters, None

        if "lang" in override_filters:
            for lang in list(machine_run_filters["langs"].keys()):
                if lang != override_filters["lang"]:
                    machine_run_filters["langs"].pop(lang)

        if "name" in override_filters:
            benchmark_name = override_filters["name"]
            for lang in machine_run_filters["langs"].keys():
                benchmark_names = machine_run_filters["langs"][lang]["names"]
                if benchmark_name[-1] == "*":
                    filtered_benchmark_names = [
                        name
                        for name in benchmark_names
                        if name.startswith(benchmark_name[:-1])
                    ]
                else:
                    filtered_benchmark_names = [
                        name for name in benchmark_names if name == benchmark_name
                    ]
                machine_run_filters["langs"][lang]["names"] = filtered_benchmark_names

        has_groups = False
        for repo_with_benchmark_groups in repos_with_benchmark_groups:
            if repo_with_benchmark_groups["benchmarkable_type"] == benchmarkable_type:
                mock_run = MockRun(
                    repo_with_benchmark_groups, filters=machine_run_filters
                )
                has_groups = has_groups or mock_run.has_benchmark_groups_to_execute()

        if not has_groups:
            return (
                machine_run_filters,
                f"Provided benchmark filters do not have any benchmark groups to be executed on {self.name}",
            )

        return machine_run_filters, None

    def scheduled_or_running_builds(self):
        return buildkite.get_scheduled_builds(self.buildkite_pipeline_name)

    def create_api_access_token(self):
        header = {"alg": "HS256"}
        payload = {"machine": self.name, "created_at": str(datetime.utcnow())}
        key = Config.SECRET
        return jwt.encode(header, payload, key).decode()
