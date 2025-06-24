#!/bin/bash
##################################################################
# Author  : Percio Andrade
# Email   : perciocastelo@gmail.com
# Info    : Shell script to install and manage S3 on server
# Version : 2.3
##################################################################

V="2.3"

# Define variables for paths and URLs
srcPath="/usr/local/src"
LIBFUSE="http://pkgs.fedoraproject.org/repo/pkgs/fuse/fuse-2.9.4.tar.gz/ecb712b5ffc6dffd54f4a405c9b372d8/fuse-2.9.4.tar.gz"
USERPATH="/home"

# Function to display the help message
function display_help() {
    cat <<-EOF

Usage: $0 [-i|--install] [-e|--enable] [-r|--remove] [-ftp|--ftp] [-h|--help] [-f|--force]

Options:
        -i, --install     Install FuseS3 and FuseLib
        -e, --enable      Create bucket on the server
        -r, --remove      Remove bucket from the server
        -ftp, --ftp       Install VSTP FTP server
        -h, --help        Display this help message
        -f, --force       Use with 'install' to reinstall all libraries
EOF
}

# Check for help option
if [[ $1 == "-h" ]] || [[ $1 == "--help" ]]; then
    display_help
    exit 0
fi

# Check if no arguments provided
if [[ -z "$1" ]]; then
    echo -e "\nError: Please insert at least one argument"
    echo -e "Use -h or --help to check available commands\n"
    exit 1
fi

function log_files() {
    local bucketName="$1"
    local userName="$2"
    local userHomePath="$3"

    # Log file for individual user
    echo -e "DATE: $(date)          BUCKET NAME: $bucketName             USERNAME: $userName         DIR: $userHomePath/$userName/$bucketName\n" >> "$userHomePath/$userName/buckets3-$userName.log"
    # Master log file for all valid accounts
    echo -e "DATE: $(date)          BUCKET NAME: $bucketName             USERNAME: $userName         DIR: $userHomePath/$userName/$bucketName\n" >> "$userHomePath/buckets3.log"
    # Global log file
    echo -e "DATE: $(date)          BUCKET NAME: $bucketName             USERNAME: $userName         DIR: $userHomePath/$userName/$bucketName\n" >> "/var/log/buckets3.log"
}

function create_welcome_file() {
    local userName="$1"
    local userHomePath="$2"

    echo "[+] - Creating Welcome File"
    echo -e "Welcome to your S3 bucket!\n\nThis is a placeholder text. Feel free to customize this welcome message." > "$userHomePath/$userName/readme.txt"
    echo "[+] - Welcome file created"
}

# Install function
function install_s3fs() {
    # REMOVE OLD FUSE
    CHECK_FUSE=$(rpm -qa | grep fuse)

    if [[ -n "$CHECK_FUSE" ]]; then
        yum remove -y fuse fuse-s3fs
    fi

    # CHECK DEPENDENCIES
    echo "[+] - Installing Dependencies, please wait..."
    yum install -y libstdc++-devel curl-devel automake gcc gcc-c++ git libxml2-devel make openssl-devel &> /dev/null

    # COMPILE FUSE
    if [[ ! -f "/usr/local/lib/libfuse.so" ]] || [[ $2 == "-f" ]] || [[ $2 == "--force" ]]; then
        echo "[!] - LibFuse not found or force option used, installing..."
        rm -rf "$srcPath/fuse/"
        cd "$srcPath" && mkdir fuse && wget "$LIBFUSE" -O fuse.tar.gz && tar -xvf fuse.tar.gz -C fuse/ && cd fuse/fuse* || exit
        ./configure --prefix=/usr/local
        make && make install
        export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig
        ldconfig
        modprobe fuse
    else
        echo "[!] - Fuse already compiled"
    fi

    # CHECK IF SF3-FUSE HAS COMPILED
    if [[ ! -f "/usr/local/bin/s3fs" ]] || [[ $2 == "-f" ]] || [[ $2 == "--force" ]]; then
        echo "[!] - S3FS not found or force option used"
        rm -rf "$srcPath/s3fs-fuse/"
        cd "$srcPath" && git clone https://github.com/s3fs-fuse/s3fs-fuse.git && cd s3fs-fuse || exit
        ./autogen.sh
        ./configure
        make
        make install
    else
        echo "[!] - S3FS already compiled"
    fi

    # ENABLE FUSE S3
    if ! grep -q "/usr/local/lib/" /etc/ld.so.conf; then
        echo "/usr/local/lib/" >> /etc/ld.so.conf
        ldconfig
    fi

    # CONFIGURE S3FS
    if [[ ! -f "$HOME/.passwd-s3fs" ]] || [[ ! -s "$HOME/.passwd-s3fs" ]]; then
        echo -e "[!] - You need to create your AWS keys to allow access to s3fuse"
        echo -e "[!] - You can create keys here: https://console.aws.amazon.com/iam/home?region=sa-east-1#security_credential"
        echo -e "[!] - Creating configuration file..."
        echo "[!] - Insert your details"
        read -rsp "Insert AWS Key: " awsAccessKey
        echo
        read -rsp "Insert AWS PrivateKey: " awsPrivateKey
        echo
        echo "$awsAccessKey:$awsPrivateKey" > "$HOME/.passwd-s3fs"
        if [[ -z "$awsAccessKey" ]] || [[ -z "$awsPrivateKey" ]]; then
            echo "[+] - Values are empty, try again"
            exit 1
        fi
        chmod 600 "$HOME/.passwd-s3fs"
        echo "user_allow_other" >> /etc/fuse.conf # Enable normal users to access on FTP
        echo "[+] - S3FS was configured"
    else
        echo "[+] - S3Fuse config already exists at $HOME/.passwd-s3fs, remove this file first if you want to reconfigure"
    fi
}

