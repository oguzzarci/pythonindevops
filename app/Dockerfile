FROM python:alpine3.15
RUN mkdir /app
WORKDIR /app
RUN apk update \
    && apk add --virtual build-deps gcc python3-dev musl-dev \
    && apk add --no-cache mariadb-dev
COPY requirements.txt requirements.txt
RUN pip3 install -r requirements.txt
RUN apk del build-deps
COPY . .
#CMD ["python", "app.py"]
RUN chmod +x ./entrypoint.sh
ENTRYPOINT ["./entrypoint.sh"]