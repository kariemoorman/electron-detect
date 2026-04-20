#!/bin/bash

# Function to get Chromium + Node from Electron release page
get_runtime_versions() {
    local version="$1"

    local tmp=$(mktemp)

    curl -sL "https://releases.electronjs.org/release/v${version}" > "$tmp"

    # Node.js version
    node=$(grep -o 'nodejs/node/releases/tag/v[0-9.]*' "$tmp" \
        | head -n1 \
        | sed 's/.*v//')

    # Chromium version
    chromium=$(grep -o 'refs/tags/[0-9.]*:' "$tmp" \
        | head -n1 \
        | sed 's/refs\/tags\///;s/://')

    rm -f "$tmp"

    echo "chrome=$chromium node=$node"
}

# Function to get Electron version from framework
get_electron_version() {
    local framework_dir="$1"

    for path in \
        "$framework_dir/Versions/Current/Resources/Info.plist" \
        "$framework_dir/Resources/Info.plist" \
        "$framework_dir/Electron Framework.framework/Resources/Info.plist"
    do
        if [[ -f "$path" ]]; then
            version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$path" 2>/dev/null ||
                      /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$path" 2>/dev/null)
            [[ -n "$version" ]] && echo "$version" && return
        fi
    done

    local executable
    executable=$(find "$framework_dir" -name "Electron" -type f -perm +111 2>/dev/null | head -n1)

    if [[ -n "$executable" ]]; then
        version=$("$executable" --version 2>/dev/null | awk '{print $2}')
        [[ -n "$version" ]] && echo "$version" && return
    fi

    echo "unknown"
}

# App version
get_app_version() {
    local app_path="$1"
    local plist_path="$app_path/Contents/Info.plist"

    if [[ -f "$plist_path" ]]; then
        /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$plist_path" 2>/dev/null ||
        /usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$plist_path" 2>/dev/null ||
        echo "unknown"
    else
        echo "unknown"
    fi
}

# Latest Electron version (kept simple)
get_latest_electron_version() {
    if command -v curl >/dev/null 2>&1; then
        # Try to get latest version from npm registry
        latest_version=$(curl -s https://registry.npmjs.org/electron/latest | grep -o '"version":"[^"]*' | grep -o '[^"]*$' 2>/dev/null)
        if [[ -n "$latest_version" ]]; then
            echo "$latest_version"
            return
        fi
    fi
    
    # Fallback to GitHub API if npm registry fails
    if command -v curl >/dev/null 2>&1; then
        latest_version=$(curl -s https://api.github.com/repos/electron/electron/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/^v//')
        if [[ -n "$latest_version" ]]; then
            echo "$latest_version"
            return
        fi
    fi
    
    echo "unknown"
}

# ---------------- MAIN ----------------

temp_file=$(mktemp)

mdfind "kMDItemKind == 'Application'" > "$temp_file"

for dir in "/Applications" "$HOME/Applications"; do
    [[ -d "$dir" ]] && find "$dir" -maxdepth 2 -name "*.app" -type d >> "$temp_file"
done

latest_electron_version=$(get_latest_electron_version)

echo
echo "=============================================="
echo "Latest available Electron version: v$latest_electron_version"
echo "=============================================="
echo

sort -u "$temp_file" | while read -r app; do
    framework_dir="$app/Contents/Frameworks"

    if [[ -d "$framework_dir" ]]; then
        electron_framework=$(find "$framework_dir" -maxdepth 1 -type d -iname "*electron*" 2>/dev/null | head -n1)

        if [[ -n "$electron_framework" ]]; then
            electron_version=$(get_electron_version "$electron_framework")
            app_version=$(get_app_version "$app")

            clean_version="${electron_version#v}"

            runtime=$(get_runtime_versions "$clean_version")

            chrome=$(echo "$runtime" | grep -o 'chrome=[^ ]*' | cut -d= -f2)
            node=$(echo "$runtime" | grep -o 'node=[^ ]*' | cut -d= -f2)

            echo "=============================================="
            echo "App: $app"
            echo "App Version: v$app_version"
            echo "Electron: v$electron_version"
            echo "Chromium: ${chrome:-unknown}"
            echo "Node.js: ${node:-unknown}"
            echo "=============================================="
        fi
    fi
done

rm "$temp_file"