# Function to create log files
function log_files() {
    # Log file for individual user
    log_user_bucket "$userName" "$bucketName" "$userHomePath/$userName/$bucketName"
    # Master log file for all valid accounts
    log_all_buckets "$userName" "$bucketName" "$userHomePath/$userName/$bucketName"
    # Global log file
    log_global_bucket "$userName" "$bucketName" "$userHomePath/$userName/$bucketName"
}

# Function to create a welcome file
function create_welcome_file() {
    create_welcome_message "$userHomePath/$userName/readme.txt"
}

# Enable bucket function
function enable_bucket() {
    echo -e "\n-----------------------------------------------------------------"
    echo "                    S3BUCKET - buckets3"
    echo -e "-----------------------------------------------------------------\n"
    read -rp "Inform the bucket name: " bucketName
    read -rp "Inform the username to install bucket: " userName

    if [[ -z "$bucketName" ]] || [[ -z "$userName" ]]; then
        echo -e "\n[!] - Values are empty, try again\n"
        exit 1
    fi

    echo "[+] - OK, this is all we need. Confirm that the values are correct"

    echo -e "|-------------------------------------------------------"
    echo "| BUCKETNAME: $bucketName"
    echo "| USERNAME: $userName"
    echo "| PATH: $userHomePath/$userName/$bucketName"
    echo -e "|-------------------------------------------------------"

    read -rp "Proceed? (y/n): " CONFIRM
    if [[ $CONFIRM != "y" ]]; then
        echo "[!] - Exiting..."
        exit 0
    fi

    # CHECK IF USER EXIST
    if ! id "$userName" &>/dev/null; then
        echo "[!] - User $userName not found. adding."
        useradd -d "$userHomePath/$userName" -m "$userName"
        echo "[!] - The user will be created, please enter a password"
        read -rsp "Password: " userPassw
        echo
        echo "$userName:$userPassw" | chpasswd
        echo "[+] - Done."
    else
        echo "[!] - User $userName already exists"
    fi

    # CHECK IF USER HAS HOMEDIR
    if [[ -d "$userHomePath/$userName" ]]; then
        echo -e "\n[+] - Homedir for user $userName found"
        echo "[+] - This script will mountpoint for user in $userHomePath/$userName/$bucketName"
        echo "[!] - Making the bucket directory"
    else
        echo -e "\n[!] - Homedir for user $userName not found."
        echo -e "\n[!] - Creating directory"
        mkdir -p "$userHomePath/$userName" && chown "$userName:$userName" "$userHomePath/$userName" && chmod 700 "$userHomePath/$userName"
        echo "[!] - Making the bucket directory"
    fi

    if [[ -d "$userHomePath/$userName/$bucketName" ]]; then
        echo "[!] - Bucket for user $userName already exists."
        echo "[!] - Remove first, after run this script again"
    else
        mkdir -p "$userHomePath/$userName/$bucketName"
        chmod 755 "$userHomePath/$userName/$bucketName"
        chown "$userName:$userName" "$userHomePath/$userName/$bucketName"
        echo "[+] - Mounting..."
        /usr/local/bin/s3fs "$userName" -o use_rrs -o allow_other -o default_acl=public-read "$userHomePath/$userName/$bucketName"
        echo "[+] - Saving on fstab..."
        echo "#buckets3 for user $userName on $userHomePath/$userName/$bucketName" >> /etc/fstab
        echo "s3fs#$bucketName $userHomePath/$userName/$bucketName fuse _netdev,allow_other,nodnscache,retries=5 0 0" >> /etc/fstab

        # DISABLE PERMISSION OF WRITE ON USER HOME FTP
        chmod 0555 "$userHomePath/$userName/"

        # CHECK IF IS MOUNTED
        echo "[!] - Checking if is mounted"
        if df -h | grep -q "$userHomePath/$userName/$bucketName"; then
            echo "[+] - Bucket for $userName was mounted correctly"
        else
            echo "[!] - Warning, bucket for $userName NOT MOUNTED, ask to sysadmin to check it"
        fi

        log_files  # Create log files
        create_welcome_file  # Create welcome file

        echo -e "[+] - All Done.\n"

        # CHECK IF FTP HAS ENABLED
        if [[ -e "/etc/vsftpd/user_list" ]]; then
            if ! grep -q "$userName" /etc/vsftpd/user_list; then
                echo "[+] - Enabling FTP for $userName"
                echo "$userName" >> /etc/vsftpd/user_list
                systemctl restart vsftpd
            else
                echo "[!] - User already has FTP enabled"
            fi
        fi
    fi
}

