FROM python:3.5-alpine

# Proxy settings
ENV http_proxy ${HTTP_PROXY}
ENV https_proxy ${HTTP_PROXY}

RUN pip install pyyaml

COPY raw2json.py /bin/

# TODO: create a user with access to /in and /out folder

ENTRYPOINT ["python", "/bin/raw2json.py"]
CMD ["--input", "/in", "--output", "/out"]
