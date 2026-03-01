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

indigo_path="$home_dir/indigo"

cd "$indigo_path"

echo "Process \"make run-dev-relay\" started";
(make run-dev-relay) & pid=$!
PID_LIST+=" $pid";

echo "Process \"go run ./cmd/rainbow\" started";
(go run ./cmd/rainbow) & pid=$!
PID_LIST+=" $pid";

trap "kill $PID_LIST" SIGINT

echo "Relay and Rainbow have been started";

wait $PID_LIST

echo
echo "All processes have been completed"