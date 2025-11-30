import hashlib
import hmac
import json

from flask import request
from flask_restful import Resource

from config import Config
from integrations.github import Github
from logger import log
from models.benchmarkable import Benchmarkable

expected_phrase = "@ursabot please benchmark"
benchmark_command_examples = """
Supported benchmark command examples:

`@ursabot benchmark help`

To run all benchmarks:
`@ursabot please benchmark`

To filter benchmarks by language:
`@ursabot please benchmark lang=Python`
`@ursabot please benchmark lang=C++`
`@ursabot please benchmark lang=R`
`@ursabot please benchmark lang=Java`
`@ursabot please benchmark lang=JavaScript`

To filter Python and R benchmarks by name:
`@ursabot please benchmark name=file-write`
`@ursabot please benchmark name=file-write lang=Python`
`@ursabot please benchmark name=file-.*`

To filter C++ benchmarks by archery --suite-filter and --benchmark-filter:
`@ursabot please benchmark command=cpp-micro --suite-filter=arrow-compute-vector-selection-benchmark --benchmark-filter=TakeStringRandomIndicesWithNulls/262144/2`

For other `command=cpp-micro` options, please see https://github.com/arctosalliance/benchmarks/blob/main/benchmarks/cpp_micro_benchmarks.py
"""


class UnsupportedBenchmarkCommand(Exception):
    pass


class CommitHasScheduledBenchmarkRuns(Exception):
    pass


class GithubSignatureInvalid(Exception):
    pass


def verify_github_request_signature(github_request, github_secret):
    actual_github_request_signature = github_request.headers.get("X-Hub-Signature-256")

    if not actual_github_request_signature:
        raise GithubSignatureInvalid("X-Hub-Signature-256 header was not sent.")

    expected_github_request_signature = "sha256=" + (
        hmac.new(
            key=github_secret.encode(),
            msg=github_request.data,
            digestmod=hashlib.sha256,
        ).hexdigest()
    )

    if not hmac.compare_digest(
        expected_github_request_signature, actual_github_request_signature
    ):
        raise GithubSignatureInvalid(
            "Github's actual X-Hub-Signature-256 dit not match expected X-Hub-Signature-256."
        )


def get_pull_benchmark_filters(comment):
    if expected_phrase not in comment:
        raise UnsupportedBenchmarkCommand

    filters_phrase = comment.split(expected_phrase)[-1].strip()

    if not filters_phrase:
        return {}

    # Command option is only supported for C++ benchmarks
    if filters_phrase.startswith("command=cpp-micro"):
        return {"command": filters_phrase.replace("command=", "")}

    filters = {}
    for text_filter in filters_phrase.split(" "):
        if text_filter == "":
            continue

        filter_key, filter_value = text_filter.split("=")

        if (
            filter_key not in ("lang", "name")
            or filter_key in filters
            or (
                filter_key == "lang"
                and filter_value not in ["Python", "C++", "R", "Java", "JavaScript"]
            )
        ):
            raise UnsupportedBenchmarkCommand

        filters[filter_key] = filter_value

    # Filtering C++, Java, JavaScript benchmarks by name is not supported
    if filters.get("lang") in ["C++", "Java", "JavaScript"] and filters.get("name"):
        raise UnsupportedBenchmarkCommand

    return filters


def create_benchmarkables_and_runs(pull_dict, pull_benchmark_filters, repo):
    benchmarkable_type = reason = Config.GITHUB_REPOS_WITH_BENCHMARKABLE_COMMITS[repo][
        "benchmarkable_type"
    ]
    id = pull_dict["head"]["sha"]

    if Benchmarkable.get(id):
        raise CommitHasScheduledBenchmarkRuns(
            f"Commit {id} already has scheduled benchmark runs."
        )

    data = Github(repo).get_commit(id)
    baseline_id = pull_dict["base"]["sha"]
    baseline_data = Github(repo).get_commit(baseline_id)

    baseline_benchmarkable = Benchmarkable.create(
        dict(
            id=baseline_id,
            type=benchmarkable_type,
            data=baseline_data,
            baseline_id=baseline_data["parents"][0]["sha"],
            reason=reason,
        )
    )

    benchmarkable = Benchmarkable.create(
        dict(
            id=id,
            type=benchmarkable_type,
            data=data,
            baseline_id=baseline_id,
            reason="pull-request",
            filters=pull_benchmark_filters,
            pull_number=pull_dict["number"],
        )
    )

    return baseline_benchmarkable, benchmarkable


def is_pull_request_comment_for_ursabot(event):
    return (
        event.get("action") == "created"
        and event.get("issue")
        and event.get("comment")
        and event["comment"]["body"]
        .replace("\n", "")
        .replace("\r", "")
        .startswith("@ursabot")
        and benchmark_command_examples not in event["comment"]["body"]
    )


def get_repo(github_request):
    event = json.loads(github_request.data)
    return event.get("repository", {}).get("full_name")


def get_repo_github_secret(repo):
    repo_params = Config.GITHUB_REPOS_WITH_BENCHMARKABLE_COMMITS.get(repo)

    if not repo_params:
        return

    if repo_params["enable_benchmarking_for_pull_requests"]:
        return repo_params["github_secret"]


class Events(Resource):
    def post(self):
        repo = get_repo(request)
        github_secret = get_repo_github_secret(repo)

        if not github_secret:
            return "", 202

        try:
            verify_github_request_signature(request, github_secret)
        except GithubSignatureInvalid as e:
            log.exception(e)
            return e.args[0], 401

        event = json.loads(request.data)

        if is_pull_request_comment_for_ursabot(event):
            log.info(event)
            pull_number = event["issue"]["number"]

            try:
                benchmark_filters = get_pull_benchmark_filters(event["comment"]["body"])
                pull_dict = Github(repo).get_pull(pull_number)

                baseline_benchmarkable, benchmarkable = create_benchmarkables_and_runs(
                    pull_dict, benchmark_filters, repo
                )

                for run in baseline_benchmarkable.runs + benchmarkable.runs:
                    if run.status == "created":
                        run.create_benchmark_build()

                Github(repo).create_pull_comment(
                    pull_number,
                    f"Benchmark runs are scheduled for commit {benchmarkable.id}. Watch "
                    f"https://buildkite.com/{Config.BUILDKITE_ORG} and "
                    f"{Config.CONBENCH_URL} for updates. A comment will be posted here "
                    "when the runs are complete.",
                )
            except UnsupportedBenchmarkCommand:
                Github(repo).create_pull_comment(
                    pull_number, benchmark_command_examples
                )
            except CommitHasScheduledBenchmarkRuns as e:
                Github(repo).create_pull_comment(pull_number, e.args[0])

        return "", 202
