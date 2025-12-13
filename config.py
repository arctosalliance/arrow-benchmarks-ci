import getpass
import os


class Config:
    BUILDKITE_API_BASE_URL = os.getenv("BUILDKITE_API_BASE_URL")
    BUILDKITE_API_TOKEN = os.getenv("BUILDKITE_API_TOKEN")
    BUILDKITE_ORG = os.getenv("BUILDKITE_ORG")

    CONBENCH_URL = os.getenv("CONBENCH_URL")

    DB_HOST = os.environ.get("DB_HOST", "localhost")
    DB_NAME = os.environ.get("DB_NAME", "postgres")
    DB_PASSWORD = os.environ.get("DB_PASSWORD", "postgres")
    DB_PORT = os.environ.get("DB_PORT", "5432")
    DB_USERNAME = os.environ.get("DB_USERNAME", getpass.getuser())

    ENV = os.environ.get("ENV")

    GITHUB_API_BASE_URL = os.getenv("GITHUB_API_BASE_URL")
    GITHUB_API_TOKEN = os.getenv("GITHUB_API_TOKEN")
    GITHUB_REPOS_WITH_BENCHMARKABLE_COMMITS = {
        "apache/arrow": {
            "benchmarkable_type": "arrow-commit",
            "enable_benchmarking_for_pull_requests": True,
            "github_secret": os.getenv("GITHUB_SECRET"),
            "publish_benchmark_results_on_pull_requests": True,
        },
        "ElenaHenderson/benchmarkable-repo": {
            "benchmarkable_type": "benchmarkable-repo-commit",
            "enable_benchmarking_for_pull_requests": False,
            "github_secret": None,
            "publish_benchmark_results_on_pull_requests": False,
        },
        "apache/arrow-rs": {
            "benchmarkable_type": "arrow-rs-commit",
            "enable_benchmarking_for_pull_requests": False,
            "github_secret": None,
            "publish_benchmark_results_on_pull_requests": False,
        },
        "apache/arrow-datafusion": {
            "benchmarkable_type": "arrow-datafusion-commit",
            "enable_benchmarking_for_pull_requests": False,
            "github_secret": None,
            "publish_benchmark_results_on_pull_requests": False,
        },
    }
    GITHUB_REPO = os.getenv("GITHUB_REPO")
    MAX_COMMITS_TO_FETCH = os.getenv("MAX_COMMITS_TO_FETCH", 20)

    PIPY_API_BASE_URL = os.getenv("PIPY_API_BASE_URL")
    PIPY_PROJECT = os.getenv("PIPY_PROJECT")

    PYTHON_VERSION_FOR_BENCHMARK_BUILDS = "3.12"

    SECRET = os.getenv("SECRET")

    SLACK_API_BASE_URL = os.getenv("SLACK_API_BASE_URL")
    SLACK_API_TOKEN = os.getenv("SLACK_API_TOKEN")
    SLACK_CHANNEL_FOR_BENCHMARK_RESULTS = os.getenv(
        "SLACK_CHANNEL_FOR_BENCHMARK_RESULTS"
    )
    SLACK_USER_ID_FOR_WARNINGS = os.getenv("SLACK_USER_ID_FOR_WARNINGS")

    SQLALCHEMY_DATABASE_URI = (
        f"postgresql://{DB_USERNAME}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
    )
    _SKIP_STRINGS = {
        "commit_message_skip_strings": [
            "[C#]",
            "[CI]",
            "[Dev]",
            "[Doc]",
            "[Docs]",
            "[Glib]",
            "[Go]",
            "[Java]",
            "[MATLAB]",
            "MINOR:",
            "[Release]",
            "[Ruby]",
        ]
    }

    MACHINES = {
        # "test-mac-arm": {
        #     "info": "Supported benchmark langs: C++, Python, R",
        #     "default_filters": {
        #         "arrow-commit": {
        #             "langs": {
        #                 "C++": {"names": ["cpp-micro"]},
        #                 "R": {"names": ["tpch"]},
        #             }
        #         },
        #         **_SKIP_STRINGS,
        #     },
        #     "supported_filters": ["lang", "name"],
        #     "publish_benchmark_results": True,
        #     "max_builds": 1,
        #     "build_timeout": 150,
        # },
        "amd64-c6a-4xlarge-linux": {
            "info": "Supported benchmark langs: C++, Java",
            "default_filters": {
                "arrow-commit": {
                    "langs": {
                        "C++": {"names": ["cpp-micro"]},
                        # "Java": {"names": ["java-micro"]},
                    }
                },
                **_SKIP_STRINGS,
            },
            "supported_filters": ["lang", "command"],
            "publish_benchmark_results": True,
            "max_builds": 5,
            "build_timeout": 180,
        },
        "arm64-t4g-2xlarge-linux": {
            "info": "Supported benchmark langs: C++, Python, R",
            "default_filters": {
                "arrow-commit": {
                    "langs": {
                        "Python": {"names": ["dataset-read", "dataset-select"]},
                        "C++": {"names": ["cpp-micro"]},
                        "R": {"names": ["tpch"]},
                    }
                },
                **_SKIP_STRINGS,
            },
            "supported_filters": ["lang", "name", "command"],
            "publish_benchmark_results": True,
            "max_builds": 2,
            "build_timeout": 480,
        },
        "amd64-m5-4xlarge-linux": {
            "info": "Supported benchmark langs: Python, R, Java, JavaScript, C++",
            "default_filters": {
                "arrow-commit": {
                    "langs": {
                        "Python": {
                            "names": [
                                "csv-read",
                                "dataframe-to-table",
                                "dataset-filter",
                                "dataset-read",
                                "dataset-select",
                                "dataset-selectivity",
                                "dataset-serialize",
                                "file-read",
                                "file-write",
                                "recursive-get-file-info",
                                "wide-dataframe",
                            ]
                        },
                        "R": {
                            "names": [
                                "dataframe-to-table",
                                "file-read",
                                "file-write",
                                "partitioned-dataset-filter",
                                "wide-dataframe",
                                "tpch",
                            ]
                        },
                        # "JavaScript": {"names": ["js-micro"]},
                        "C++": {"names": ["cpp-micro"]},
                        # "Java": {"names": ["java-micro"]},
                    },
                },
                **_SKIP_STRINGS,
            },
            "supported_filters": ["lang", "name", "command"],
            "publish_benchmark_results": True,
            "max_builds": 5,
            "build_timeout": 480,
        },
    }
