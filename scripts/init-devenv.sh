#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Confirm Git installation
if ! command_exists git; then
    echo "Git is not installed. Please install it from https://git-scm.com/install/"
    exit 1
fi

# Confirm Valkey or Redis installation
if command_exists valkey-server; then
    redis_command="valkey-server"
elif command_exists redis-server; then
    redis_command="redis-server"
else
    echo "Error: Neither Valkey nor Redis is installed. Please install from either https://valkey.io/download/ or https://redis.io/downloads/"
    exit 1
fi

# Determine home directory based on the operating system
if [ "$OSTYPE" == "msys" ] || [ "$OSTYPE" == "cygwin" ]; then
    # Windows
    home_dir=$(eval echo %USERPROFILE%)
elif [ "$OSTYPE" == "linux-gnu" ]; then
    # Linux
    home_dir="$HOME"
elif [ "$OSTYPE" == "darwin"* ]; then
    # macOS
    home_dir="$HOME"
else
    echo "Unsupported operating system."
    exit 1
fi

postgres_path="$home_dir/.atp-devenv/postgres"
pg_bin_folder=""

if [ ! -d "$postgres_path" ]; then
    mkdir -p "$postgres_path"
fi

# Determine the operating system and set pg_bin_folder accordingly
if [ "$(uname)" == "Linux" ]; then
    if command_exists postgres; then
        pg_bin_folder=$(dirname $(which postgres))
    elif [ -d "/usr/lib/postgresql/*/bin" ]; then
        pg_bin_folder="/usr/lib/postgresql/*/bin"
    elif [ -d "/usr/local/pgsql/bin" ]; then
        pg_bin_folder="/usr/local/pgsql/bin"
    elif whereis postgres > /dev/null 2>&1; then
        pg_bin_folder=$(dirname $(whereis postgres | awk '{print $2}'))
    fi

elif [ "$(uname)" == "Darwin" ]; then
    if command_exists postgres; then
        pg_bin_folder=$(dirname $(which postgres))
    elif [ -d "/usr/local/opt/postgresql/bin" ]; then
        pg_bin_folder="/usr/local/opt/postgresql/bin"
    elif [ -d "/opt/homebrew/opt/postgresql/bin" ]; then
        pg_bin_folder="/opt/homebrew/opt/postgresql/bin"
    elif whereis postgres > /dev/null 2>&1; then
        pg_bin_folder=$(dirname $(whereis postgres | awk '{print $2}'))
    fi

elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    if command_exists postgres; then
        pg_bin_folder=$(dirname $(which postgres))
    elif [ -d "C:/Program Files/PostgreSQL/*/bin" ]; then
        pg_bin_folder="C:/Program Files/PostgreSQL/*/bin"
    fi

else
    echo "Unsupported operating system."
    exit 1
fi

# Confirm PostgreSQL installation
if [ -z "$pg_bin_folder" ]; then
    echo "PostgreSQL executable not found. Please ensure PostgreSQL is installed correctly."
    exit 1
fi

# Check if postgres data directory has already been initialized, if not, run initdb
if [ -f "$postgres_path/PG_VERSION" ] && [ -f "$postgres_path/postgresql.conf" ] && [ -f "$postgres_path/pg_hba.conf" ]; then
    echo "PostgreSQL data directory is already initialized."
else
    echo "Initializing PostgreSQL data directory..."
    "$pg_bin_folder/initdb" -D "$postgres_path"
fi

# if (sudo -u postgres "$pg_bin_folder/postgres" -D "$postgres_path" -p 5454 >"$home_dir/.atp-devenv/pg.log") & pid=$!; then
if ("$pg_bin_folder/pg_ctl" -D "$postgres_path" -l "$home_dir/.atp-devenv/pg.log" -o "-p 5454" start); then
    echo "PostgreSQL started successfully."
else
    echo "Failed to start PostgreSQL."
    exit 1
fi

# Wait for server to start
"$pg_bin_folder/pg_isready" -h localhost -p 5454 -U postgres -d postgres

