#!/bin/bash
################################################################################
#                                                                              #
#   PROJECT: S3 Fuse & VSFTPD Manager                                          #
#   VERSION: 3.0.0                                                             #
#                                                                              #
#   AUTHOR:  Percio Andrade                                                    #
#   CONTACT: percio@evolya.com.br                                              #
#   WEB:     https://perciocastelo.com.br | contato@perciocastelo.com.br       #
#                                                                              #
#   INFO:                                                                      #
#   Install s3fs-fuse, create buckets/users and setup VSFTPD.                  #
#                                                                              #
################################################################################

# --- CONFIGURATION ---
SRC_PATH="/usr/local/src"
BASE_HOME="/home"
FUSE_LIB_URL="https://github.com/libfuse/libfuse/releases/download/fuse-2.9.9/fuse-2.9.9.tar.gz"
LOG_GLOBAL="/var/log/buckets3.log"
LOG_MASTER="$BASE_HOME/buckets3.log"
# ---------------------

# Detect System Language
SYSTEM_LANG="${LANG:0:2}"

if [[ "$SYSTEM_LANG" == "pt" ]]; then
    # Portuguese Strings
    MSG_USAGE="Uso: $0 [-i|--install] [-e|--enable] [-r|--remove] [-ftp|--ftp] [-h|--help] [-f|--force]"
    MSG_ERR_ROOT="ERRO: Este script precisa ser executado como root."
    MSG_ERR_ARG="ERRO: Por favor, insira pelo menos um argumento."
    MSG_ERR_EMPTY="ERRO: Valores vazios. Tente novamente."
    MSG_INSTALL_DEPS="[+] Instalando dependências, aguarde..."
    MSG_COMPILING="[+] Compilando"
    MSG_INSTALLED="já está instalado/compilado."
    MSG_AWS_CONFIG="[!] Configuração AWS necessária."
    MSG_AWS_LINK="[!] Crie suas chaves em: https://console.aws.amazon.com/iam/"
    MSG_INSERT_KEY="Insira a AWS Access Key: "
    MSG_INSERT_SECRET="Insira a AWS Secret Key: "
    MSG_BUCKET_NAME="Informe o nome do Bucket S3: "
    MSG_USER_NAME="Informe o usuário do sistema: "
    MSG_CONFIRM="Proceder? (y/n): "
    MSG_USER_ADD="[!] Usuário não encontrado. Criando..."
    MSG_USER_PASS="Defina uma senha para"
    MSG_MOUNTING="[+] Montando bucket e atualizando fstab..."
    MSG_CHECK_MOUNT="[!] Verificando montagem..."
    MSG_MOUNT_OK="[+] Bucket montado com sucesso!"
    MSG_MOUNT_FAIL="[!] AVISO: Falha ao montar o bucket."
    MSG_FTP_ENABLE="[+] Habilitando FTP para"
    MSG_FTP_INSTALL="[!] Instalando VSFTPD..."
    MSG_REMOVE_TITLE="[!] Processo de remoção de bucket"
    MSG_REMOVE_USER="Insira o usuário para remover o bucket: "
    MSG_REMOVE_PATH="Insira o caminho do Bucket (ex: /home/user/bucket): "
    MSG_REMOVE_FOUND="[+] Bucket encontrado e desmontado."
    MSG_REMOVE_CLEAN="[+] Logs e Fstab limpos."
    MSG_DONE="[+] Processo concluído."
else
    # English Strings (Default)
    MSG_USAGE="Usage: $0 [-i|--install] [-e|--enable] [-r|--remove] [-ftp|--ftp] [-h|--help] [-f|--force]"
    MSG_ERR_ROOT="ERROR: This script must be run as root."
    MSG_ERR_ARG="ERROR: Please insert at least one argument."
    MSG_ERR_EMPTY="ERROR: Empty values. Try again."
    MSG_INSTALL_DEPS="[+] Installing dependencies, please wait..."
    MSG_COMPILING="[+] Compiling"
    MSG_INSTALLED="is already installed/compiled."
    MSG_AWS_CONFIG="[!] AWS Configuration required."
    MSG_AWS_LINK="[!] Create keys at: https://console.aws.amazon.com/iam/"
    MSG_INSERT_KEY="Insert AWS Access Key: "
    MSG_INSERT_SECRET="Insert AWS Secret Key: "
    MSG_BUCKET_NAME="Enter S3 Bucket Name: "
    MSG_USER_NAME="Enter System Username: "
    MSG_CONFIRM="Proceed? (y/n): "
    MSG_USER_ADD="[!] User not found. Creating..."
    MSG_USER_PASS="Set password for"
    MSG_MOUNTING="[+] Mounting bucket and updating fstab..."
    MSG_CHECK_MOUNT="[!] Checking mount status..."
    MSG_MOUNT_OK="[+] Bucket mounted successfully!"
    MSG_MOUNT_FAIL="[!] WARNING: Failed to mount bucket."
    MSG_FTP_ENABLE="[+] Enabling FTP for"
    MSG_FTP_INSTALL="[!] Installing VSFTPD..."
    MSG_REMOVE_TITLE="[!] Bucket Removal Process"
    MSG_REMOVE_USER="Enter username to remove bucket: "
    MSG_REMOVE_PATH="Enter Bucket Path (e.g., /home/user/bucket): "
    MSG_REMOVE_FOUND="[+] Bucket found and unmounted."
    MSG_REMOVE_CLEAN="[+] Logs and Fstab cleaned."
    MSG_DONE="[+] Process completed."
