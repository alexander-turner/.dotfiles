FROM ubuntu:latest

COPY install_fish.sh /tmp/install_fish.sh

RUN apt-get update && \
    apt-get install -y sudo curl git vim unzip wget && \
    useradd -m testuser && \
    echo "testuser:testuser" | chpasswd && \
    adduser testuser sudo

USER testuser
WORKDIR /home/testuser

CMD ["/bin/bash"]
