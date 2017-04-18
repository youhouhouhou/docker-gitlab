
FROM registry.docker.local/ubuntu-scm:16.04

ADD https://github.com/Yelp/dumb-init/releases/download/v1.0.2/dumb-init_1.0.2_amd64 /usr/bin/dumb-init
RUN chmod +x /usr/bin/dumb-init

RUN echo "deb https://packages.gitlab.com/runner/gitlab-ci-multi-runner/ubuntu/ xenial main" > /etc/apt/sources.list.d/runner_gitlab-ci-multi-runner.list && \
    wget -q -O - https://packages.gitlab.com/gpg.key | apt-key add - && \
    apt-get update -y && \
    apt-get install -y gitlab-ci-multi-runner && \
    apt-get clean && \
    mkdir -p /etc/gitlab-runner/certs && \
    chmod -R 700 /etc/gitlab-runner && \
    rm -rf /var/lib/apt/lists/*

ADD docker/entrypoint /
RUN chmod +x /entrypoint

COPY docker/set_env.sh /root/
# 设置环境变量, 将gitlab-runner 用户添加的 docker 组, 修正目录权限
RUN chmod +x /root/set_env.sh && \
    /root/set_env.sh && \
    gpasswd -a gitlab-runner docker && \
    chown -R gitlab-runner:root /opt/node-*/lib && \
    chown -R gitlab-runner:root /opt/node-*/bin

VOLUME ["/etc/gitlab-runner", "/home/gitlab-runner"]
ENTRYPOINT ["/usr/bin/dumb-init", "/entrypoint"]
CMD ["run", "--user=gitlab-runner", "--working-directory=/home/gitlab-runner"]

