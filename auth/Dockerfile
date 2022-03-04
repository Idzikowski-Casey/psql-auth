FROM python:3.10

COPY requirements.txt ./

RUN pip install --no-cache-dir -r requirements.txt

COPY . ./auth
RUN ["chmod", "+x", "/auth/bin/run"]

CMD auth/bin/run