psql -c "CREATE USER atp_devenv WITH PASSWORD 'atp_devenv';" -p 5454 postgres
psql -c "ALTER USER atp_devenv CREATEDB;" -p 5454 postgres
psql -c "CREATE DATABASE atp_devenv OWNER atp_devenv;" -p 5454 postgres
psql -c "GRANT ALL PRIVILEGES ON DATABASE atp_devenv TO atp_devenv;" -p 5454 postgres

# if kill $pid; then
if ("$pg_bin_folder/pg_ctl" -D "$postgres_path" stop); then
    echo "PostgreSQL stopped successfully."
else
    echo "Failed to stop PostgreSQL."
    exit 1
fi

# Check for the presence of package managers
npm_installed=false
yarn_installed=false
pnpm_installed=false

if command_exists npm; then
    npm_installed=true
fi
if command_exists yarn; then
    yarn_installed=true
fi
if command_exists pnpm; then
    pnpm_installed=true
fi

# Determine the number of installed package managers
installed_count=0
[ "$npm_installed" == true ] && ((installed_count++))
[ "$yarn_installed" == true ] && ((installed_count++))
[ "$pnpm_installed" == true ] && ((installed_count++))

# Prompt for package manager if at least two are available
if [ "$installed_count" -ge 2 ]; then
    if $npm_installed && $yarn_installed && $pnpm_installed; then
        read -p "You have NPM, Yarn, and PNPM installed. Which one do you wish to use? (npm/yarn/pnpm): " package_manager
    elif $npm_installed && $yarn_installed; then
        read -p "You have both NPM and Yarn installed. Which one do you wish to use? (npm/yarn): " package_manager
    elif $npm_installed && $pnpm_installed; then
        read -p "You have both NPM and PNPM installed. Which one do you wish to use? (npm/pnpm): " package_manager
    elif $yarn_installed && $pnpm_installed; then
        read -p "You have both Yarn and PNPM installed. Which one do you wish to use? (yarn/pnpm): " package_manager
    fi
else
    # Use the first available package manager
    if $pnpm_installed; then
        package_manager="pnpm"
    elif $yarn_installed; then
        package_manager="yarn"
    elif $npm_installed; then
        package_manager="npm"
    else
        echo "Neither NPM, Yarn, nor PNPM is installed. Please install Node and NPM from https://docs.npmjs.com/downloading-and-installing-node-js-and-npm."
        exit 1
    fi
fi

# Confirm Go installation
if ! command_exists go; then
    echo "Go is not installed. Please install it from https://go.dev/doc/install."
    exit 1
fi

# Clone Indigo if it doesn't exist
indigo_path="$home_dir/indigo"
if [ ! -d "$indigo_path" ]; then
    git clone https://github.com/bluesky-social/indigo "$indigo_path"
    cd "$indigo_path"
    make build-relay-admin-ui
    make run-dev-relay
else
    echo "Indigo folder already exists. Skipping clone operation."
fi

# Install @atproto/dev-env using the chosen package manager
if [ "$package_manager" == "npm" ]; then
    if ! npm list -g --depth=0 | grep '@atproto/dev-env' > /dev/null; then
        npm install -g @atproto/dev-env
        echo "@atproto/dev-env installed with NPM."
    else
        echo "@atproto/dev-env is already installed with NPM."
    fi
elif [ "$package_manager" == "yarn" ]; then
    if ! yarn global list --pattern '@atproto/dev-env' > /dev/null; then
        yarn global add @atproto/dev-env
        echo "@atproto/dev-env installed with Yarn."
    else
        echo "@atproto/dev-env is already installed with Yarn."
    fi
elif [ "$package_manager" == "pnpm" ]; then
    if ! pnpm list -g | grep '@atproto/dev-env' > /dev/null; then
        pnpm install -g @atproto/dev-env
        echo "@atproto/dev-env installed with PNPM."
    else
        echo "@atproto/dev-env is already installed with PNPM."
    fi
else
    echo "Invalid package manager chosen."
    exit 1
fi