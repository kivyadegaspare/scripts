#!/bin/bash

WILDFLY_STANDALONE=/usr/wildfly/standalone
CHINCHILA_CLIENT_DIR=$WILDFLY_STANDALONE/chinchila-client
CHINCHILA_PDV_DIR=$WILDFLY_STANDALONE/chinchila-pdv
CHINCHILA_BROKER_DIR=$WILDFLY_STANDALONE/chinchila-broker
CHINCHILA_UPDATE_PGKS_DIR=$WILDFLY_STANDALONE/chinchila-update-pkgs
DEPLOYMENTS_DIR=$WILDFLY_STANDALONE/deployments

#
# Exemplo de uso via pipe:
#   bash -c "$(wget -q -O - https://a7.net.br/scherrer/aplicarAtualizacao.sh)" -s svr-2.13.12.0_cli-2.13.12.0_pdv-2.07.4.3-pkg
#

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

if [ -z "$1" ]; then
  msg "Uso:"
  msg "  $0 -l             lista as últimas 15 versões disponíveis"
  msg "  $0 pacote-versao  aplica a versão do pacote"
  msg "Exemplos:"
  msg "  $0 -l"
  msg "  $0 svr-2.13.12.0_cli-2.13.12.0_pdv-2.07.4.3-pkg.7z"
  msg "  $0 /home/alpha7/Downloads/svr-2.13.12.0_cli-2.13.12.0_pdv-2.07.4.3-pkg.7z"
  exit 1
fi

if [ "$1" == "-l" ]; then
  echo "Últimos 15 pacotes disponibilizados:"
  xmlstarlet select --net -t -m "/pacotes/pacote[tipo='release']" \
    -v "data" -o ' ' -v "nomeArquivo" \
    -n http://update.a7.net.br/atualizacoes.xml | tail -15 | sed 's/^/  /' \
    | tac
  exit 0
fi

PACOTE=$1

if [[ ! "$PACOTE" =~ \.7z$ ]]; then
  PACOTE=${PACOTE}.7z
fi


msg "Pacote: $PACOTE"

if [ ! -f "$PACOTE" ]; then
  if [ -f "$CHINCHILA_UPDATE_PGKS_DIR/$PACOTE" ]; then
    msg "Pacote $PACOTE encontrado em $CHINCHILA_UPDATE_PGKS_DIR"
    PACOTE="$CHINCHILA_UPDATE_PGKS_DIR/$PACOTE"
  elif [[ ! "$PACOTE" =~ / ]]; then
    while [[ ! "$baixar" =~ [snSN] ]]; do
      echo -en "Pacote não encontrado, deseja baixá-lo automaticamente? [s/n] "
      read baixar
    done

    if [[ "$baixar" =~ [nN] ]]; then
      exit 0
    fi

    wget -c http://update.a7.net.br/$PACOTE -P $CHINCHILA_UPDATE_PGKS_DIR || {
      error "Falha ao baixar o pacote. O nome está correto?"
      exit 1
    }

    PACOTE="$CHINCHILA_UPDATE_PGKS_DIR/$PACOTE"
  else
    error "$PACOTE não está acessível"
    exit 1
  fi
fi

sevenZPath=$(which 7za)

if [ $? -ne 0 ]; then
  error "Comando 7za não disponível (7zip não instalado? Instalar com: sudo yum install -y p7zip)"
  exit 1
fi


msg "Criando diretório temporário para extração do pacote"
tempDir=$(mktemp -d)

msg "Utilizando diretório $tempDir"


msg "Extraindo pacote"

$sevenZPath x -o${tempDir} "$PACOTE" || {
  error "Falha ao extrair o pacote"
  exit 1
}

msg "Pacote extraído"

fileName=$(basename $PACOTE)
extractedPackageDir=$tempDir/${fileName/-pkg.7z/}


warn 'ATENÇÃO: não continuar se o WildFly estiver em execução!'

while [[ ! "$continuar" =~ [snSN] ]]; do
  echo -en "continuar? [s/n]: "
  read continuar
done

if [[ "$continuar" =~ [nN] ]]; then
  exit 0
fi

wildfly_ps=$(ps ax | grep java | grep org.jboss.as.standalone | grep -v grep) && {
  error "WildFly em execução! É necessário parar o WildFly antes de aplicar a versão!"
  error "Abortando"
  exit 1
}

msg "Limpando diretórios $CHINCHILA_CLIENT_DIR, $CHINCHILA_PDV_DIR e $CHINCHILA_BROKER_DIR"

rm -rf $CHINCHILA_CLIENT_DIR/* || {
  error "Falha ao limpar o diretório $CHINCHILA_CLIENT_DIR"
  exit 1
}

rm -rf $CHINCHILA_PDV_DIR/* || {
  error "Falha ao limpar o diretório $CHINCHILA_PDV_DIR"
  exit 1
}

rm -rf $CHINCHILA_BROKER_DIR/* || {
  error "Falha ao limpar o diretório $CHINCHILA_BROKER_DIR"
  exit 1
}


msg "Copiando arquivos de $extractedPackageDir/Client para $CHINCHILA_CLIENT_DIR"

cp -ra $extractedPackageDir/Client/* $CHINCHILA_CLIENT_DIR/ || {
  error "Falhou"
  exit 1
}

msg "Copiando arquivos de $extractedPackageDir/PDV para $CHINCHILA_PDV_DIR"

cp -ra $extractedPackageDir/PDV/* $CHINCHILA_PDV_DIR/ || {
  error "Falhou"
  exit 1
}

msg "Copiando arquivos de $extractedPackageDir/Broker para $CHINCHILA_BROKER_DIR"

cp -ra $extractedPackageDir/Broker/* $CHINCHILA_BROKER_DIR/ || {
  error "Falhou"
  exit 1
}

msg "Copiando $extractedPackageDir/Servidor/chinchila.ear para $DEPLOYMENTS_DIR"

rm -rf $DEPLOYMENTS_DIR/chinchila.ear

cp -a $extractedPackageDir/Servidor/chinchila.ear $DEPLOYMENTS_DIR || {
  error "Falhou"
  exit 1
}

msg "Criando $DEPLOYMENTS_DIR/chinchila.ear.dodeploy"
touch $DEPLOYMENTS_DIR/chinchila.ear.dodeploy

msg "Removendo diretório temporário $tempDir"

rm -rf $tempDir || {
  error "Falhou"
}

msg "Feito"