fi

# Help Function
function display_help() {
    cat <<-EOF

$MSG_USAGE

Options:
    -i, --install      Install FuseS3 and dependencies
    -e, --enable       Create user and mount S3 bucket
    -r, --remove       Unmount and remove bucket config
    -ftp, --ftp        Install and configure VSFTPD
    -h, --help         Display this help message
    -f, --force        Force reinstall of libraries
EOF
}

# Check Root
if [[ $EUID -ne 0 ]]; then
   echo "$MSG_ERR_ROOT"
   exit 1
fi

# Check Arguments
if [[ -z "$1" ]]; then
    echo "$MSG_ERR_ARG"
    display_help
    exit 1
fi

if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    display_help
    exit 0
fi

# unified Log Function
function write_log() {
    local bucket="$1"
    local user="$2"
    local path="$3"
    local date_now=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="DATE: $date_now | BUCKET: $bucket | USER: $user | DIR: $path"

    # User Log
    echo "$log_entry" >> "$BASE_HOME/$user/buckets3-$user.log"
    # Master Log
    echo "$log_entry" >> "$LOG_MASTER"
    # Global Log
    echo "$log_entry" >> "$LOG_GLOBAL"
}

# Install Function
function install_s3fs() {
    local FORCE=$2

    # Update/Install YUM dependencies
    echo "$MSG_INSTALL_DEPS"
    yum install -y gcc libstdc++-devel gcc-c++ fuse fuse-devel curl-devel libxml2-devel openssl-devel mailcap git automake make

    # Compile Fuse (Only if not present or forced)
    # Note: Modern CentOS 7/8/9 usually prefers 'yum install fuse', but keeping logic as requested.
    if [[ ! -f "/usr/local/lib/libfuse.so" ]] || [[ "$FORCE" == "-f" ]] || [[ "$FORCE" == "--force" ]]; then
        echo "$MSG_COMPILING Fuse..."
        rm -rf "$SRC_PATH/fuse/"
        mkdir -p "$SRC_PATH/fuse"
        
        # Using a more reliable source or relying on yum is better, but here is the manual way:
        cd "$SRC_PATH"
        # Download fuse source (updated link logic if needed, using variable)
        wget "$FUSE_LIB_URL" -O fuse.tar.gz
        tar -xvf fuse.tar.gz -C fuse --strip-components=1
        cd fuse
        ./configure --prefix=/usr/local
        make && make install
        
        export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig
        ldconfig
        modprobe fuse
    else
        echo "Fuse $MSG_INSTALLED"
    fi

    # Compile S3FS
    if ! command -v s3fs &> /dev/null || [[ "$FORCE" == "-f" ]] || [[ "$FORCE" == "--force" ]]; then
        echo "$MSG_COMPILING S3FS..."
        rm -rf "$SRC_PATH/s3fs-fuse/"
        cd "$SRC_PATH"
        git clone https://github.com/s3fs-fuse/s3fs-fuse.git
        cd s3fs-fuse
        ./autogen.sh
        ./configure
        make && make install
    else
        echo "S3FS $MSG_INSTALLED"
    fi

    # Config Loader
    if ! grep -q "/usr/local/lib" /etc/ld.so.conf; then
        echo "/usr/local/lib" >> /etc/ld.so.conf
        ldconfig
    fi

    # AWS Credentials
    if [[ ! -s "$HOME/.passwd-s3fs" ]]; then
        echo "$MSG_AWS_CONFIG"
        echo "$MSG_AWS_LINK"
        
        read -r -p "$MSG_INSERT_KEY" awsAccessKey
        read -r -p "$MSG_INSERT_SECRET" awsSecretKey
        
        if [[ -z "$awsAccessKey" ]] || [[ -z "$awsSecretKey" ]]; then
            echo "$MSG_ERR_EMPTY"
            exit 1
        fi
        
        echo "$awsAccessKey:$awsSecretKey" > "$HOME/.passwd-s3fs"
        chmod 600 "$HOME/.passwd-s3fs"
        
        # Allow non-root users to mount
        if ! grep -q "user_allow_other" /etc/fuse.conf; then
            echo "user_allow_other" >> /etc/fuse.conf
        fi
        echo "$MSG_DONE"
    else
        echo "[!] $HOME/.passwd-s3fs exists."
    fi
}

