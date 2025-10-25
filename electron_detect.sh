#!/bin/bash

# Function to get Electron version from framework
get_electron_version() {
    local framework_dir="$1"
    local plist_path="$framework_dir/Resources/Info.plist"
    
    for path in \
        "$framework_dir/Versions/Current/Resources/Info.plist" \
        "$framework_dir/Resources/Info.plist" \
        "$framework_dir/Electron Framework.framework/Resources/Info.plist"
    do
        if [[ -f "$path" ]]; then
            version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$path" 2>/dev/null ||
                      /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$path" 2>/dev/null)
            if [[ -n "$version" ]]; then
                echo "$version"
                return
            fi
        fi
    done
    
    local executable
    executable=$(find "$framework_dir" -name "Electron" -type f -perm +111 2>/dev/null | head -n1)
    if [[ -n "$executable" ]]; then
        version=$("$executable" --version 2>/dev/null | awk '{print $2}')
        if [[ -n "$version" ]]; then
            echo "$version"
            return
        fi
    fi
    
    echo "unknown"
}

# Function to get the app version
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

# Function to get the latest Electron version
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

# Main script
temp_file=$(mktemp)

mdfind "kMDItemKind == 'Application'" > "$temp_file"

for dir in "/Applications" "$HOME/Applications"; do
    [[ -d "$dir" ]] && find "$dir" -maxdepth 2 -name "*.app" -type d >> "$temp_file"
done

# Get latest Electron version
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
            echo "✅ Electron App: $app (App: v$app_version, Electron: v$electron_version)"
        fi
    fi
done
echo

rm "$temp_file"
