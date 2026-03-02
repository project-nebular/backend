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

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

postgres_path="$home_dir/.atp-devenv/postgres"
postgres_port=5454
redis_port=6390

if command_exists valkey-server; then
    redis_command="valkey-server"
elif command_exists redis-server; then
    redis_command="redis-server"
else
    echo "Error: Neither Valkey nor Redis is installed. Please install from either https://valkey.io/download/ or https://redis.io/downloads/"
    exit 1
fi

pg_bin_folder=""

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

# Check if pg_bin_folder was successfully set
if [ -z "$pg_bin_folder" ]; then
    echo "PostgreSQL executable not found. Please ensure PostgreSQL is installed correctly."
    exit 1
fi

# Check if postgres has already been initialized
if ! [ -f "$postgres_path/PG_VERSION" ] || ! [ -f "$postgres_path/postgresql.conf" ] || ! [ -f "$postgres_path/pg_hba.conf" ]; then
    echo "Postgrres has not been initialized."
    "$pg_bin_folder/initdb" -D "$postgres_path"
fi

indigo_path="$home_dir/indigo"

cd "$indigo_path"

export REDIS_HOST="http://localhost:$redis_port"
export DB_POSTGRES_URL="postgresql://atp_devenv:atp_devenv@localhost:$postgres_port/atp_devenv"

echo "Process \"make run-dev-relay\" started";
(make run-dev-relay) & pid=$!
PID_LIST+=" $pid";

echo "Process \"go run ./cmd/rainbow\" started";
(sleep 10 && go run ./cmd/rainbow) & pid=$!
PID_LIST+=" $pid";

echo "Process \"$redis_command\" started";
($redis_command --port $redis_port) & pid=$!
PID_LIST+=" $pid";

echo "Process \"$pg_bin_folder/postgres\" started";
("$pg_bin_folder/postgres" -D "$postgres_path" -p $postgres_port) & pid=$!
PID_LIST+=" $pid";

echo "Process \"dev-env\" started";
(dev-env) & pid=$!
PID_LIST+=" $pid";

trap "kill $PID_LIST" SIGINT

echo "Relay and Rainbow have been started";

wait $PID_LIST

echo
echo "All processes have been completed"