# Enable Bucket Function
function enable_bucket() {
    echo -e "\n--- S3 BUCKET MANAGER ---\n"
    
    read -r -p "$MSG_BUCKET_NAME" bucketName
    read -r -p "$MSG_USER_NAME" userName

    if [[ -z "$bucketName" ]] || [[ -z "$userName" ]]; then
        echo "$MSG_ERR_EMPTY"
        exit 1
    fi

    echo "-------------------------"
    echo " BUCKET: $bucketName"
    echo " USER:   $userName"
    echo " PATH:   $BASE_HOME/$userName/$bucketName"
    echo "-------------------------"

    read -r -p "$MSG_CONFIRM" CONFIRM
    [[ "$CONFIRM" != "y" ]] && exit 0

    # User Management
    if ! id "$userName" &>/dev/null; then
        echo "$MSG_USER_ADD"
        useradd -d "$BASE_HOME/$userName" -m "$userName"
        echo "$MSG_USER_PASS $userName:"
        passwd "$userName"
    fi

    # Directory Setup
    USER_PATH="$BASE_HOME/$userName"
    MOUNT_POINT="$USER_PATH/$bucketName"

    mkdir -p "$MOUNT_POINT"
    chown "$userName:$userName" "$MOUNT_POINT"
    chmod 755 "$MOUNT_POINT"

    echo "$MSG_MOUNTING"
    
    # Mount
    /usr/local/bin/s3fs "$bucketName" "$MOUNT_POINT" \
    -o use_rrs -o allow_other -o default_acl=public-read \
    -o passwd_file="$HOME/.passwd-s3fs"

    # Fstab Persistence
    # Check if already in fstab to avoid duplicates
    if ! grep -q "$MOUNT_POINT" /etc/fstab; then
        echo "# S3FS for $userName" >> /etc/fstab
        echo "s3fs#$bucketName $MOUNT_POINT fuse _netdev,allow_other,passwd_file=$HOME/.passwd-s3fs,retries=5 0 0" >> /etc/fstab
    fi

    # Read-only Home, Write on Bucket (Security best practice for FTP users)
    chmod 555 "$USER_PATH"

    # Verification
    echo "$MSG_CHECK_MOUNT"
    if df -h | grep -q "$MOUNT_POINT"; then
        echo "$MSG_MOUNT_OK"
        write_log "$bucketName" "$userName" "$MOUNT_POINT"
        
        # Welcome File
        echo "Welcome to your S3 Storage!" > "$USER_PATH/readme.txt"
        chown "$userName:$userName" "$USER_PATH/readme.txt"
    else
        echo "$MSG_MOUNT_FAIL"
    fi

    # Auto Enable FTP if User List exists
    if [[ -f "/etc/vsftpd/user_list" ]]; then
        if ! grep -q "$userName" /etc/vsftpd/user_list; then
            echo "$MSG_FTP_ENABLE $userName"
            echo "$userName" >> /etc/vsftpd/user_list
            systemctl restart vsftpd
        fi
    fi
}

# Remove Bucket Function
function remove_bucket() {
    echo "$MSG_REMOVE_TITLE"
    
    # Show active buckets from log
    if [[ -f "$LOG_MASTER" ]]; then
        echo "--- Active Buckets Log ---"
        tail -n 10 "$LOG_MASTER"
        echo "--------------------------"
    fi

    read -r -p "$MSG_REMOVE_USER" rUser
    read -r -p "$MSG_REMOVE_PATH" rPath

    if [[ -z "$rPath" ]]; then
        echo "$MSG_ERR_EMPTY"
        exit 1
    fi

    # Unmount
    if grep -qs "$rPath" /proc/mounts; then
        umount -l "$rPath"
        echo "$MSG_REMOVE_FOUND"
    else
        echo "[!] Path not mounted or invalid."
    fi

    # Clean Fstab (using | as delimiter for sed to handle paths)
    sed -i "\|$rPath|d" /etc/fstab
    
    # Clean Logs
    sed -i "\|$rPath|d" "$LOG_MASTER"

    echo "$MSG_REMOVE_CLEAN"
}

# FTP Install Function
function install_ftp() {
    echo "$MSG_FTP_INSTALL"
    
    if ! rpm -q vsftpd &>/dev/null; then
        yum install -y vsftpd
        
        # Backup config
        cp /etc/vsftpd/vsftpd.conf /etc/vsftpd/vsftpd.conf.bak
        
        # Configure
        sed -i 's/anonymous_enable=YES/anonymous_enable=NO/g' /etc/vsftpd/vsftpd.conf
        
        # Get External IP
        IP=$(curl -s --connect-timeout 5 ifconfig.me)
        
        # Append Config
        cat <<EOF >> /etc/vsftpd/vsftpd.conf

pasv_enable=YES
pasv_min_port=1024
pasv_max_port=1048
userlist_deny=NO
chroot_local_user=YES
pasv_address=$IP
EOF

        systemctl restart vsftpd
        systemctl enable vsftpd
        echo "$MSG_DONE IP: $IP"
    else
        echo "VSFTPD $MSG_INSTALLED"
    fi
}

# Main Execution
case $1 in
    "-i"|"--install") install_s3fs "$@" ;;
    "-e"|"--enable")  enable_bucket ;;
    "-r"|"--remove")  remove_bucket ;;
    "-ftp"|"--ftp")   install_ftp ;;
    *) display_help ;;
esac
