FROM ubuntu:18.04
ENV TZ=America/Denver
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    apt-get update && apt-get install -y apt-transport-https gnupg2 curl && \
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
    echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | tee -a /etc/apt/sources.list.d/kubernetes.list && \
    apt-get update -y && \
    apt-get install -y kubectl awscli gettext
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh
ENTRYPOINT [ "entrypoint.sh" ]