#!/bin/bash
# Criado por Kivya Pottechi

WILDFLY_STANDALONE=/usr/wildfly/standalone
CHINCHILA_CLIENT_DIR=$WILDFLY_STANDALONE/chinchila-client
CHINCHILA_PDV_DIR=$WILDFLY_STANDALONE/chinchila-pdv
CHINCHILA_BROKER_DIR=$WILDFLY_STANDALONE/chinchila-broker
CHINCHILA_UPDATE_PGKS_DIR=$WILDFLY_STANDALONE/chinchila-update-pkgs
DEPLOYMENTS_DIR=$WILDFLY_STANDALONE/deployments

# Funções de mensagem
function msg(){
  echo -e "\e[36;1m$1\e[0m"
}

function error(){
  echo -e "\e[31;1m$1\e[0m"
}

function warn(){
  echo -e "\e[33;1m$1\e[0m"
}

if [ $UID -eq 0 ]; then
  error "NÃO executar como root!"
  exit 1
fi

# Solicitar o link do pacote
msg "Insira o link do pacote de atualização(linha mirror1 em http://update.a7.net.br/atualizacoes.xml):"
read -p "Link: " package_link

# Baixar o pacote
msg "Baixando pacote de atualização..."
wget -c "$package_link" -P "$CHINCHILA_UPDATE_PGKS_DIR" || {
  error "Falha ao baixar o pacote. Verifique o link e se há conectividade com a internet."
  exit 1
}

PACOTE="$CHINCHILA_UPDATE_PGKS_DIR/$(basename "$package_link")"

# Parar o serviço WildFly
msg "Parando o serviço WildFly..."
if ! sudo service wildfly stop; then
  warn "Falha ao parar o serviço WildFly. Tentando encerrar com kill -9..."
  PID=$(pgrep -f 'wildfly')
  if [ -n "$PID" ]; then
    kill -9 $PID && msg "WildFly encerrado com sucesso via kill -9." || {
      error "Não foi possível encerrar o processo WildFly."
      exit 1
    }
  else
    error "Processo WildFly não encontrado."
    exit 1
  fi
fi

# Verificar e baixar o script aplicarAtualizacao.sh
if [ ! -f "aplicarAtualizacao.sh" ]; then
  msg "Baixando o script de atualização..."
  wget -q "http://a7.net.br/scherrer/aplicarAtualizacao.sh" || {
    error "Falha ao baixar o script aplicarAtualizacao.sh."
    exit 1
  }
else
  msg "Script aplicarAtualizacao.sh já existe. Pulando o download."
fi

# Aplicar a atualização
msg "Aplicando o pacote de atualização..."
bash "aplicarAtualizacao.sh" "$PACOTE" || {
  error "Falha ao aplicar a atualização. Verifique o script e as permissões."
  exit 1
}

# Iniciar o serviço WildFly
msg "Iniciando o serviço WildFly..."
sudo service wildfly start || {
  error "Falha ao iniciar o serviço WildFly. Verifique se há permissões adequadas."
  exit 1
}

msg "Sistema atualizado com sucesso!"
