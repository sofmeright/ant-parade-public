# Name: prometheus-eaton-ups-exporter-sfmr:latest

FROM python:3.14.0a6-alpine3.21

RUN apk add --no-cache git
RUN apk add --no-cache openssh
RUN apk add --no-cache coreutils
    
RUN wget https://github.com/psyinfra/prometheus-eaton-ups-exporter/archive/refs/tags/v1.2.0.zip
RUN unzip v1.2.0.zip
RUN mv /prometheus-eaton-ups-exporter-1.2.0 /prometheus-eaton-ups-exporter
RUN cd /prometheus-eaton-ups-exporter
WORKDIR /prometheus-eaton-ups-exporter
#COPY ./requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

# copy project
COPY . .

CMD [ "sleep infinity" ]