# Remove bucket function
function remove_bucket() {
    echo -e "\n[!] - Remove bucket process\n"
    read -rp "Insert username to remove bucket: " userBucketNameRemove
    echo "[!] - Searching bucket for user $userBucketNameRemove ...."
    echo -e "\n"; grep "$userBucketNameRemove" "$userHomePath/buckets3.log"; echo -e "\n"

    if [[ -z $userBucketNameRemove ]]; then
        echo "[!] - $userBucketNameRemove not found. Please inform PATH of bucket"
    else
        echo "[+] - Bucket for $userBucketNameRemove was found"
    fi

    read -rp "Insert Bucket Path: " userBucketPathRemove
    echo "[+] - Checking if is mounted"
    df -h | grep "$userBucketPathRemove"

    if [[ -n $userBucketPathRemove ]]; then
        # UMOUNT BUCKET
        umount -l "$userBucketPathRemove"
        echo "[+] - Bucket located on $userBucketPathRemove was stopped"
        df -h | grep "$userBucketPathRemove"

        # REMOVING ON LOGS
        getBucketRemoveLog=$(echo "$userBucketPathRemove" | sed -e 's/\//\\\//g')
        sed -i "/$getBucketRemoveLog=/d" "$userHomePath/buckets3.log"

        # REMOVING ON FSTAB
        getBucketRemoveFSTab=$(echo "$userBucketPathRemove" | sed -e 's/\//\\\//g') # CONVERT / to \/ for sed work correctly
        sed -i "/$getBucketRemoveFSTab/d" /etc/fstab
    else
        echo "[!] - Bucket $userBucketPathRemove not found"
    fi
}

# Install FTP function
function install_ftp() {
    # CHECK IF WAS INSTALLED
    if ! rpm -q vsftpd &>/dev/null; then
        echo -e "[!] - Installing FTP"
        yum install -y vsftpd
        sed -i 's/anonymous_enable=YES/anonymous_enable=NO/g' /etc/vsftpd/vsftpd.conf
        cat <<EOF >> /etc/vsftpd/vsftpd.conf

pasv_enable=YES
pasv_min_port=1024
pasv_max_port=1048
userlist_deny=NO
pasv_address=CHANGE_HERE_IP
EOF

        # GET PUBLICIP
        IP=$(curl --silent http://ipecho.net/plain)
        sed -i "s/pasv_address=CHANGE_HERE_IP/pasv_address=$IP/g" /etc/vsftpd/vsftpd.conf
        sed -i "s/#chroot_local_user=YES/chroot_local_user=YES/g" /etc/vsftpd/vsftpd.conf
        systemctl restart vsftpd
        systemctl enable vsftpd
    else
        echo "FTP already installed"
    fi
}

# Main script
case $1 in
    "-i"|"--install")
        install_s3fs "$@"
        ;;
    "-e"|"--enable")
        enable_bucket
        ;;
    "-r"|"--remove")
        remove_bucket
        ;;
    "-ftp"|"--ftp")
        install_ftp
        ;;
    *)
        echo "Invalid option. Use -h or --help for usage information."
        exit 1
        ;;
esac

