from flask import request
from flask_restful import Resource

from config import Config
from integrations.github import Github
from logger import log
from api.events import (
    verify_github_request_signature,
    create_benchmarkables_and_runs,
    get_pull_benchmark_filters,
    GithubSignatureInvalid,
    UnsupportedBenchmarkCommand,
    CommitHasScheduledBenchmarkRuns,
    benchmark_command_examples,
)


class Benchmarks(Resource):
    def post(self):
        data = request.get_json()
        repo = data.get("repo")

        if not repo:
            return {"error": "Missing repo"}, 400

        # Get the github secret for this repo (reuse existing config)
        repo_config = Config.GITHUB_REPOS_WITH_BENCHMARKABLE_COMMITS.get(repo)
        if not repo_config:
            return {"error": f"Repo {repo} not configured"}, 400

        github_secret = repo_config.get("github_secret")
        if not github_secret:
            return {"error": f"Repo {repo} has no github_secret configured"}, 400

        if not repo_config.get("enable_benchmarking_for_pull_requests"):
            return {"error": f"Benchmarking not enabled for {repo}"}, 400

        # Verify signature using same method as webhooks
        try:
            verify_github_request_signature(request, github_secret)
        except GithubSignatureInvalid as e:
            log.exception(e)
            return {"error": e.args[0]}, 401

        pull_number = data.get("pull_number")
        filters_string = data.get("filters", "")

        if not pull_number:
            return {"error": "Missing pull_number"}, 400

        try:
            # Parse filters (reuse existing logic)
            benchmark_filters = {}
            if filters_string:
                fake_comment = f"@ursabot please benchmark {filters_string}"
                benchmark_filters = get_pull_benchmark_filters(fake_comment)

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

            return {
                "success": True,
                "commit": benchmarkable.id,
                "baseline_commit": baseline_benchmarkable.id,
            }, 201

        except UnsupportedBenchmarkCommand:
            Github(repo).create_pull_comment(pull_number, benchmark_command_examples)
            return {"error": "Unsupported benchmark command"}, 400
        except CommitHasScheduledBenchmarkRuns as e:
            Github(repo).create_pull_comment(pull_number, e.args[0])
            return {"error": e.args[0]}, 409
        except Exception as e:
            log.exception(e)
            return {"error": str(e)}, 500
