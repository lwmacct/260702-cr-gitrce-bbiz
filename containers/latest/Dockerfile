# syntax=docker/dockerfile:1
# https://hub.docker.com/_/ubuntu
FROM ubuntu:resolute-20261105.1
LABEL maintainer="https://github.com/lwmacct"
ARG DEBIAN_FRONTEND=noninteractive
ARG TARGETARCH
# Ubuntu 26.04 的 python3.14 目前停在 3.14.4, 该版本带有 GH-140262 引入的循环 GC 回归,
# 长连接/高频建 SSL context 的进程 RSS 会涨到数 GiB. 这里用 uv 托管解释器绕开发行版包.
ARG PYTHON_VERSION=3.14.7
SHELL ["/bin/bash", "-lc"]

RUN set -eux; \
    echo "配置源,容器内源文件为 /etc/apt/sources.list.d/ubuntu.sources"; \
    sed -i 's@//.*archive.ubuntu.com@//mirrors.ustc.edu.cn@g' /etc/apt/sources.list.d/ubuntu.sources; \
    sed -i 's@//ports.ubuntu.com@//mirrors.ustc.edu.cn@g' /etc/apt/sources.list.d/ubuntu.sources; \
    sed -i 's/security.ubuntu.com/mirrors.ustc.edu.cn/g' /etc/apt/sources.list.d/ubuntu.sources; \
    apt-get update; apt-get install -y --no-install-recommends ca-certificates curl wget sudo pcp gnupg; \
    sed -i 's/http:/https:/g' /etc/apt/sources.list.d/ubuntu.sources; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*; \
    echo "设置 PS1"; \
    cat >> /root/.bashrc <<"MEOF"
PS1='${debian_chroot:+($debian_chroot)}\[\033[01;33m\]\u\[\033[00m\]@\[\033[01;35m\]\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
MEOF

RUN set -eux; \
    echo "语言/时间"; \
    apt-get update; \
    apt-get install -y --no-install-recommends locales fonts-wqy-zenhei fonts-wqy-microhei tzdata; \
    locale-gen zh_CN.UTF-8 en_US.UTF-8; \
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 LANGUAGE=en_US.UTF-8; \
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime; \
    echo "Asia/Shanghai" > /etc/timezone; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*; \
    echo;

