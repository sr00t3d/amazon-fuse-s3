# Amazon S3 Bucket Manager 🪣

A comprehensive bash script for managing Amazon S3 buckets on Linux servers with FTP integration.

# About 📝
This tool automates the process of mounting and managing S3 buckets as local filesystems using s3fs-fuse, with additional FTP server integration for easy remote access.

- Author 👨‍💻
- Percio Andrade
- Email: percio@zendev.com.br
- Website: Zendev : https://zendev.com.br

# Features ✨
- 🔧 Automated FUSE and S3FS installation
- 📦 S3 bucket mounting and management
- 📡 FTP server integration (vsftpd)
- 📊 Detailed operation logging
- 👥 User management and permissions
- 🔄 Automatic fstab configuration

# Requirements 📋
- 🔑 Root/sudo access
- ☁️ AWS credentials configured
- 🌐 Internet connectivity
- 🛠️ Basic system utilities:
  - curl
  - wget
  - git

# Installation 💿
```bash
git clone https://github.com/percioandrade/amazon-fuse-s3
cd s3bucket
chmod +x s3bucket
```

# Usage 🚀
```bash
# Install FUSE and S3FS components
./s3bucket -i

# Create and mount a new S3 bucket
./s3bucket -e

# Remove an existing bucket
./s3bucket -r

# Install and configure FTP server
./s3bucket -ftp

# Display help information
./s3bucket -h
```

# Configuration ⚙️
- AWS credentials are stored in `~/.passwd-s3fs`
- FTP configuration in `/etc/vsftpd/vsftpd.conf`
- Mount points configured in `/etc/fstab`

# Logs 📝
- System-wide logs in `/var/log/buckets3.log`
- User-specific logs in `$USERPATH/$USER/buckets3-$USER.log`
- Master log file in `$USERPATH/buckets3.log`

# Screens
<img src="http://i.imgur.com/yPDtfQL.png" />

<br />

<img src="http://i.imgur.com/3tzJUhi.png" />

<br />

<img src="http://i.imgur.com/R35QWtp.png" />

# Support 💬
For support, please contact: support@zendev.com.br

# Notes 📌
- Always backup your data before mounting new buckets
- Keep AWS credentials secure
- Monitor system logs for any mounting issues
- Ensure proper file permissions

# License 📄
This project is licensed under the GNU General Public License v2.0