#!/bin/bash
set -e

# 0. 变量兜底
USER=${USER:-zv}
PWD=${PWD:-105106}
TZ=${TZ:-Asia/Shanghai}

# 1. 动态创建用户并配置权限
if ! id -u "${USER}" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "${USER}" || true
fi

# 2. 设置 Root 和自定义用户密码
echo "${USER}:${PWD}" | chpasswd
echo "root:${PWD}" | chpasswd
echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-custom-user

# 3. 注入 sctl 别名
for HOME_DIR in "/root" "/home/${USER}"; do
    if [ -d "$HOME_DIR" ]; then
        sed -i '/alias sctl=/d' "$HOME_DIR/.bashrc"
        echo "alias sctl='sudo supervisorctl'" >> "$HOME_DIR/.bashrc"
        if [ "$HOME_DIR" != "/root" ]; then
            chown -R "${USER}:${USER}" "$HOME_DIR" || true
        fi
    fi
done

# 4. 时区设置
if [ -w /etc/localtime ]; then
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
    echo $TZ > /etc/timezone
fi

# 5. 清理旧的 PID/Sock 文件确保顺利启动
rm -f /var/run/supervisor.sock /var/run/supervisord.pid

# 6. 启动进程管理器
echo "Starting system with User: $USER (Root access enabled via sudo)"
exec /usr/bin/supervisord -n -c /etc/supervisord.conf
