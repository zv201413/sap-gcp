FROM ubuntu:22.04

# 1. 环境变量
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai \
    USER=zv \
    PWD=105106 \
    CF_TOKEN='' \
    GCP_IP=''

# 2. 安装基础依赖 (构建阶段)
RUN apt-get update && apt-get install -y \
    openssh-server supervisor curl wget sudo ca-certificates \
    tzdata vim net-tools unzip iputils-ping telnet git iproute2 \
    && rm -rf /var/lib/apt/lists/*

# 3. 预装工具：Cloudflared, ttyd 和 EasyTier
RUN curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb \
    && dpkg -i cloudflared.deb \
    && rm cloudflared.deb \
    && curl -L https://github.com/tsl0922/ttyd/releases/download/1.7.3/ttyd.x86_64 -o /usr/local/bin/ttyd \
    && chmod +x /usr/local/bin/ttyd \
    && curl -L -o easytier.zip https://github.com/EasyTier/EasyTier/releases/download/v1.2.1/easytier-linux-x86_64.zip \
    && unzip easytier.zip && mv easytier-core /usr/bin/ && rm easytier.zip

# 4. SSH 基础配置
RUN mkdir -p /run/sshd && \
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config && \
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config && \
    ssh-keygen -A

# 5. 写入 Supervisord 配置 (注意变量引用方式)
RUN echo "[unix_http_server]\n\
file=/var/run/supervisor.sock\n\
chmod=0770\n\
chown=root:sudo\n\
\n\
[supervisord]\n\
nodaemon=true\n\
user=root\n\
logfile=/var/log/supervisord.log\n\
pidfile=/var/run/supervisord.pid\n\
\n\
[rpcinterface:supervisor]\n\
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface\n\
\n\
[supervisorctl]\n\
serverurl=unix:///var/run/supervisor.sock\n\
\n\
[program:sshd]\n\
command=/usr/sbin/sshd -D\n\
autorestart=true\n\
\n\
[program:cloudflared]\n\
command=bash -c \"/usr/bin/cloudflared tunnel --no-autoupdate run --token \${CF_TOKEN}\"\n\
autorestart=true\n\
\n\
[program:ttyd]\n\
command=/usr/local/bin/ttyd -p 8080 -W bash\n\
autorestart=true\n\
\n\
[program:easytier]\n\
command=/usr/bin/easytier-core --ipv4 10.6.0.2 --peers udp://\${GCP_IP}:11010 --proxy-networks 10.6.0.0/24\n\
autorestart=true" > /etc/supervisord.conf

# 6. 复制 Entrypoint 脚本
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22 8080

ENTRYPOINT ["/entrypoint.sh"]
