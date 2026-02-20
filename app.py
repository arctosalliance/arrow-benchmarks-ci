from flask import Flask
from flask_restful import Api

from api.benchmarks import Benchmarks
from api.events import Events
from api.health_check import HealthCheck
from api.logs import Logs
from api.runs import Runs
from config import Config
from db import Session


app = Flask(__name__)
app.config["SQLALCHEMY_DATABASE_URI"] = Config.SQLALCHEMY_DATABASE_URI
api = Api(app)


@app.teardown_appcontext
def cleanup(_):
    Session.remove()


api.add_resource(Benchmarks, "/benchmarks")
api.add_resource(Events, "/events")
api.add_resource(HealthCheck, "/health-check")
api.add_resource(Logs, "/logs")
api.add_resource(Runs, "/runs/<string:id>")

if __name__ == "__main__":
    app.run()
