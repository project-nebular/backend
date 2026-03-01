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