RUN set -eux; \
    echo "基础软件包"; \
    apt-get update; \
    apt-get dist-upgrade -y; \
    apt-get install -y --no-install-recommends \
        tini supervisor cron vim git jq bc tree zstd zip unzip xz-utils tzdata lsof expect tmux perl sshpass \
        util-linux bash-completion dosfstools e2fsprogs parted dos2unix kmod pciutils moreutils psmisc \
        openssl openssh-server nftables iptables iproute2 iputils-ping net-tools ethtool socat telnet mtr rsync nfs-common \
        sysstat iftop htop iotop dstat; \
    rm -rf /*-is-merged; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*; \
    echo;

ENV PATH=$PATH:/opt/MegaRAID/storcli
RUN set -eux; \
    echo "安装 storcli"; \
    mkdir -p /tmp/storcli; \
    wget -O /tmp/storcli/download.zip https://docs.broadcom.com/docs-and-downloads/007.3103.0000.0000_MR%207.31_storcli.zip; \
    unzip /tmp/storcli/download.zip -d /tmp/storcli; \
    unzip /tmp/storcli/storcli_rel/Unified_storcli_all_os.zip -d /tmp/storcli; \
    case "$TARGETARCH" in \
        amd64) _storcli_deb=/tmp/storcli/Unified_storcli_all_os/Ubuntu/storcli_007.3103.0000.0000_all.deb ;; \
        arm64) _storcli_deb=/tmp/storcli/Unified_storcli_all_os/ARM/Linux/storcli64_007.3103.0000.0000_arm64.deb ;; \
        *) _storcli_deb= ;; \
    esac; \
    if [ -n "$_storcli_deb" ] && [ -f "$_storcli_deb" ]; then \
        dpkg -i "$_storcli_deb"; \
    else \
        echo "skip storcli for TARGETARCH=$TARGETARCH"; \
    fi; \
    rm -rf /tmp/storcli; \
    echo;

RUN set -eux; \
    echo "安装 zabbix-agent 6.0.46"; \
    case "$TARGETARCH" in \
        amd64|'') \
            _zabbix_url='https://cdn.zabbix.com/zabbix/binaries/stable/6.0/6.0.46/zabbix_agent-6.0.46-linux-3.0-amd64-static.tar.gz'; \
            if ! getent passwd zabbix >/dev/null; then useradd --system --home-dir /var/lib/zabbix --shell /usr/sbin/nologin zabbix; fi; \
            mkdir -p /tmp/zabbix /etc/zabbix /var/lib/zabbix; \
            curl -fL "$_zabbix_url" -o /tmp/zabbix/zabbix-agent.tar.gz; \
            tar -xzf /tmp/zabbix/zabbix-agent.tar.gz -C /tmp/zabbix; \
            install -o root -g root -m 0755 /tmp/zabbix/sbin/zabbix_agentd /usr/local/sbin/zabbix_agentd; \
            install -o root -g root -m 0755 /tmp/zabbix/bin/zabbix_get /usr/local/bin/zabbix_get; \
            install -o root -g root -m 0755 /tmp/zabbix/bin/zabbix_sender /usr/local/bin/zabbix_sender; \
            install -o root -g root -m 0644 /tmp/zabbix/conf/zabbix_agentd.conf /etc/zabbix/zabbix_agentd.conf; \
            install -d -o root -g root -m 0755 /etc/zabbix/zabbix_agentd.d; \
            install -d -o zabbix -g zabbix -m 0755 /var/log/zabbix; \
            sed -i 's@^LogFile=.*@LogFile=/var/log/zabbix/zabbix_agentd.log@' /etc/zabbix/zabbix_agentd.conf; \
            rm -rf /tmp/zabbix; \
            ;; \
        *) \
            echo "skip zabbix-agent for TARGETARCH=$TARGETARCH (amd64 static binary only)"; \
            ;; \
    esac; \
    echo;

# https://github.com/etcd-io/etcd
COPY --from=gcr.io/etcd-development/etcd:v3.7.4 /usr/local/bin/etcdctl /usr/local/bin/etcdctl

# https://github.com/VictoriaMetrics/VictoriaMetrics
COPY --from=victoriametrics/vmagent:v1.157.0 /vmagent-prod /usr/local/bin/vmagent

RUN set -eux; \
    echo "安装 docker-cli https://docs.docker.com/engine/install/ubuntu/"; \
    install -m 0755 -d /etc/apt/keyrings; \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc; \
    chmod a+r /etc/apt/keyrings/docker.asc; \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null; \
    apt-get update && apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin; \
    rm -rf /etc/apt/sources.list.d/docker.list; \
    rm -rf /etc/apt/keyrings/docker.asc; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*;

RUN set -eux; \
    echo "安装 fluent-bit"; \
    curl https://raw.githubusercontent.com/fluent/fluent-bit/master/install.sh | sh; \
    apt-get autoremove -y; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*;

RUN set -eux; \
    echo "apt 包安装"; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
				ipmitool dmidecode smartmontools hardinfo lsscsi nvme-cli \
				dnsutils ripgrep fd-find \
                tcpdump iperf3 \
                redis virt-what freeipmi ; \
    apt-get autoremove -y; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*;

RUN set -eux; \
    echo "安装 oras"; \
    _tag_name="$(curl -fsSL https://api.github.com/repos/oras-project/oras/releases/latest | jq -er '.tag_name')"; \
    _oras_version="${_tag_name#v}"; \
    case "$TARGETARCH" in \
        amd64|arm64) _arch="$TARGETARCH" ;; \
        *) echo "unsupported TARGETARCH=$TARGETARCH" >&2; exit 1 ;; \
    esac; \
    curl -fL -o "/tmp/oras_${_oras_version}_linux_${_arch}.tar.gz" "https://github.com/oras-project/oras/releases/download/${_tag_name}/oras_${_oras_version}_linux_${_arch}.tar.gz"; \
    mkdir -p /tmp/oras-install; \
    tar -zxf "/tmp/oras_${_oras_version}_linux_${_arch}.tar.gz" -C /tmp/oras-install; \
    mv /tmp/oras-install/oras /usr/local/bin/oras; \
    rm -rf "/tmp/oras_${_oras_version}_linux_${_arch}.tar.gz" /tmp/oras-install; \
    echo;

RUN set -eux; \
    echo "安装 uv"; \
    curl -LsSf https://astral.sh/uv/install.sh | sh; \
    export PATH="/root/.local/bin:$PATH"; \
    uv python install "${PYTHON_VERSION}"; \
    uv venv /opt/venv --python "${PYTHON_VERSION}" --system-site-packages; \
    uv pip install --python /opt/venv/bin/python pip; \
    /opt/venv/bin/pip config set global.index-url https://mirrors.ustc.edu.cn/pypi/simple; \
    echo; 

RUN set -eux; \
    echo "软链接"; \
    rm -rf /etc/cron.d/; \
    ln -sf /app/data/.gitrce/cron.d/ /etc/cron.d; \
    ln -sf /bin/bash /bin/sh; \
    mkdir -p /root/.ssh; \
    chmod 700 /root/.ssh; \
    echo "StrictHostKeyChecking no" >> /root/.ssh/config; \
    if [ ! -L "/etc/cron.d" ]; then exit 1; fi; \
    echo;

ENV PATH=/root/.local/bin:/opt/venv/bin:/opt/fluent-bit/bin:$PATH
ENV TZ=Asia/Shanghai
ENV PYTHONDONTWRITEBYTECODE=1
# 让仓库脚本 boot/start.sh 里的 uv sync 使用托管的 Python, 而不是系统的 3.14.4
ENV UV_PYTHON=${PYTHON_VERSION}

WORKDIR /app/data
COPY containers/latest/app/ /app/
ENTRYPOINT ["tini", "--"]
CMD ["bash", "/app/.entry.sh"]

LABEL org.opencontainers.image.source=https://github.com/lwmacct/250209-cr-gitrce
LABEL org.opencontainers.image.description="gitrce"
LABEL org.opencontainers.image.licenses=MIT
