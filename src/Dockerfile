FROM ubuntu:22.04

# Evitar prompts interativos
ENV DEBIAN_FRONTEND=noninteractive

# Environment variables for multiple users support
ENV SAMBA_USERS="" 
ENV SAMBA_PASSWORDS="" 
ENV SHARED_FOLDER_PERMISSIONS="755"

# Instalar dependências
RUN apt-get update && \
    apt-get install -y \
    samba \
    samba-common-bin \
    supervisor \
    procps \
    net-tools \
    smbclient \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Criar usuário não-root com UID/GID 1000
RUN groupadd -g 1000 sambauser && \
    useradd -r -u 1000 -g 1000 -s /bin/false -d /var/lib/samba sambauser

# Criar diretórios necessários
RUN mkdir -p /shared \
    /var/log/samba \
    /var/lib/samba/private \
    /var/lib/samba/locks \
    /etc/supervisor/conf.d \
    /run/samba

# Copiar arquivos de configuração
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY smb.conf /etc/samba/smb.conf

# Definir permissões do script
RUN chmod +x /usr/local/bin/entrypoint.sh 

# Definir permissões dos diretórios
RUN chown -R sambauser:sambauser /shared \
    && chmod ${SHARED_FOLDER_PERMISSIONS:-755} /shared

# Criar arquivos de log
RUN touch /var/log/samba/log.nmbd /var/log/samba/log.smbd \
    && chown sambauser:sambauser /var/log/samba/log.*

# Expor portas
EXPOSE 139 445 137/udp 138/udp

# Definir volumes
VOLUME ["/shared", "/var/log/samba"]

# Manter como root para gerenciar serviços
USER root

# Ponto de entrada
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
