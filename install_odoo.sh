echo "Start Odoo Installation"
folder="Odoo-15-0"
version="15.0"
odoo_user="odoo-15"
odoo_group="odoo-15"
env_name="Odoo-15-0-env"
conf="Odoo15v2.conf "
service="odoo15.service"


# Define variables for config
admin="@007Jamesbond@"
host="localhost"
folder="Odoo-15-0"

DB_NAME="odoo15"
user="odoo15"
password="1234"
port="5433"
PG_USER="postgres"

# Check if database exists
db_exists=$(sudo -u $PG_USER psql -h $host -p $port -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'")
if [ -z "$db_exists" ]; then
    echo "Database $DB_NAME does not exist. Creating..."
    sudo -u $PG_USER psql -h $host -p $port -c "CREATE DATABASE $DB_NAME;"
else
    echo "Database $DB_NAME already exists."
fi

# Check if user exists
user_exists=$(sudo -u $PG_USER psql -h $host -p $port -tAc "SELECT 1 FROM pg_roles WHERE rolname='$user'")
if [ -z "$user_exists" ]; then
    echo "User $user does not exist. Creating..."
    sudo -u $PG_USER psql -h $host -p $port -c "CREATE USER $user WITH PASSWORD '$password';"
else
    echo "User $user already exists."
fi

# Grant privileges to the user on the database
echo "Granting privileges to $user on database $DB_NAME..."
sudo -u $PG_USER psql -h $host -p $port -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $user;"

echo "Database $DB_NAME, user $user, and privileges have been set up successfully."





#Create Odoo if not exist
if [ ! -d "/opt/Odoo" ]; then
    sudo mkdir /opt/Odoo/
fi


#Create server if not exist
if [ ! -d "/opt/Odoo/server" ]; then
    sudo mkdir /opt/Odoo/server
fi

#Create venv if not exist
if [ ! -d "/opt/Odoo/venv" ]; then
    sudo mkdir /opt/Odoo/venv
fi

#Create conf if not exist
if [ ! -d "/opt/Odoo/conf" ]; then
    sudo mkdir /opt/Odoo/conf
fi


# Create directory if it doesn't exist
if [ ! -d "/opt/Odoo/server/$folder" ]; then
    sudo mkdir /opt/Odoo/server/$folder
fi

sudo chmod -R +777 /opt/Odoo/venv

# Clone Odoo repo
sudo git clone https://www.github.com/odoo/odoo --depth 1 --branch $version --single-branch /opt/Odoo/server/$folder/



# Create group and user if they don't exist
if ! getent group $odoo_group; then
    sudo groupadd $odoo_group
fi

if ! id -u $odoo_user > /dev/null 2>&1; then
    sudo useradd -m -g $odoo_group -s /bin/bash $odoo_user
fi

# Install python3-venv if it's not installed
sudo apt-get install -y python3-venv



echo "Creating Virtual Environment"
sudo -u odoo python3 -m venv /opt/Odoo/venv/$env_name
echo "Virtual Environment Created"

# Change ownership and permissions
sudo chown -R $odoo_group:$odoo_group /opt/Odoo/venv/$env_name
sudo chmod -R 775 /opt/Odoo/venv/$env_name
sudo chmod -R +777 /opt/Odoo/venv/$env_name

# Install dependencies in virtual environment
sudo -u odoo bash -c ". /opt/Odoo/venv/$env_name/bin/activate && pip install -r /opt/Odoo/server/$folder/requirements.txt"





# Create configuration file

sudo bash -c "cat > /opt/Odoo/conf/$conf <<EOF
[options]
; This is the password that allows database operations:
admin_passwd = $admin
db_host = $host
db_port = $port
db_user = $user
db_password = $password
addons_path = /opt/Odoo/server/$folder/addons,/opt/Odoo/server/$folder/odoo/addons
xmlrpc_port = 8069
EOF"

sudo chmod -R 777 /opt/Odoo/conf/$conf
echo "Configuration file created at /opt/Odoo/conf/$conf"





# Create systemd service for Odoo
echo "Creating Odoo systemd service"


environment="VIRTUAL_ENV=/opt/Odoo/venv/$env_name"
environment2="PATH=$VIRTUAL_ENV/bin:$PATH"
environment3="PYTHONPATH=/opt/Odoo/venv/$env_name/lib/python3.12/site-packages"

sudo bash -c "cat > /etc/systemd/system/$service <<EOF
[Service]
Type=simple
User=odoo
Group=odoo
WorkingDirectory=/opt/Odoo/server/$folder

# Set environment variables for virtual environment
Environment="$environment"
Environment="$environment2"
Environment="$environment3"

ExecStart=/bin/bash -c 'source /opt/Odoo/venv/$env_name/bin/activate && exec /opt/Odoo/venv/$env_name/bin/python3 /opt/Odoo/server/$folder/odoo-bin -c /opt/Odoo/conf/$conf'

#StandardOutput=append:/var/log/odoo/odoo.log
#StandardError=append:/var/log/odoo/odoo.log

StandardOutput=journal
StandardError=journal

Restart=always
LimitNOFILE=4096
TimeoutStartSec=300
EOF"

echo "Odoo Service File Creation Done"