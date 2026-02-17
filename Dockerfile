FROM python:3.12

COPY requirements-test.txt /tmp/
COPY requirements.txt /tmp/
RUN pip install -r /tmp/requirements-test.txt -r /tmp/requirements.txt

WORKDIR /app
ADD . /app
